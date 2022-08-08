
using WGPUgfx
using WGPU
using GLFW

using WGPU_jll
using Images

using WGPUgfx.MacroMod: wgslCode

using OhMyREPL
using Eyeball
using GeometryBasics
using LinearAlgebra
using Rotations
using StaticArrays

WGPU.SetLogLevel(WGPULogLevel_Debug)

shaderSource = quote
	struct Locals
		transform::Mat4{Float32}
	end

	@var Uniform 0 0 rLocals::@user Locals
	
	struct VertexInput
		@location 0 pos::Vec4{Float32}
		@location 1 texcoord::Vec2{Float32}
	end
	
	struct VertexOutput
		@location 0 texcoord::Vec2{Float32}
		@builtin position pos::Vec4{Float32}
	end
	
	@vertex function vs_main(in::@user VertexInput)::@user VertexOutput
		@let ndc::Vec4{Float32} = rLocals.transform*in.pos
		@var out::@user VertexOutput
		out.pos = Vec4{Float32}(ndc.x, ndc.y, 0.0, 1.0)
		out.texcoord = in.texcoord
		return out
	end
	
	@var Generic 0 1 rTex::Texture2D{Float32}
	@var Generic 0 2 rSampler::Sampler
	
	@fragment function fs_main(in::@user VertexOutput)::@location 0 Vec4{Float32}
		@let value = textureSample(rTex, rSampler, in.texcoord).r;
		return Vec4{Float32}(value, value, value, 1.0)
	end
end |> wgslCode |> Vector{UInt8}

canvas = WGPU.defaultInit(WGPU.WGPUCanvas)
gpuDevice = WGPU.getDefaultDevice()
shadercode = WGPU.loadWGSL(shaderSource) |> first;
cshader = Ref(WGPU.createShaderModule(gpuDevice, "shadercode", shadercode, nothing, nothing));

flatten(x) = reshape(x, (:,))

vertexData =  cat([
    [-1, -1, 1, 1, 0, 0],
    [1, -1, 1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1],
    [-1, 1, 1, 1, 0, 1],
    [-1, 1, -1, 1, 1, 0],
    [1, 1, -1, 1, 0, 0],
    [1, -1, -1, 1, 0, 1],
    [-1, -1, -1, 1, 1, 1],
    [1, -1, -1, 1, 0, 0],
    [1, 1, -1, 1, 1, 0],
    [1, 1, 1, 1, 1, 1],
    [1, -1, 1, 1, 0, 1],
    [-1, -1, 1, 1, 1, 0],
    [-1, 1, 1, 1, 0, 0],
    [-1, 1, -1, 1, 0, 1],
    [-1, -1, -1, 1, 1, 1],
    [1, 1, -1, 1, 1, 0],
    [-1, 1, -1, 1, 0, 0],
    [-1, 1, 1, 1, 0, 1],
    [1, 1, 1, 1, 1, 1],
    [1, -1, 1, 1, 0, 0],
    [-1, -1, 1, 1, 1, 0],
    [-1, -1, -1, 1, 1, 1],
    [1, -1, -1, 1, 0, 1],
]..., dims=2) .|> Float32
   

indexData =   cat([
        [0, 1, 2, 2, 3, 0], 
        [4, 5, 6, 6, 7, 4],  
        [8, 9, 10, 10, 11, 8], 
        [12, 13, 14, 14, 15, 12], 
        [16, 17, 18, 18, 19, 16], 
        [20, 21, 22, 22, 23, 20], 
    ]..., dims=2) .|> UInt32


tmpData = cat([
        [50, 100, 150, 200],
        [100, 150, 200, 50],
        [150, 200, 50, 100],
        [200, 50, 100, 150],
    ]..., dims=2) .|> UInt8
    


textureData = repeat(tmpData, inner=(64, 64))
textureSize = (size(textureData)..., 1)


uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix


(vertexBuffer, _) = WGPU.createBufferWithData(
	gpuDevice, 
	"vertexBuffer", 
	vertexData, 
	["Vertex", "CopySrc"]
)


(indexBuffer, _) = WGPU.createBufferWithData(
	gpuDevice, 
	"indexBuffer", 
	indexData |> flatten, 
	"Index"
)

(uniformBuffer, _) = WGPU.createBufferWithData(
	gpuDevice, 
	"uniformBuffer", 
	uniformData, 
	["Uniform", "CopyDst"]
)

renderTextureFormat = WGPU.getPreferredFormat(canvas)

