export defaultGrid, MainGrid

mutable struct MainGrid <: Renderable
	gpuDevice
	vertexData
	colorData
	indexData
	uniformData
	uniformBuffer
	indexBuffer
	vertexBuffer
	pipelineLayout
	renderPipeline
end

function defaultGrid(; origin=[0, 0, 0], len=4.0, segments = 10)
	segLen = len/segments
	vertexData = ((len/2.0) |> Float32) .- cat(
		cat(
			[[
				[origin[1] + i*segLen,	origin[2] + len/2.0, 	origin[3] 			, 			1],
				[origin[1] + i*segLen,	origin[2] + len/2.0, 	origin[3] + len 	, 			1],
				[origin[1]			 , 	origin[2] + len/2.0, 	origin[3] + i*segLen, 			1],
				[origin[1] + len	 ,	origin[2] + len/2.0, 	origin[3] + i*segLen, 			1],
			] for i in 0:segments]
			..., 
		dims=2)..., dims=2
	) .|> Float32 

	unitColor = cat([
		[0.6, 0.6, 0.6, 1.0],
		[0.6, 0.6, 0.6, 1.0],
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 2), outer=(1, segments+1))

	indexData = reshape(0:4*(segments+1)-1, 2, 2*(segments + 1)) .|> UInt32
		
	MainGrid(
		nothing,
		vertexData,
		colorData,
		indexData,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
	)
end

function prepareObject(gpuDevice, grid::MainGrid)
	uniformData = computeUniformData(grid)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"Grid Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(grid, :uniformData, uniformData)
	setfield!(grid, :uniformBuffer, uniformBuffer)
	setfield!(grid, :gpuDevice, gpuDevice)
	setfield!(grid, :indexBuffer, getIndexBuffer(gpuDevice, grid))
	setfield!(grid, :vertexBuffer, getVertexBuffer(gpuDevice, grid))
	return grid
end


function preparePipeline(gpuDevice, scene, grid::MainGrid; isVision=false, binding=2)
	bindingLayouts = []
	bindings = []
	cameraUniform = getfield(scene.camera, :uniformBuffer)
	vertexBuffer = getfield(grid, :vertexBuffer)
	uniformBuffer = getfield(grid, :uniformBuffer)
	indexBuffer = getfield(grid, :indexBuffer)
	append!(
		bindingLayouts, 
		getBindingLayouts(scene.camera; binding = 0), 
		getBindingLayouts(grid; binding=binding)
	)
	append!(
		bindings, 
		getBindings(scene.camera, cameraUniform; binding = 0), 
		getBindings(grid, uniformBuffer; binding=binding)
	)
	pipelineLayout = WGPUCore.createPipelineLayout(gpuDevice, "PipeLineLayout", bindingLayouts, bindings)
	grid.pipelineLayout = pipelineLayout
	renderPipelineOptions = getRenderPipelineOptions(
		scene,
		grid,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label=" Grid RENDER PIPELINE "
	)
	grid.renderPipeline = renderPipeline
end


function getShaderCode(grid::MainGrid; isVision=false, islight=false, binding=0)
	isVision = false
	islight = islight && isdefined(grid, :normalData) # TODO this needs to be transferred.
	name = Symbol(:Grid, binding)
	gridType = typeof(grid)
	gridUniform = Symbol(gridType, :Uniform)
	shaderSource = quote
		struct $gridUniform
			transform::Mat4{Float32}
		end
		
		@var Uniform 0 $binding $name::@user $gridUniform
		
		@vertex function vs_main(vertexIn::@user VertexInput)::@user VertexOutput
			@var out::@user VertexOutput
			out.pos = $(name).transform*vertexIn.pos
			out.pos = camera.transform*out.pos
			out.vColor = vertexIn.vColor
			return out
		end

		@fragment function fs_main(fragmentIn::@user VertexOutput)::@location 0 Vec4{Float32}
			@var color::Vec4{Float32} = fragmentIn.vColor
			return color
		end

 	end
 	
	return shaderSource
end


# TODO check it its called multiple times
function getVertexBuffer(gpuDevice, grid::MainGrid)
	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat(
			[
				grid.vertexData, 
				grid.colorData, 
			]...
		), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end


function getVertexBufferLayout(grid::MainGrid; offset=0)
	WGPUCore.GPUVertexBufferLayout => [
		:arrayStride => 8*4,
		:stepMode => "Vertex",
		:attributes => [
			:attribute => [
				:format => "Float32x4",
				:offset => 0,
				:shaderLocation => offset + 0
			],
			:attribute => [
				:format => "Float32x4",
				:offset => 4*4,
				:shaderLocation => offset + 1
			]	
		]
	]
end


function getBindingLayouts(grid::MainGrid; binding=4)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		]
	]
	return bindingLayouts
end


function getBindings(grid::MainGrid, uniformBuffer; binding=4)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		]
	]
end


function getRenderPipelineOptions(scene, grid::MainGrid)
	renderpipelineOptions = [
		WGPUCore.GPUVertexState => [
			:_module => scene.cshader.internal[],						# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",							# SET THIS (FIXED FOR NOW)
			:buffers => [
				getVertexBufferLayout(grid)
			]
		],
		WGPUCore.GPUPrimitiveState => [
			:topology => "LineList",
			:frontFace => "CCW",
			:cullMode => "None",
			:stripIndexFormat => "Undefined"
		],
		WGPUCore.GPUDepthStencilState => [
			:depthWriteEnabled => true,
			:depthCompare => WGPUCompareFunction_LessEqual,
			:format => WGPUTextureFormat_Depth24Plus
		],
		WGPUCore.GPUMultiSampleState => [
			:count => 1,
			:mask => typemax(UInt32),
			:alphaToCoverageEnabled=>false,
		],
		WGPUCore.GPUFragmentState => [
			:_module => scene.cshader.internal[],						# SET THIS
			:entryPoint => "fs_main",							# SET THIS (FIXED FOR NOW)
			:targets => [
				WGPUCore.GPUColorTargetState =>	[
					:format => scene.renderTextureFormat,				# SET THIS
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
	renderpipelineOptions
end

