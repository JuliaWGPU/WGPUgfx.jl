
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
					:clearValue => (0.0, 0.0, 0.0, 1.0),
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

function addObject!(renderer::Renderer, object::Union{Renderable, RenderableUI})
    scene = renderer.scene
	for camera in scene.cameraSystem
		setup(renderer, object, camera)
	end
	push!(scene.objects, object)
end

function addObjects!(renderer::Renderer, objects::Array{Union{Renderable, RenderableUI}})
    for obj in objects
        addObject!(renderer, obj)
    end
end

function addObjects!(renderer::Renderer, objects::Union{Renderable, RenderableUI}...)
    for obj in objects
        addObject!(renderer, obj)
    end
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
	binding = MAX_CAMERAS + MAX_LIGHTS + 1 # Binding slot for objects starts from this index.
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
	# Prepare the object only once regardless of camera
	if !isdefined(object, :gpuDevice) || object.gpuDevice === nothing
		prepareObject(gpuDevice, object)
	end
	preparePipeline(gpuDevice, renderer, object, camera; binding=binding)
end

function setup(renderer::Renderer, quad::RenderableUI, camera::Camera)
	binding = 0
	scene = renderer.scene
	gpuDevice = scene.gpuDevice
	scene.cameraId = camera.id
	compileShaders!(gpuDevice, scene, quad; binding=binding)
	
	# Only prepare object if it hasn't been prepared yet
	if !isdefined(quad, :gpuDevice) || quad.gpuDevice === nothing
		prepareObject(gpuDevice, quad)
	end
	
	preparePipeline(gpuDevice, renderer, quad, camera; binding=binding)
end

function getDefaultSrc(scene::Scene, isLight::Bool, isTexture::Bool)
	src = quote end

	# Add camera shader code including struct definition and binding
	push!(src.args, getShaderCode(scene.camera; binding = scene.cameraId - 1 + CAMERA_BINDING_START))
	
	# Add lighting if needed
	isLight && push!(src.args, getShaderCode(scene.light; binding = LIGHT_BINDING_START))

	return src
end

function compileShaders!(gpuDevice, scene::Scene, object::Renderable; binding=MAX_CAMERAS + MAX_LIGHTS+1)
	isLight = isNormalDefined(object) && scene.light != nothing
	isTexture = isTextureDefined(object) && object.textureData != nothing

	# Create shader source
	src = quote end
	
	# Add specific camera code
	append!(src.args, getDefaultSrc(scene, isLight, isTexture).args)
	
	# Add object-specific shader code
	push!(src.args, getShaderCode(object, scene.cameraId; binding = binding))
	
	try
		cshader = createShaderObj(gpuDevice, src; savefile=false)
		cshaders = getfield(object, :cshaders)
		cshaders[scene.cameraId] = cshader
		if isdefined(WGPUCore, :logLevel) && Int(WGPUCore.logLevel) == 4 # Debug level
			@info cshader.src "Renderable"
		end
	catch(e)
		@info "Caught exception in Renderable :compileShaders!" e
		@error "Source code:" src
		rethrow(e)
	end
	return nothing
end


function compileShaders!(gpuDevice, scene::Scene, quad::RenderableUI; binding=MAX_CAMERAS + MAX_LIGHTS+1)
	isLight = false
	isTexture = isTextureDefined(quad) && quad.textureData !== nothing

	# For UI elements, we don't need camera access in most cases
	src = quote end
	
	push!(src.args, getShaderCode(quad, scene.cameraId; binding = binding))
	
	try
		cshader = createShaderObj(gpuDevice, src; savefile=false)
		cshaders = getfield(quad, :cshaders)
		cshaders[scene.cameraId] = cshader
		if isdefined(WGPUCore, :logLevel) && Int(WGPUCore.logLevel) == 4
			@info cshader.src "RenderableUI"
		end
	catch(e)
		@info "Caught exception in RenderableUI :compileShaders!" e
		@error "Source code:" src
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
			
			# Create shader source
			src = quote end
			
			# Add camera and other code
			append!(src.args, getDefaultSrc(scene, isLight, isTexture).args)
			push!(src.args, getShaderCode(obj, scene.cameraId; binding = binding))
			
			try
				cshader = createShaderObj(gpuDevice, src; savefile=false)
				cshaders = getfield(obj, :cshaders)
				cshaders[scene.cameraId] = cshader
				if isdefined(WGPUCore, :logLevel) && Int(WGPUCore.logLevel) == 4
					@info cshader.src "WorldObject"
				end
			catch(e)
				@info "Caught Exception in WorldObject :compileShaders!" e
				@error "Source code:" src
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
		WGPUCore.setViewport(renderer.renderPass, dims..., 0.0, 1.0)
		# WGPUCore.setScissorRect(renderer.renderPass[], dims...)
	end
	for object in scene.objects
		try
			WGPUgfx.render(renderer.renderPass, renderer.renderPassOptions, object, scene.cameraId)
		catch e
			@error "Error rendering object of type $(typeof(object)):" e
		end
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
			try
				# Make sure cshader exists for this camera
				if !haskey(object.cshaders, camera.id)
					@debug "Object does not have shader for camera $(camera.id), recompiling"
					# Store current camera id
					oldCameraId = scene.cameraId
					# Set current camera id to the target camera
					scene.cameraId = camera.id
					# Compile shaders for this camera
					try
						compileShaders!(scene.gpuDevice, scene, object)
						# Prepare pipeline for this camera
						preparePipeline(scene.gpuDevice, renderer, object, camera)
					catch e
						@error "Error compiling shaders for camera $(camera.id)" e
					end
					# Restore original camera id
					scene.cameraId = oldCameraId
				end
				
				# Now render with the correct camera
				WGPUgfx.render(renderer.renderPass, renderer.renderPassOptions, object, camera.id)
			catch e
				@error "Error rendering object of type $(typeof(object)) with camera $(camera.id):" e
			end
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
		WGPUCore.setViewport(renderer.renderPass, dims..., 0.0, 1.0)
		# WGPUCore.setScissorRect(renderer.renderPass[], dims...)
	end
	
	# Make sure shader exists for this camera
	if !haskey(object.cshaders, scene.cameraId)
		@debug "Object does not have shader for current camera, recompiling"
		compileShaders!(scene.gpuDevice, scene, object)
		preparePipeline(scene.gpuDevice, renderer, object, scene.cameraSystem[scene.cameraId])
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
