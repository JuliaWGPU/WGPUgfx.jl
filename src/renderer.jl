
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


function getRenderPassOptions(currentTextureView, depthView; depthClearValue=1.0f0)
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


function addObject!(renderer::Renderer, object::Renderable, camera::Camera)
    scene = renderer.scene
	setup(renderer, object, camera)
	push!(scene.objects, object)
end

function addObject!(renderer::Renderer, quad::RenderableUI, camera::Camera)
	scene = renderer.scene
	setup(renderer, quad, camera)
	push!(scene.objects, quad)
end

function addObject!(renderer::Renderer, object::Renderable)
    scene = renderer.scene
	for camera in scene.cameraSystem
		setup(renderer, object, camera)
	end
	push!(scene.objects, object)
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
	binding = 0 # MAX_CAMERAS + MAX_LIGHTS + 1 # Binding slot for objects starts from this index.
	scene = renderer.scene
	gpuDevice = scene.gpuDevice
	scene.cameraId = camera.id
	preparedLight=false
	compileShaders!(gpuDevice, scene, object; binding=MAX_CAMERAS + MAX_LIGHTS + 1)
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
	# Checking camera.id here to share object uniforms to cameraSystem 
	# TODO we need to make a more disciplined way to handle this
	# For now we are sharing objects across cameras 
	if camera.id == 1
		prepareObject(gpuDevice, object)
	end
	preparePipeline(gpuDevice, renderer, object, camera; binding=binding)
end

function setup(renderer::Renderer, quad::RenderableUI, camera::Camera)
	binding = 0
	scene = renderer.scene
	gpuDevice = scene.gpuDevice
	scene.cameraId = camera.id
	compileShaders!(gpuDevice, scene, quad; binding=0)
	prepareObject(gpuDevice, quad)
	preparePipeline(gpuDevice, renderer, quad, camera; binding=0)
end

function getDefaultSrc(scene::Scene, isLight::Bool, isTexture::Bool)
	src = quote end

	push!(src.args, getShaderCode(scene.cameraSystem; binding=scene.cameraId - 1 + CAMERA_BINDING_START))
	isLight && push!(src.args, getShaderCode(scene.light; binding = LIGHT_BINDING_START))
	
	return src
end

function compileShaders!(gpuDevice, scene::Scene, object::Renderable; binding=MAX_CAMERAS + MAX_LIGHTS+1)
	isLight = isNormalDefined(object) && scene.light != nothing 
	
	isTexture =  isTextureDefined(object) && object.textureData != nothing

	src = getDefaultSrc(scene, isLight, isTexture)
	push!(src.args, getShaderCode(object, scene.cameraId; binding = binding))
	try
		cshader = createShaderObj(gpuDevice, src; savefile=false)
		cshaders =  getfield(object, :cshaders)
		cshaders[scene.cameraId] = cshader
		# setfield!(object, :cshader, cshader)
		if isdefined(WGPUCore, :logLevel) && Int(WGPUCore.logLevel) == 4 # Debug level
			@info  cshader.src "Renderable"
		end
	catch(e)
		@info "Caught exception in Renderable :compileShaders!" e
		rethrow(e)
	end
	return nothing
end


function compileShaders!(gpuDevice, scene::Scene, quad::RenderableUI; binding=MAX_CAMERAS + MAX_LIGHTS+1)
	isLight = false
	isTexture =  isTextureDefined(quad) && quad.textureData !== nothing

	src = quote end
	push!(src.args, getShaderCode(quad, scene.cameraId; binding = binding))
	try
		cshader = createShaderObj(gpuDevice, src; savefile=false)
		cshaders =  getfield(quad, :cshaders)
		cshaders[scene.cameraId] = cshader
		# setfield!(object, :cshader, cshader)
		if isdefined(WGPUCore, :logLevel) && Int(WGPUCore.logLevel) == 4
			@info  cshader.src "RenderableUI"
		end
	catch(e)
		@info "Caught exception in RenderableUI :compileShaders!" e
		rethrow(e)
	end
	return nothing
end


