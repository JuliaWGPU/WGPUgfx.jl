module SceneMod

using WGPU_jll
using WGPU
using Rotations
using CoordinateTransformations
using MacroTools
using LinearAlgebra
using StaticArrays
using GeometryBasics: Mat4

include("shader.jl")

using .ShaderMod

export Scene, composeShader, defaultCamera, Camera, defaultCube,
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


function addObject!(scene, obj)
	push!(scene.objects, obj)
	setup(scene)
end

function composeShader(gpuDevice, scene, object; binding=2)
	src = quote end

	islight = (scene.light != nothing)

	push!(src.args, getShaderCode(typeof(scene.camera); islight=islight, binding=0))

	islight && push!(src.args, getShaderCode(typeof(scene.light); islight=islight, binding=1))

	defaultSource = quote
		struct VertexInput
			@location 0 pos::Vec4{Float32}
			@location 1 vColor::Vec4{Float32}
			if $islight
				@location 2 vNormal::Vec4{Float32}
			end
		end
		
		struct VertexOutput
			@location 0 vColor::Vec4{Float32}
			if $islight
				@location 1 vNormal::Vec4{Float32}
			end
			@builtin position pos::Vec4{Float32}
		end
	end
	
	push!(src.args, defaultSource)
	push!(src.args, getShaderCode(typeof(object); islight=islight, binding = binding))
	createShaderObj(gpuDevice, src)
end


setup(scene) = setup(scene.gpuDevice, scene)

function setup(gpuDevice, scene)

	scene.renderTextureFormat = WGPU.getPreferredFormat(scene.canvas)
	presentContext = WGPU.getContext(scene.canvas)
	WGPU.determineSize(presentContext[])
	WGPU.config(presentContext, device=gpuDevice, format = scene.renderTextureFormat)
	scene.presentContext = presentContext

	for (binding, object) in enumerate(scene.objects)
		cshader = composeShader(gpuDevice, scene, object; binding=binding + 1)
		scene.cshader = cshader
		@info cshader.src
		if binding == 1
			prepareObject(gpuDevice, scene.camera)
		end
		scene.camera.eye = ([0.0, 0.0, -4.0] .|> Float32)
		(scene.light != nothing) && prepareObject(gpuDevice, scene.light)
		prepareObject(gpuDevice, object)
		preparePipeline(gpuDevice, scene, object; binding=binding + 1)
	end
	
end

runApp(scene) = runApp(scene.gpuDevice, scene)

function runApp(gpuDevice, scene)
	currentTextureView = WGPU.getCurrentTexture(scene.presentContext[]);
	cmdEncoder = WGPU.createCommandEncoder(gpuDevice, "CMD ENCODER")

	scene.depthTexture = WGPU.createTexture(
		gpuDevice,
		"DEPTH TEXTURE",
		(scene.canvas.size..., 1),
		1,
		1,
		WGPUTextureDimension_2D,
		WGPUTextureFormat_Depth24Plus,
		WGPU.getEnum(WGPU.WGPUTextureUsage, "RenderAttachment")
	)
	
	scene.depthView = WGPU.createView(scene.depthTexture)

	renderPassOptions = [
		WGPU.GPUColorAttachments => [
			:attachments => [
				WGPU.GPUColorAttachment => [
					:view => currentTextureView,
					:resolveTarget => C_NULL,
					:clearValue => (0.8, 0.8, 0.7, 1.0),
					:loadOp => WGPULoadOp_Clear,
					:storeOp => WGPUStoreOp_Store,
				],
			]
		],
		WGPU.GPUDepthStencilAttachments => [
			:attachments => [
				WGPU.GPUDepthStencilAttachment => [
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
	

	renderPass = WGPU.beginRenderPass(cmdEncoder, renderPassOptions |> Ref; label= "BEGIN RENDER PASS")

	for object in scene.objects
		render(renderPass, renderPassOptions, object)
	end
	
	WGPU.endEncoder(renderPass)
	WGPU.submit(gpuDevice.queue, [WGPU.finish(cmdEncoder),])
	WGPU.present(scene.presentContext[])
end

end