texture = WGPU.createTexture(
	gpuDevice,
	"texture", 
	textureSize, 
	1,
	1, 
	WGPUTextureDimension_2D,  
	WGPUTextureFormat_R8Unorm,  
	WGPU.getEnum(WGPU.WGPUTextureUsage, ["CopyDst", "TextureBinding"]),
)

textureView = WGPU.createView(texture)

dstLayout = [
	:dst => [
		:texture => texture |> Ref,
		:mipLevel => 0,
		:origin => ((0, 0, 0) .|> Float32)
	],
	:textureData => textureData |> Ref,
	:layout => [
		:offset => 0,
		:bytesPerRow => size(textureData) |> last, # TODO
		:rowsPerImage => size(textureData) |> first
	],
	:textureSize => textureSize
]

sampler = WGPU.createSampler(gpuDevice)

WGPU.writeTexture(gpuDevice.queue; dstLayout...)

bindingLayouts = [
	WGPU.WGPUBufferEntry => [
		:binding => 0,
		:visibility => ["Vertex", "Fragment"],
		:type => "Uniform"
	],
	WGPU.WGPUTextureEntry => [
		:binding => 1,
		:visibility => "Fragment",
		:sampleType => "Float",
		:viewDimension => "2D",
		:multisampled => false
	],
	WGPU.WGPUSamplerEntry => [
		:binding => 2,
		:visibility => "Fragment",
		:type => "Filtering"
	]
]

bindings = [
	WGPU.GPUBuffer => [
		:binding => 0,
		:buffer => uniformBuffer,
		:offset => 0,
		:size => uniformBuffer.size
	],
	WGPU.GPUTextureView =>	[
		:binding => 1,
		:textureView => textureView
	],
	WGPU.GPUSampler => [
		:binding => 2,
		:sampler => sampler
	]
]

(bindGroupLayouts, bindGroup) = WGPU.makeBindGroupAndLayout(gpuDevice, bindingLayouts, bindings)
# 
# cBindingLayoutsList = WGPU.makeEntryList(bindingLayouts) |> Ref
# cBindingsList = WGPU.makeBindGroupEntryList(bindings) |> Ref
# bindGroupLayout = WGPU.createBindGroupLayout(gpuDevice, "Bind Group Layout", cBindingLayoutsList[])
# bindGroup = WGPU.createBindGroup("BindGroup", gpuDevice, bindGroupLayout, cBindingsList[])
# 
# if bindGroupLayout.internal[] == C_NULL
	# bindGroupLayouts = []
# else
	# bindGroupLayouts = map((x)->x.internal[], [bindGroupLayout,])
# end

pipelineLayout = WGPU.createPipelineLayout(gpuDevice, "PipeLineLayout", bindGroupLayouts)

presentContext = WGPU.getContext(canvas)

WGPU.determineSize(presentContext[])

WGPU.config(presentContext, device=gpuDevice, format = renderTextureFormat)

renderpipelineOptions = [
	WGPU.GPUVertexState => [
		:_module => cshader[],
		:entryPoint => "vs_main",
		:buffers => [
			WGPU.GPUVertexBufferLayout => [
				:arrayStride => 6*4,
				:stepMode => "Vertex",
				:attributes => [
					:attribute => [
						:format => "Float32x4",
						:offset => 0,
						:shaderLocation => 0
					],
					:attribute => [
						:format => "Float32x2",
						:offset => 4*4,
						:shaderLocation => 1
					]
				]
			],
		]
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
		:_module => cshader[],
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
		WGPU.copyBufferToBuffer(cmdEncoder, tmpBuffer, 0, uniformBuffer, 0, sizeof(uniformData))
		
		renderPassOptions = [
			WGPU.GPUColorAttachments => [
				:attachments => [
					WGPU.GPUColorAttachment => [
						:view => currentTextureView[],
						:resolveTarget => C_NULL,
						:clearValue => (abs(0.8f0*sin(a2)), abs(0.8f0*cos(a2)), 0.3f0, 1.0f0),
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
		# dataDown = reinterpret(Float32, WGPU.readBuffer(gpuDevice, vertexBuffer, 0, sizeof(vertexData)))
		# @info sum(dataDown .== vertexData |> flatten)
		# @info dataDown
		# println("FPS : $(1/(a2 - prevTime))")
		# WGPU.destroy(tmpBuffer)
		# WGPU.destroy(currentTextureView[])
		prevTime = a2
	end
finally
	GLFW.DestroyWindow(canvas.windowRef[])
end
