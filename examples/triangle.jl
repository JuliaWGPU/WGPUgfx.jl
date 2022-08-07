using WGPUgfx
using WGPU
using GLFW

using WGPU_jll
using Images

using WGPUgfx.MacroMod: wgslCode

WGPU.SetLogLevel(WGPULogLevel_Debug)

shaderSource = quote
	struct VertexInput
		@builtin vertex_index vertex_index::UInt32
	end

	struct VertexOutput
		@location 0 color::Vec4{Float32}
		@builtin position pos::Vec4{Float32}
	end

	@vertex function vs_main(in::@user VertexInput)::@user VertexOutput
		@var positions = "array<vec2<f32>, 3>(vec2<f32>(0.0, -1.0), vec2<f32>(1.0, 1.0), vec2<f32>(-1.0, 1.0));"
		@let index = Int32(in.vertex_index)
		@let p::Vec2{Float32} = positions[index]
		@var out::@user VertexOutput
		out.pos = Vec4{Float32}(p, 0.0, 1.0)
		out.color = Vec4{Float32}(p, 0.5, 1.0)
		return out
	end

	@fragment function fs_main(in::@user VertexOutput)::@location 0 Vec4{Float32}
		return in.color
	end
end |> wgslCode |> Vector{UInt8}

canvas = WGPU.defaultInit(WGPU.WGPUCanvas)
gpuDevice = WGPU.getDefaultDevice()
shadercode = WGPU.loadWGSL(shaderSource) |> first
cshader = Ref(WGPU.createShaderModule(gpuDevice, "shadercode", shadercode, nothing, nothing));

bindingLayouts = []
bindings = []

(bindGroupLayouts, bindGroup) = WGPU.makeBindGroupAndLayout(gpuDevice, bindingLayouts, bindings)


pipelineLayout = WGPU.createPipelineLayout(gpuDevice, "PipeLineLayout", bindGroupLayouts)
# swapChainFormat = wgpuSurfaceGetPreferredFormat(canvas.surface[], gpuDevice.adapter.internal[])
swapChainFormat = WGPU.getPreferredFormat(canvas)
presentContext = WGPU.getContext(canvas)
ctxtSize = WGPU.determineSize(presentContext[]) .|> Int

WGPU.config(presentContext, device=gpuDevice, format = swapChainFormat)

renderpipelineOptions = [
	WGPU.GPUVertexState => [
		:_module => cshader[],
		:entryPoint => "vs_main",
		:buffers => []
	],
	WGPU.GPUPrimitiveState => [
		:topology => "TriangleList",
		:frontFace => "CCW",
		:cullMode => "None",
		:stripIndexFormat => "Undefined"
	],
	WGPU.GPUDepthStencilState => [],
	WGPU.GPUMultiSampleState => [
		:count => 1,
		:mask => typemax(UInt32),
		:alphaToCoverageEnabled=>false
	],
	WGPU.GPUFragmentState => [
		:_module => cshader[],
		:entryPoint => "fs_main",
		:targets => [
			WGPU.GPUColorTargetState =>	[
				:format => swapChainFormat,
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

renderPipeline =  WGPU.createRenderPipeline(
	gpuDevice, pipelineLayout, 
	renderpipelineOptions; 
	label = "RENDER PIPE LABEL "
)

function drawFunction()
	WGPU.draw(renderPass, 3, 1, 0, 0)
	WGPU.end(renderPass)
end

WGPU.attachDrawFunction(canvas, drawFunction)

try
	while !GLFW.WindowShouldClose(canvas.windowRef[])
		nextTexture = WGPU.getCurrentTexture(presentContext[]) |> Ref
		cmdEncoder = WGPU.createCommandEncoder(gpuDevice, "cmdEncoder")
		renderPassOptions = [
			WGPU.GPUColorAttachments => [
				:attachments => [
					WGPU.GPUColorAttachment => [
						:view => nextTexture[],
						:resolveTarget => C_NULL,
						:clearValue => (0.0, 0.0, 0.0, 1.0),
						:loadOp => WGPULoadOp_Clear,
						:storeOp => WGPUStoreOp_Store,
					],
				]
			],
		]
		renderPass = WGPU.beginRenderPass(cmdEncoder, renderPassOptions; label= "Begin Render Pass")
		WGPU.setPipeline(renderPass, renderPipeline)
		WGPU.draw(renderPass, 3; instanceCount = 1, firstVertex= 0, firstInstance=0)
		WGPU.endEncoder(renderPass)
		WGPU.submit(gpuDevice.queue, [WGPU.finish(cmdEncoder),])
		WGPU.present(presentContext[])
		GLFW.PollEvents()
	end
finally
	WGPU.destroyWindow(canvas)
end

