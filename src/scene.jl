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


# TODO viewport dependent addObject
function addObject!(scene, obj)
	push!(scene.objects, obj)
	setup(scene)
end

function composeShader(gpuDevice, scene, object; binding=3)
	src = quote end

	islight = (scene.light != nothing)

	isVision = typeof(scene.camera) != Camera
	
	push!(src.args, getShaderCode(scene.camera; isVision=isVision, islight=islight, binding=0))

	islight && push!(src.args, getShaderCode(scene.light; isVision=isVision, islight=islight, binding= isVision ? 2 : 1))

	isTexture = object.textureData != nothing
	
	defaultSource = quote
		struct VertexInput
			@location 0 pos::Vec4{Float32}
			@location 1 vColor::Vec4{Float32}
			if $islight
				@location 2 vNormal::Vec4{Float32}
			end
			if $isTexture
				@location 3 vTexCoords::Vec2{Float32}
			end
		end

		struct VertexOutput
			@location 0 vColor::Vec4{Float32}
			@builtin position pos::Vec4{Float32}

			if $isVision
				@location 1 vPosLeft::Vec4{Float32}
				@location 2 vPosRight::Vec4{Float32}
			end

			if $islight
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
	push!(src.args, getShaderCode(object; isVision=isVision, islight=islight, binding = binding))
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
	WGPUCore.determineSize(presentContext[])
	WGPUCore.config(presentContext, device=gpuDevice, format = scene.renderTextureFormat)
	scene.presentContext = presentContext
	
	isVision = typeof(scene.camera) == Vision

	for (idx, object) in enumerate(scene.objects)
		binding = idx + (isVision ? 2 : 1)
		cshader = composeShader(gpuDevice, scene, object; binding=binding)
		scene.cshader = cshader
		@info cshader.src
		if idx == 1
			prepareObject(gpuDevice, scene.camera)
		end
		scene.camera.eye = ([0.0, 0.0, -4.0] .|> Float32)
		(scene.light != nothing) && prepareObject(gpuDevice, scene.light)
		prepareObject(gpuDevice, object)
		preparePipeline(gpuDevice, scene, object; isVision=isVision, binding=binding)
	end
	
end

runApp(scene) = runApp(scene.gpuDevice, scene)

function runApp(gpuDevice, scene)
	currentTextureView = WGPUCore.getCurrentTexture(scene.presentContext[]);
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

	for object in scene.objects
		render(renderPass, renderPassOptions, object)
	end

	# WGPUCore.setViewport(renderPass, 150, 150, 300, 300, 0, 1)
	# for object in scene.objects
		# render(renderPass, renderPassOptions, object)
	# end
	
	WGPUCore.endEncoder(renderPass)
	WGPUCore.submit(gpuDevice.queue, [WGPUCore.finish(cmdEncoder),])
	WGPUCore.present(scene.presentContext[])
end

