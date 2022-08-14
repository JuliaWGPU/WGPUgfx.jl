
using WGPUgfx
using WGPU
using GLFW

using WGPU_jll
using Images

using OhMyREPL
using Eyeball
using GeometryBasics
using LinearAlgebra
using Rotations
using StaticArrays

WGPU.SetLogLevel(WGPULogLevel_Debug)

canvas = WGPU.defaultInit(WGPU.WGPUCanvas)
gpuDevice = WGPU.getDefaultDevice()

scene = Scene(canvas, [])

cube = defaultCube()
push!(scene.objects, cube)

camera = Camera()

cshader = defaultShader(gpuDevice, typeof(cube))

renderTextureFormat = WGPU.getPreferredFormat(canvas)

scene = []

vertexBuffer = getVertexBuffer(gpuDevice, cube)
uniformData = defaultUniformData(typeof(cube))
uniformBuffer = getUniformBuffer(gpuDevice, cube)

indexBuffer = getIndexBuffer(gpuDevice, cube)

push!(scene, cube)

bindingLayouts = [
	WGPU.WGPUBufferEntry => [
		:binding => 0,
		:visibility => ["Vertex", "Fragment"],
		:type => "Uniform"
	],
]

bindings = [
	WGPU.GPUBuffer => [
		:binding => 0,
		:buffer => uniformBuffer,
		:offset => 0,
		:size => uniformBuffer.size
	],
]

(bindGroupLayouts, bindGroup) = WGPU.makeBindGroupAndLayout(gpuDevice, bindingLayouts, bindings)

pipelineLayout = WGPU.createPipelineLayout(gpuDevice, "PipeLineLayout", bindGroupLayouts)

presentContext = WGPU.getContext(canvas)

WGPU.determineSize(presentContext[])

WGPU.config(presentContext, device=gpuDevice, format = renderTextureFormat)

getVertexBufferLayouts(scene) = map(getVertexBufferLayout, scene)

renderpipelineOptions = [
	WGPU.GPUVertexState => [
		:_module => cshader.internal[],
		:entryPoint => "vs_main",
		:buffers => getVertexBufferLayouts(scene)
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
		:_module => cshader.internal[],
		:entryPoint => "fs_main",
		:targets => [
			WGPU.GPUColorTargetState =>	[
				:format => renderTextureFormat,
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

prevTime = time()
try
	while !GLFW.WindowShouldClose(canvas.windowRef[])
		a1 = 0.3f0
		a2 = time()
		s = 0.6f0
		
		ortho = s.*Matrix{Float32}(I, (3, 3))
		rotxy = RotXY(a1, a2)
		uniformData[1:3, 1:3] .= rotxy*ortho
		
		(tmpBuffer, _) = WGPU.createBufferWithData(
			gpuDevice, "ROTATION BUFFER", uniformData, "CopySrc"
		)
		
		currentTextureView = WGPU.getCurrentTexture(presentContext[]) |> Ref;
		cmdEncoder = WGPU.createCommandEncoder(gpuDevice, "CMD ENCODER")
		WGPU.copyBufferToBuffer(cmdEncoder, 
			tmpBuffer, 
			0, 
			uniformBuffer, 
			0, 
			sizeof(uniformData)
		)
		
		renderPassOptions = [
			WGPU.GPUColorAttachments => [
				:attachments => [
					WGPU.GPUColorAttachment => [
						:view => currentTextureView[],
						:resolveTarget => C_NULL,
						# :clearValue => (abs(0.8f0*sin(a2)), abs(0.8f0*cos(a2)), 0.3f0, 1.0f0),
						:clearValue => (0.8, 0.8, 0.7, 1.0),
						:loadOp => WGPULoadOp_Clear,
						:storeOp => WGPUStoreOp_Store,
					],
				]
			],
		]
		
		renderPass = WGPU.beginRenderPass(cmdEncoder, renderPassOptions; label= "BEGIN RENDER PASS")
		
		WGPU.setPipeline(renderPass, renderPipeline)
		WGPU.setIndexBuffer(renderPass, indexBuffer, "Uint32")
		WGPU.setVertexBuffer(renderPass, 0, vertexBuffer)
		WGPU.setBindGroup(renderPass, 0, bindGroup, UInt32[], 0, 99 )
		WGPU.drawIndexed(renderPass, Int32(indexBuffer.size/sizeof(UInt32)); instanceCount = 1, firstIndex=0, baseVertex= 0, firstInstance=0)
		WGPU.endEncoder(renderPass)
		WGPU.submit(gpuDevice.queue, [WGPU.finish(cmdEncoder),])
		WGPU.present(presentContext[])
		GLFW.PollEvents()
		println("FPS : $(1/(a2 - prevTime))")
		# WGPU.destroy(tmpBuffer)
		# WGPU.destroy(currentTextureView[])
		prevTime = a2
	end
finally
	GLFW.DestroyWindow(canvas.windowRef[])
end
