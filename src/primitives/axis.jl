export defaultAxis, MainAxis

mutable struct MainAxis <: Renderable
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


function defaultAxis(; origin=[0, 0, 0], len=1.0)
	vertexData = cat([
		[origin[1], 		origin[2], 			origin[3], 			1],
		[origin[1] + len, 	origin[2], 			origin[3], 			1],
		[origin[1], 		origin[2], 			origin[3], 			1],
		[origin[1], 		origin[2] + len, 	origin[3], 			1],
		[origin[1], 		origin[2], 			origin[3], 			1],
		[origin[1], 		origin[2], 			origin[3] + len, 	1],
	]..., dims=2) .|> Float32

	unitColor = cat([
		[0.8, 0.1, 0.1, 1],
		[0.1, 0.8, 0.1, 1],
		[0.1, 0.1, 0.8, 1],
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 2))

	indexData = cat([
		[0, 1],
		[2, 3],
		[4, 5]
	]..., dims=2) .|> UInt32

	MainAxis(
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

function prepareObject(gpuDevice, axis::MainAxis)
	uniformData = computeUniformData(axis)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"Axis Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(axis, :uniformData, uniformData)
	setfield!(axis, :uniformBuffer, uniformBuffer)
	setfield!(axis, :gpuDevice, gpuDevice)
	setfield!(axis, :indexBuffer, getIndexBuffer(gpuDevice, axis))
	setfield!(axis, :vertexBuffer, getVertexBuffer(gpuDevice, axis))
	return axis
end


function preparePipeline(gpuDevice, scene, axis::MainAxis; isVision=false, binding=2)
	bindingLayouts = []
	bindings = []
	cameraUniform = getfield(scene.camera, :uniformBuffer)
	vertexBuffer = getfield(axis, :vertexBuffer)
	uniformBuffer = getfield(axis, :uniformBuffer)
	indexBuffer = getfield(axis, :indexBuffer)
	append!(
		bindingLayouts, 
		getBindingLayouts(scene.camera; binding = 0), 
		getBindingLayouts(axis; binding=binding-1)
	)
	append!(
		bindings, 
		getBindings(scene.camera, cameraUniform; binding = 0), 
		getBindings(axis, uniformBuffer; binding=binding-1)
	)
	pipelineLayout = WGPUCore.createPipelineLayout(gpuDevice, "PipeLineLayout", bindingLayouts, bindings)
	axis.pipelineLayout = pipelineLayout
	renderPipelineOptions = getRenderPipelineOptions(
		scene,
		axis,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label=" AXIS RENDER PIPELINE "
	)
	axis.renderPipeline = renderPipeline
end

function defaultUniformData(::Type{<:MainAxis}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

# TODO for now axis is static
# definitely needs change based on position, rotation etc ...
function computeUniformData(axis::MainAxis)
	return defaultUniformData(typeof(axis))
end


Base.setproperty!(axis::MainAxis, f::Symbol, v) = begin
	setfield!(axis, f, v)
	setfield!(axis, :uniformData, f==:uniformData ? v : computeUniformData(axis))
	updateUniformBuffer(axis)
end

Base.getproperty(axis::MainAxis, f::Symbol) = begin
	getfield(axis, f)
end

function getUniformData(axis::MainAxis)
	return axis.uniformData
end

function updateUniformBuffer(axis::MainAxis)
	data = SMatrix{4, 4}(axis.uniformData[:])
	# @info :UniformBuffer data
	WGPUCore.writeBuffer(
		axis.gpuDevice.queue, 
		getfield(axis, :uniformBuffer),
		data,
	)
end

function readUniformBuffer(axis::MainAxis)
	data = WGPUCore.readBuffer(
		axis.gpuDevice,
		getfield(axis, :uniformBuffer),
		0,
		getfield(axis, :uniformBuffer).size
	)
	datareinterpret = reinterpret(Mat4{Float32}, data)[1]
	# @info "Received Buffer" datareinterpret
end

function getUniformBuffer(axis::MainAxis)
	getfield(axis, :uniformBuffer)
end

function getShaderCode(axis::MainAxis; isVision=false, islight=false, binding=0)
	binding = binding-1
	isVision = false
	islight = islight && isdefined(axis, :normalData) # TODO this needs to be transferred.
	name = Symbol(:axis, binding)
	axisType = typeof(axis)
	axisUniform = Symbol(axisType, :Uniform)
	shaderSource = quote
		struct $axisUniform
			transform::Mat4{Float32}
		end
		
		@var Uniform 0 $binding $name::@user $axisUniform
		
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
function getVertexBuffer(gpuDevice, axis::MainAxis)
	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat(
			[
				axis.vertexData, 
				axis.colorData, 
			]...
		), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end


function getIndexBuffer(gpuDevice, axis::MainAxis)
	(indexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		axis.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end


function getVertexBufferLayout(axis::MainAxis; offset=0)
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


function getBindingLayouts(axis::MainAxis; binding=4)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		]
	]
	return bindingLayouts
end


function getBindings(axis::MainAxis, uniformBuffer; binding=4)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		]
	]
end


function getRenderPipelineOptions(scene, axis::MainAxis)
	renderpipelineOptions = [
		WGPUCore.GPUVertexState => [
			:_module => scene.cshader.internal[],						# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",							# SET THIS (FIXED FOR NOW)
			:buffers => [
				getVertexBufferLayout(axis)
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

function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, axis::MainAxis)
	WGPUCore.setPipeline(renderPass, axis.renderPipeline)
	WGPUCore.setIndexBuffer(renderPass, axis.indexBuffer, "Uint32")
	WGPUCore.setVertexBuffer(renderPass, 0, axis.vertexBuffer)
	WGPUCore.setBindGroup(renderPass, 0, axis.pipelineLayout.bindGroup, UInt32[], 0, 99)
	WGPUCore.drawIndexed(renderPass, Int32(axis.indexBuffer.size/sizeof(UInt32)); instanceCount = 1, firstIndex=0, baseVertex= 0, firstInstance=0)
end
