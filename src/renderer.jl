
export Renderer, getRenderPassOptions, getRenderer, compileShaders!, init, deinit, render

mutable struct Renderer
	scene
	presentContext
	currentTextureView
	cmdEncoder
	depthTexture
	depthView
	renderPass
	renderPassOptions
	renderTextureFormat
end

function getRenderPassOptions(currentTextureView, depthView)
	renderPassOptions = [
		WGPUCore.GPUColorAttachments => [
			:attachments => [
				WGPUCore.GPUColorAttachment => [
					:view => currentTextureView,
					:resolveTarget => C_NULL,
					:clearValue => (0.2, 0.2, 0.2, 1.0),
					:loadOp => WGPULoadOp_Clear,
					:storeOp => WGPUStoreOp_Store,
				],
			]
		],
		WGPUCore.GPUDepthStencilAttachments => [
			:attachments => [
				WGPUCore.GPUDepthStencilAttachment => [
					:view => depthView,
					:depthClearValue => 1.0f0,
					:depthLoadOp => WGPULoadOp_Clear,
					:depthStoreOp => WGPUStoreOp_Store,
					:stencilLoadOp => WGPULoadOp_Clear,
					:stencilStoreOp => WGPUStoreOp_Store,
				]
			]
		]
	]
	return renderPassOptions
end


function getRenderer(scene::Scene)
	renderTextureFormat = WGPUCore.getPreferredFormat(scene.canvas)
	presentContext = WGPUCore.getContext(scene.canvas)
	WGPUCore.determineSize(presentContext)
	WGPUCore.config(presentContext, device=scene.gpuDevice, format = renderTextureFormat)
	
	currentTextureView = WGPUCore.getCurrentTexture(presentContext);

	Renderer(
		scene,
		presentContext,
		nothing, #currentTextureView,
		nothing,
		nothing, #depthTexture,
		nothing, # depthView,
		nothing,
		nothing, #renderPassOptions,
		renderTextureFormat
	)
end


function setup(renderer::Renderer, object::Renderable, camera::Camera)
	binding = 2 # Binding slot for objects starts from this index.
	scene = renderer.scene
	gpuDevice = scene.gpuDevice
	scene.cameraId = camera.id
	preparedLight=false
	compileShaders!(gpuDevice, scene, object; binding=binding)
	if camera.uniformBuffer === nothing
		prepareObject(gpuDevice, camera)
		camera.up = [0, 1, 0] .|> Float32
		camera.eye = ([0.0, 0.0, 4.0] .|> Float32)
	end
	if !preparedLight
		if (typeof(object) <: WorldObject && isRenderType(object.rType, SURFACE)) || isNormalDefined(object)
			prepareObject(gpuDevice, scene.light)
			preparedLight = true
		end
	end
	prepareObject(gpuDevice, object)
	preparePipeline(gpuDevice, renderer, object, camera; binding=binding)
end


function getDefaultSrc(scene::Scene, isLight::Bool, isTexture::Bool)
	src = quote end

	push!(src.args, getShaderCode(scene.cameraSystem; binding=scene.cameraId-1))
	isLight && push!(src.args, getShaderCode(scene.light; binding= 1))
	
	return src
end

function compileShaders!(gpuDevice, scene::Scene, object::Renderable; binding=3)
	isLight = isNormalDefined(object) && scene.light != nothing 
	
	isTexture =  isTextureDefined(object) && object.textureData != nothing

	src = getDefaultSrc(scene, isLight, isTexture)
	push!(src.args, getShaderCode(object, scene.cameraId; binding = binding))
	try
		cshader = createShaderObj(gpuDevice, src; savefile=false)
		setfield!(object, :cshader, cshader)
		@info  cshader.src "Renderable"
	catch(e)
		@info "Caught exception in Renderable :compileShaders!" e
		rethrow(e)
	end
	return nothing
end