function compileShaders!(gpuDevice, scene::Scene, object::WorldObject; binding=MAX_CAMERAS+MAX_LIGHTS+1)
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
			push!(src.args, getShaderCode(obj, scene.cameraId; binding = binding))
			try
				cshader = createShaderObj(gpuDevice, src; savefile=false)
				cshaders = getfield(obj, :cshaders)
				cshaders[scene.cameraId] = cshader
				# setfield!(obj, :cshader, cshader)
				if isdefined(WGPUCore, :logLevel) && Int(WGPUCore.logLevel) == 4
					@info  cshader.src "WorldObject"
				end
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
	renderer.currentTextureView = WGPUCore.getCurrentTexture(renderer.presentContext);

	renderer.depthTexture = WGPUCore.createTexture(
		scene.gpuDevice,
		"DEPTH TEXTURE",
		(renderSize..., 1),
		1,
		1,
		WGPUTextureDimension_2D,
		WGPUTextureFormat_Depth24Plus,
		WGPUCore.getEnum(WGPUCore.WGPUTextureUsage, "RenderAttachment")
	)
	
	renderer.depthView = WGPUCore.createView(renderer.depthTexture)

	renderer.renderPassOptions = getRenderPassOptions(renderer.currentTextureView, renderer.depthView)

	renderer.cmdEncoder = WGPUCore.createCommandEncoder(scene.gpuDevice, "CMD ENCODER")
	renderer.renderPass = WGPUCore.beginRenderPass(
		renderer.cmdEncoder, 
		renderer.renderPassOptions |> Ref; 
		label= "BEGIN RENDER PASS"
	)
end

function deinit(renderer::Renderer)
	WGPUCore.endEncoder(renderer.renderPass)
	WGPUCore.submit(renderer.scene.gpuDevice.queue, [WGPUCore.finish(renderer.cmdEncoder),])
	WGPUCore.present(renderer.presentContext)
	WGPUCore.destroy(renderer.depthView)
	WGPUCore.destroy(renderer.depthView.texture[])
	# WGPUCore.destroy(renderer.depthTexture[])
end


function render(renderer::Renderer; dims=nothing)
    scene = renderer.scene
	if dims !== nothing
		WGPUCore.setViewport(renderer.renderPass, dims..., 0.0, 1)
		# WGPUCore.setScissorRect(renderer.renderPass[], dims...)
	end
	for object in scene.objects
		WGPUgfx.render(renderer.renderPass, renderer.renderPassOptions, object, scene.cameraId)
	end
end

function render(renderer::Renderer, viewportDims::Dict)
	scene = renderer.scene
	for idx in 1:length(scene.objects)
		for camera in scene.cameraSystem
			dims = get(viewportDims, camera.id, nothing)
			object = scene.objects[idx]
			if dims !== nothing
				WGPUCore.setViewport(renderer.renderPass, dims..., 0.0, 1.0)
				# WGPUCore.setScissorRect(renderer.renderPass[], dims...)
			end
			WGPUgfx.render(renderer.renderPass, renderer.renderPassOptions, object, camera.id)
		end
	end
end


function render(renderer::Renderer, object::Renderable, viewportDims::Dict)
	for camId in keys(viewportDims)
		dims = viewportDims[camId]
		WGPUCore.setViewport(renderer.renderPass, dims..., 0.0, 1.0)
		# WGPUCore.setScissorRect(renderer.renderPass[], dims...)
		WGPUgfx.render(renderer.renderPass, renderer.renderPassOptions, object, camId)
	end
end

function render(renderer::Renderer, quad::RenderableUI, viewportDims::Dict)
	for camId in keys(viewportDims)
		dims = viewportDims[camId]
		WGPUCore.setViewport(renderer.renderPass, dims..., 0.0, 1.0)
		# WGPUCore.setScissorRect(renderer.renderPass[], dims...)
		WGPUgfx.render(renderer.renderPass, renderer.renderPassOptions, quad, camId)
	end
end


function render(renderer::Renderer, object::Renderable; dims=nothing)
	scene = renderer.scene
	if dims!==nothing
		WGPUCore.setViewport(renderer.renderPass, dims..., 0.0, 1)
		# WGPUCore.setScissorRect(renderer.renderPass[], dims...)
	end
	WGPUgfx.render(renderer.renderPass, renderer.renderPassOptions, object, scene.cameraId)
end


function preparePipeline(gpuDevice, renderer::Renderer, mesh::WorldObject{T}, camera::Camera; binding=0) where T<:Renderable
	isRenderType(mesh.rType, SURFACE) && mesh.renderObj !== nothing && 
		preparePipeline(gpuDevice, renderer, mesh.renderObj, camera; binding = binding)
	isRenderType(mesh.rType, WIREFRAME) && mesh.wireFrame !== nothing &&
		preparePipeline(gpuDevice, renderer, mesh.wireFrame, camera; binding = binding)
	isRenderType(mesh.rType, BBOX) && mesh.bbox !==nothing &&
		preparePipeline(gpuDevice, renderer, mesh.bbox, camera; binding = binding)
	isRenderType(mesh.rType, AXIS) && mesh.axis !==nothing &&
		preparePipeline(gpuDevice, renderer, mesh.axis, camera; binding = binding)
	isRenderType(mesh.rType, SELECT) && mesh.select !== nothing &&
		preparePipeline(gpuDevice, renderer, mesh.select, camera; binding=binding)
end
