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
	defaultCircle, Circle, setup, runApp, defaultLighting, Lighting


mutable struct Scene
	canvas
	objects 					# ::Union{WorldObject, ObjectGroup}
	indexBuffer
	vertexBuffer
	uniformData
	uniformBuffer
	presentContext
	bindGroup
	camera
	lighting
	depthTexture
	depthView
end


# prefer push! over add
function attach(scene, obj)
	push!(scene.objects, obj)
	setup(scene)
end


function composeShader(scene, gpuDevice)
	src = quote end
	
	for object in scene.objects
		push!(src.args, getShaderCode(typeof(object)))
	end
	
	defaultSource = quote
		struct VertexInput
			@location 0 pos::Vec4{Float32}
			@location 1 vColor::Vec4{Float32}
		end
		
		struct VertexOutput
			@location 0 vColor::Vec4{Float32}
			@builtin position pos::Vec4{Float32}
		end
		
		@vertex function vs_main(in::@user VertexInput)::@user VertexOutput
			@var out::@user VertexOutput
			out.pos = camera.transform*in.pos
			out.vColor = in.vColor
			return out
		end
		
		@fragment function fs_main(in::@user VertexOutput)::@location 0 Vec4{Float32}
			return in.vColor
		end
	end
	
	push!(src.args, defaultSource)
	createShaderObj(gpuDevice, src)
end


function getVertexBufferLayouts(objs)
	layout = []
	for obj in objs
		if !(typeof(obj) in [Camera, Lighting])
			push!(layout, getVertexBufferLayout(typeof(obj)))
		end
	end
	return layout
end


function setup(scene, gpuDevice)
	cshader = composeShader(scene, gpuDevice)
	@info cshader.src
	renderTextureFormat = WGPU.getPreferredFormat(scene.canvas)
	
	bindings = []
	bindingLayouts = []
	indexBuffer = nothing
	vertexBuffer = nothing
	
	for obj in scene.objects
		prepareObject(gpuDevice, obj)
		if typeof(obj) == Camera
			scene.camera = obj
			push!(bindingLayouts, getBindingLayouts(typeof(obj))...)
			push!(bindings, getBindings(typeof(obj), getfield(obj, :uniformBuffer))...)
		elseif typeof(obj) == Lighting
			scene.lighting = obj
			push!(bindingLayouts, getBindingLayouts(typeof(obj))...)
			push!(bindings, getBindings(typeof(obj), getfield(obj, :uniformBuffer))...)
		else
			vertexBuffer =getVertexBuffer(gpuDevice, obj)
			uniformData = defaultUniformData(typeof(obj))
			uniformBuffer = getUniformBuffer(obj)
			indexBuffer = getIndexBuffer(gpuDevice, obj)
			push!(bindingLayouts, getBindingLayouts(typeof(obj))...)
			push!(bindings, getBindings(typeof(obj), uniformBuffer)...)
		end
	end

	scene.camera.eye = ([0.0, 0.0, -4.0] .|> Float32)
		
	scene.indexBuffer = indexBuffer
	scene.vertexBuffer = vertexBuffer
	
	(bindGroupLayouts, bindGroup) = WGPU.makeBindGroupAndLayout(gpuDevice, bindingLayouts, bindings)
	scene.bindGroup = bindGroup
	pipelineLayout = WGPU.createPipelineLayout(gpuDevice, "PipeLineLayout", bindGroupLayouts)
	presentContext = WGPU.getContext(scene.canvas)
	WGPU.determineSize(presentContext[])
	WGPU.config(presentContext, device=gpuDevice, format = renderTextureFormat)
	
	scene.presentContext = presentContext
	
	renderpipelineOptions = [
		WGPU.GPUVertexState => [
			:_module => cshader.internal[],						# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",							# SET THIS (FIXED FOR NOW)
			:buffers => getVertexBufferLayouts(scene.objects)
		],
		WGPU.GPUPrimitiveState => [
			:topology => "TriangleList",
			:frontFace => "CCW",
			:cullMode => "Front",
			:stripIndexFormat => "Undefined"
		],
		WGPU.GPUDepthStencilState => [
			:depthWriteEnabled => true,
			:depthCompare => WGPUCompareFunction_LessEqual,
			:format => WGPUTextureFormat_Depth24Plus
		],
		WGPU.GPUMultiSampleState => [
			:count => 1,
			:mask => typemax(UInt32),
			:alphaToCoverageEnabled=>false,
		],
		WGPU.GPUFragmentState => [
			:_module => cshader.internal[],						# SET THIS
			:entryPoint => "fs_main",							# SET THIS (FIXED FOR NOW)
			:targets => [
				WGPU.GPUColorTargetState =>	[
					:format => renderTextureFormat,				# SET THIS
					:color => [
						:srcFactor => "One",
						:dstFactor => "Zero",
						:operation => "Add"
					],
					:alpha => [
						:srcFactor => "One",
						:dstFactor => "Zero",
						:operation => "Add",
					]
				],
			]
		]
	]

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

	renderPipeline = WGPU.createRenderPipeline(
		gpuDevice, pipelineLayout, 
		renderpipelineOptions; 
		label=" RENDER PIPELINE "
	)
	return (renderPipeline, scene.depthTexture)
end


function runApp(scene, gpuDevice, renderPipeline)

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
	
	WGPU.setPipeline(renderPass, renderPipeline)
	WGPU.setIndexBuffer(renderPass, scene.indexBuffer, "Uint32")
	WGPU.setVertexBuffer(renderPass, 0, scene.vertexBuffer)
	WGPU.setBindGroup(renderPass, 0, scene.bindGroup, UInt32[], 0, 99)
	WGPU.drawIndexed(renderPass, Int32(scene.indexBuffer.size/sizeof(UInt32)); instanceCount = 1, firstIndex=0, baseVertex= 0, firstInstance=0)
	WGPU.endEncoder(renderPass)
	WGPU.submit(gpuDevice.queue, [WGPU.finish(cmdEncoder),])
	WGPU.present(scene.presentContext[])
end

end