function compileShaders!(gpuDevice, scene::Scene, object::WorldObject; binding=3)
	objType = typeof(object)
	for fieldIdx in 1:fieldcount(WorldObject)
		fName = fieldname(objType, fieldIdx)
		fType = fieldtype(objType, fieldIdx)
		if (fType >: Renderable || fType <: Renderable)
			(fName == :wireFrame) &&
				isRenderType(object.rType, WIREFRAME) && object.wireFrame == nothing &&
					setfield!(object, :wireFrame, defaultWireFrame(object.renderObj))
			(fName == :bbox) &&
				isRenderType(object.rType, BBOX) && object.bbox == nothing &&
					setfield!(object, :bbox, defaultBBox(object.renderObj))
			(fName == :axis) &&
				isRenderType(object.rType, AXIS) && object.axis == nothing &&
					setfield!(object, :axis, defaultAxis(;len=0.1))
			(fName == :select) && 
				isRenderType(object.rType, SELECT) && object.select == nothing &&
					setfield!(object, :select, defaultBBox(object.renderObj))
			obj = getfield(object, fName)
			if obj == nothing
				continue
			end
			
			isLight = isNormalDefined(obj) && scene.light != nothing 
			isTexture = isTextureDefined(obj) && obj.textureData != nothing
			src = getDefaultSrc(scene, isLight, isTexture)
			push!(src.args, getShaderCode(obj; binding = binding))
			try
				cshader = createShaderObj(gpuDevice, src; savefile=false)
				setfield!(obj, :cshader, cshader)
				@info  cshader.src "WorldObject"
			catch(e)
				@info "Caught Exception in WorldObject :compileShaders!" e
				rethrow(e)
			end
		# else
			# Currently this ignore RenderType field within WorldObject 
			# @error objType fName fType
		end
	end
	return nothing
end

function init(renderer::Renderer)
	scene = renderer.scene
	renderSize = scene.canvas.size
	renderer.currentTextureView = WGPUCore.getCurrentTexture(renderer.presentContext) |> Ref;

	renderer.depthTexture = WGPUCore.createTexture(
		scene.gpuDevice,
		"DEPTH TEXTURE",
		(renderSize..., 1),
		1,
		1,
		WGPUTextureDimension_2D,
		WGPUTextureFormat_Depth24Plus,
		WGPUCore.getEnum(WGPUCore.WGPUTextureUsage, "RenderAttachment")
	) |> Ref
	
	renderer.depthView = WGPUCore.createView(renderer.depthTexture[]) |> Ref

	renderer.renderPassOptions = getRenderPassOptions(renderer.currentTextureView[], renderer.depthView[])

	renderer.cmdEncoder = WGPUCore.createCommandEncoder(scene.gpuDevice, "CMD ENCODER") |> Ref
	renderer.renderPass = WGPUCore.beginRenderPass(
		renderer.cmdEncoder[], 
		renderer.renderPassOptions |> Ref; 
		label= "BEGIN RENDER PASS"
	) |> Ref
end

function deinit(renderer::Renderer)
	WGPUCore.endEncoder(renderer.renderPass[])
	WGPUCore.submit(renderer.scene.gpuDevice.queue, [WGPUCore.finish(renderer.cmdEncoder[]),])
	WGPUCore.present(renderer.presentContext)
	WGPUCore.destroy(renderer.depthView[])
	WGPUCore.destroy(renderer.depthView[].texture[])
	# WGPUCore.destroy(renderer.depthTexture[])
end


function render(renderer::Renderer; dims=nothing)
	if dims !== nothing
		WGPUCore.setViewport(renderer.renderPass[], dims..., 0, 1)
	end
	for object in scene.objects
		WGPUgfx.render(renderer.renderPass[], renderer.renderPassOptions, object)
	end
end

function render(renderer::Renderer, object; dims=nothing)
	if dims!==nothing
		WGPUCore.setViewport(renderer.renderPass[], dims..., 0, 1)
	end
	WGPUgfx.render(renderer.renderPass[], renderer.renderPassOptions, object)
end

