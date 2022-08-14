module SceneMod

using WGPU_jll
using WGPU
using Rotations
using CoordinateTransformations
using MacroTools
using LinearAlgebra

include("shader.jl")

using .ShaderMod

export Scene, composeShader, defaultCamera, Camera, defaultCube, Cube, setup, runApp

mutable struct Scene
	canvas
	objects # ::Union{WorldObject, ObjectGroup}
	indexBuffer
	vertexBuffer
	uniformData
	uniformBuffer
	presentContext
	bindGroup
	camera
end

# prefer push! over add
function add(scene, obj)
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
			out.pos = rLocals.transform*in.pos
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
		if typeof(obj) == Cube
			push!(layout, getVertexBufferLayout(typeof(obj)))
		end
	end
	return layout
end

function setup(scene, gpuDevice)

	cshader = composeShader(scene, gpuDevice)
	
	renderTextureFormat = WGPU.getPreferredFormat(scene.canvas)

	bindings = []
	bindingLayouts = []
	uniformData = nothing
	uniformBuffer = nothing
	indexBuffer = nothing
	vertexBuffer = nothing
	
	for obj in scene.objects
		if typeof(obj) == Cube
			vertexBuffer =getVertexBuffer(gpuDevice, obj)
			uniformData = defaultUniformData(typeof(obj))
			uniformBuffer = getUniformBuffer(gpuDevice, obj)
			indexBuffer = getIndexBuffer(gpuDevice, obj)
			push!(bindingLayouts, getBindingLayouts(typeof(obj))...)
			push!(bindings, getBindings(typeof(obj), uniformBuffer)...)
		end
	end
	
	scene.uniformData = uniformData
	scene.uniformBuffer = uniformBuffer
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
			:_module => cshader.internal[],					# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",						# SET THIS (FIXED FOR NOW)
			:buffers => getVertexBufferLayouts(scene.objects)
		],
		WGPU.GPUPrimitiveState => [
			:topology => "TriangleList",
			:frontFace => "CCW",
			:cullMode => "Back",
			:stripIndexFormat => "Undefined"
		],
		WGPU.GPUDepthStencilState => [],
		WGPU.GPUMultiSampleState => [
			:count => 1,
			:mask => typemax(UInt32),
			:alphaToCoverageEnabled=>false
		],
		WGPU.GPUFragmentState => [
			:_module => cshader.internal[],					# SET THIS
			:entryPoint => "fs_main",						# SET THIS (FIXED FOR NOW)
			:targets => [
				WGPU.GPUColorTargetState =>	[
					:format => renderTextureFormat,			# SET THIS
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
	
	renderPipeline = WGPU.createRenderPipeline(
		gpuDevice, pipelineLayout, 
		renderpipelineOptions; 
		label=" "
	)
	return (renderPipeline, nothing)
end


function runApp(scene, gpuDevice, renderPipeline)
	a1 = 0.3f0
	a2 = time()
	s = 0.6f0

	ortho = s.*Matrix{Float32}(I, (3, 3))
	rotxy = RotXY(a1, a2)
	scene.uniformData[1:3, 1:3] .= rotxy*ortho
	
	(tmpBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, "ROTATION BUFFER", scene.uniformData, "CopySrc"
	)
	
	currentTextureView = WGPU.getCurrentTexture(scene.presentContext[]) |> Ref;
	cmdEncoder = WGPU.createCommandEncoder(gpuDevice, "CMD ENCODER")
	WGPU.copyBufferToBuffer(cmdEncoder, 
		tmpBuffer, 
		0, 
		scene.uniformBuffer, 
		0, 
		sizeof(scene.uniformData)
	)
	
	renderPassOptions = [
		WGPU.GPUColorAttachments => [
			:attachments => [
				WGPU.GPUColorAttachment => [
					:view => currentTextureView[],
					:resolveTarget => C_NULL,
					:clearValue => (0.8, 0.8, 0.7, 1.0),
					:loadOp => WGPULoadOp_Clear,
					:storeOp => WGPUStoreOp_Store,
				],
			]
		],
	]
	
	renderPass = WGPU.beginRenderPass(cmdEncoder, renderPassOptions; label= "BEGIN RENDER PASS")
	
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
