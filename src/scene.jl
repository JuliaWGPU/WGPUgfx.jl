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

function composeShader(gpuDevice, scene)
	src = quote end

	islight = (scene.light != nothing)

	push!(src.args, getShaderCode(typeof(scene.camera); binding=0))
	push!(src.args, getShaderCode(typeof(scene.light); binding=1))
	
	for (binding, object) in enumerate(scene.objects)
		if typeof(object) == Lighting
			islight = true
		end
		push!(src.args, getShaderCode(typeof(object); binding = binding + 1))
	end

	bindingCount = length(src.args) # TODO we might need to track count
	
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
		
		@vertex function vs_main(in::@user VertexInput)::@user VertexOutput
			@var out::@user VertexOutput
			out.pos = camera.transform*in.pos
			out.vColor = in.vColor
			if $islight
				out.vNormal = camera.transform*in.vNormal
			end
			return out
		end
		
		@fragment function fs_main(in::@user VertexOutput)::@location 0 Vec4{Float32}
			if $islight
				@let N::Vec3{Float32} = normalize(in.vNormal.xyz)
				@let L::Vec3{Float32} = normalize(lighting.position.xyz - in.pos.xyz)
				@let V::Vec3{Float32} = normalize(camera.eye.xyz - in.pos.xyz)
				@let H::Vec3{Float32} = normalize(L + V)
				@let diffuse::Float32 = lighting.diffuseIntensity*max(dot(N, L), 0.0)
				@let specular::Float32 = lighting.specularIntensity*pow(max(dot(N, H), 0.0), lighting.specularShininess)
				@let ambient::Float32 = lighting.ambientIntensity
				return in.vColor*(ambient + diffuse) + lighting.specularColor*specular
			else
				return in.vColor
			end
		end
	end
	
	push!(src.args, defaultSource)
	createShaderObj(gpuDevice, src)
end


setup(scene) = setup(scene.gpuDevice, scene)

function setup(gpuDevice, scene)
	cshader = composeShader(gpuDevice, scene)
	scene.cshader = cshader
	@info cshader.src

	prepareObject(gpuDevice, scene.camera)
	scene.camera.eye = ([0.0, 0.0, -4.0] .|> Float32)

	prepareObject(gpuDevice, scene.light)

	scene.renderTextureFormat = WGPU.getPreferredFormat(scene.canvas)
	presentContext = WGPU.getContext(scene.canvas)
	WGPU.determineSize(presentContext[])
	WGPU.config(presentContext, device=gpuDevice, format = scene.renderTextureFormat)
	scene.presentContext = presentContext
	
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

	# TODO what if we have multiple sources of light
	# TODO what about shadows
	for (binding, object) in enumerate(scene.objects)
		if typeof(object) == Lighting
			scene.islight = true
		end
	end

	for (binding, object) in enumerate(scene.objects)
		prepareObject(gpuDevice, object)
		preparePipeline(gpuDevice, scene, object)
	end

end


function runApp(scene, gpuDevice)
	currentTextureView = WGPU.getCurrentTexture(scene.presentContext[]);
	cmdEncoder = WGPU.createCommandEncoder(gpuDevice, "CMD ENCODER")

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
