using WGPUNative
using WGPUCore
using Rotations
using CoordinateTransformations
using LinearAlgebra
using StaticArrays
using GeometryBasics: Mat4

export Scene, composeShader, defaultCamera, defaultVision, Vision, Camera, defaultCube,
	defaultPlane, Plane, Cube, Triangle3D, defaultTriangle3D,
	defaultCircle, Circle, setup, runApp, defaultLighting, Lighting,
	defaultWGPUMesh, addObject!

mutable struct Scene
	gpuDevice
	canvas	
	camera						# TODO cameras
	light						# TODO lights
	objects 					# ::Union{WorldObject, ObjectGroup}
	presentContext
	bindGroup
	depthTexture				# Not sure if this should be part of scene
	depthView					# same here
	renderTextureFormat
	cshader
end


# TODO not sure if this is right approach
# function Base.setproperty!(scene::Scene, s::Symbol, v)
	# if s==:depthView
		# if scene.depthView != nothing
			# WGPUCore.destroy(scene.depthView)
			# WGPUCore.destroy(scene.depthView.texture[])
		# end
	# end
# end


# TODO viewport dependent addObject
function addObject!(scene, obj)
	push!(scene.objects, obj)
	setup(scene)
end

function composeShader(gpuDevice, scene, object; binding=3)
	src = quote end

	isLight = (scene.light != nothing) && isdefined(object, :normalData)

	isVision = typeof(scene.camera) != Camera
	
	push!(src.args, getShaderCode(scene.camera; isVision=isVision, islight=isLight, binding=0))

	isLight && push!(src.args, getShaderCode(scene.light; isVision=isVision, islight=isLight, binding= isVision ? 2 : 1))

	isTexture = false

	if isdefined(object, :textureData)
		isTexture = object.textureData != nothing
	end

	VertexInputName = Symbol(
		:VertexInput, 
		isLight ? (:LL) : (:NL),
		isTexture ? (:TT) : (:NT),
		isVision ? (:VV) : (:NV)
	)
	
	VertexOutputName = Symbol(
		:VertexOutput, 
		isLight ? (:LL) : (:NL),
		isTexture ? (:TT) : (:NT),
		isVision ? (:VV) : (:NV)
	)

	defaultSource = quote
		struct $VertexInputName
			@location 0 pos::Vec4{Float32}
			@location 1 vColor::Vec4{Float32}
			if $isLight
				@location 2 vNormal::Vec4{Float32}
			end
			if $isTexture
				@location 3 vTexCoords::Vec2{Float32}
			end
		end

		struct $VertexOutputName
			@location 0 vColor::Vec4{Float32}
			@builtin position pos::Vec4{Float32}

			if $isVision
				@location 1 vPosLeft::Vec4{Float32}
				@location 2 vPosRight::Vec4{Float32}
			end

			if $isLight
				if $isVision
					@location 3 vNormalLeft::Vec4{Float32}
					@location 4 vNormalRight::Vec4{Float32}
				else
					@location 1 vNormal::Vec4{Float32}
				end
			end
			if $isTexture
				if $isVision
					@location 5 vTexCoords::Vec2{Float32}
				else
					@location 2 vTexCoords::Vec2{Float32}
				end	
			end
		end
	end
	
	push!(src.args, defaultSource)
	push!(src.args, getShaderCode(object; isVision=isVision, islight=isLight, binding = binding))
	try
		createShaderObj(gpuDevice, src; savefile=false)
	catch(e)
		@info e
		rethrow(e)
	end
end


setup(scene) = setup(scene.gpuDevice, scene)

function setup(gpuDevice, scene)
	scene.renderTextureFormat = WGPUCore.getPreferredFormat(scene.canvas)
	presentContext = WGPUCore.getContext(scene.canvas)
	WGPUCore.determineSize(presentContext)
	WGPUCore.config(presentContext, device=gpuDevice, format = scene.renderTextureFormat)
	scene.presentContext = presentContext
	
	isVision = typeof(scene.camera) == Vision
	preparedCamera = false
	preparedLight = false

	for (idx, object) in enumerate(scene.objects)
		binding = idx + (isVision ? 2 : 1)
		cshader = composeShader(gpuDevice, scene, object; binding=binding)
		scene.cshader = cshader
		@info cshader.src
		if !preparedCamera
			prepareObject(gpuDevice, scene.camera)
			scene.camera.up = [0, 1, 0] .|> Float32
			scene.camera.eye = ([0.0, 0, 4.0] .|> Float32)
			preparedCamera = true
		end
		if !preparedLight
			if (scene.light != nothing) && isLightRequired(object)
				prepareObject(gpuDevice, scene.light)
				preparedLight = true
			end
		end
		prepareObject(gpuDevice, object)
		preparePipeline(gpuDevice, scene, object; isVision=isVision, binding=binding)
	end
end

runApp(scene) = runApp(scene.gpuDevice, scene)

function runApp(gpuDevice, scene)
	currentTextureView = WGPUCore.getCurrentTexture(scene.presentContext);
	cmdEncoder = WGPUCore.createCommandEncoder(gpuDevice, "CMD ENCODER")

	scene.depthTexture = WGPUCore.createTexture(
		gpuDevice,
		"DEPTH TEXTURE",
		(scene.canvas.size..., 1),
		1,
		1,
		WGPUTextureDimension_2D,
		WGPUTextureFormat_Depth24Plus,
		WGPUCore.getEnum(WGPUCore.WGPUTextureUsage, "RenderAttachment")
	)
	
	scene.depthView = WGPUCore.createView(scene.depthTexture)

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
					:view => scene.depthView,
					:depthClearValue => 1.0f0,
					:depthLoadOp => WGPULoadOp_Clear,
					:depthStoreOp => WGPUStoreOp_Store,
					:stencilLoadOp => WGPULoadOp_Clear,
					:stencilStoreOp => WGPUStoreOp_Store,
				]
			]
		]
	]

	renderPass = WGPUCore.beginRenderPass(cmdEncoder, renderPassOptions |> Ref; label= "BEGIN RENDER PASS")

	# TODO idea default viewport 0
	for object in scene.objects
		render(renderPass, renderPassOptions, object)
	end

	# TODO and support multiple viewports
	# WGPUCore.setViewport(renderPass, 150, 150, 300, 300, 0, 1)
	# for object in scene.objects
		# render(renderPass, renderPassOptions, object)
	# end
	
	WGPUCore.endEncoder(renderPass)
	WGPUCore.submit(gpuDevice.queue, [WGPUCore.finish(cmdEncoder),])
	WGPUCore.present(scene.presentContext)

	# for object in scene.objects
		# # WGPUCore.destroy(object.renderPipeline)
		# # for prop in propertynames(object)
			# # @info typeof(object) prop
			# # if prop in [:uniformBuffer, :vertexBuffer, :indexBuffer, :renderPipeline]
				# # continue
			# # elseif WGPUCore.isDestroyable(getfield(object, prop))
				# # @warn typeof(object) prop "Destroying"
				# # WGPUCore.destroy(getfield(object, prop))
			# # end
		# # end
	# end

	WGPUCore.destroy(scene.depthView)
	WGPUCore.destroy(scene.depthView.texture[])

end

