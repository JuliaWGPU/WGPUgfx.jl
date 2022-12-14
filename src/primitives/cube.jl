using WGPUNative
using WGPUCore

export defaultCube, Cube

mutable struct Cube
	gpuDevice
	vertexData
	colorData
	indexData
	normalData
	uvs
	uniformData
	uniformBuffer
	indexBuffer
	vertexBuffer
	bindGroup
	renderPipeline
end

function prepareObject(gpuDevice, cube::Cube)
	uniformData = computeUniformData(cube)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"Cube Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(cube, :uniformData, uniformData)
	setfield!(cube, :uniformBuffer, uniformBuffer)
	setfield!(cube, :gpuDevice, gpuDevice)
	setfield!(cube, :indexBuffer, getIndexBuffer(gpuDevice, cube))
	setfield!(cube, :vertexBuffer, getVertexBuffer(gpuDevice, cube))
	return cube
end

function preparePipeline(gpuDevice, scene, cube::Cube; binding=2)
	bindingLayouts = []
	bindings = []
	cameraUniform = getfield(scene.camera, :uniformBuffer)
	vertexBuffer = getfield(cube, :vertexBuffer)
	uniformBuffer = getfield(cube, :uniformBuffer)
	indexBuffer = getfield(cube, :indexBuffer)
	append!(
		bindingLayouts, 
		getBindingLayouts(typeof(scene.camera); binding = 0), 
		scene.light != nothing ? getBindingLayouts(typeof(scene.light); binding = 1) : [], 
		getBindingLayouts(typeof(cube); binding=binding)
	)
	append!(
		bindings, 
		getBindings(typeof(scene.camera), cameraUniform; binding=0), 
		scene.light != nothing ? getBindings(typeof(scene.light), cameraUniform; binding=1) : [], 
		getBindings(typeof(cube), uniformBuffer; binding=binding)
	)
	(bindGroupLayouts, bindGroup) = WGPUCore.makeBindGroupAndLayout(gpuDevice, bindingLayouts, bindings)
	cube.bindGroup = bindGroup
	pipelineLayout = WGPUCore.createPipelineLayout(gpuDevice, "PipeLineLayout", bindGroupLayouts)
	renderPipelineOptions = getRenderPipelineOptions(
		scene,
		cube,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label=" CUBE RENDER PIPELINE "
	)
	cube.renderPipeline = renderPipeline
end

function defaultUniformData(::Type{Cube}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

# TODO for now cube is static
# definitely needs change based on position, rotation etc ...
function computeUniformData(cube::Cube)
	return defaultUniformData(Cube)
end


function defaultCube()
	vertexData = cat([
	    [-1, -1, 1, 1],
	    [1, -1, 1, 1],
	    [1, 1, 1, 1],
	    [-1, 1, 1, 1],
	    [-1, 1, -1, 1],
	    [1, 1, -1, 1],
	    [1, -1, -1, 1],
	    [-1, -1, -1, 1],
	    [1, -1, -1, 1],
	    [1, 1, -1, 1],
	    [1, 1, 1, 1],
	    [1, -1, 1, 1],
	    [-1, -1, 1, 1],
	    [-1, 1, 1, 1],
	    [-1, 1, -1, 1],
	    [-1, -1, -1, 1],
	    [1, 1, -1, 1],
	    [-1, 1, -1, 1],
	    [-1, 1, 1, 1],
	    [1, 1, 1, 1],
	    [1, -1, 1, 1],
	    [-1, -1, 1, 1],
	    [-1, -1, -1, 1],
	    [1, -1, -1, 1],
	]..., dims=2) .|> Float32

	unitColor = cat([
		[0.6, 0.4, 0.5, 1],
		[0.5, 0.6, 0.3, 1],
		[0.4, 0.5, 0.6, 1],
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 8))

	indexData =   cat([
	        [0, 1, 2, 2, 3, 0], 
	        [4, 5, 6, 6, 7, 4],  
	        [8, 9, 10, 10, 11, 8], 
	        [12, 13, 14, 14, 15, 12], 
	        [16, 17, 18, 18, 19, 16], 
	        [20, 21, 22, 22, 23, 20], 
	    ]..., dims=2) .|> UInt32

	faceNormal = cat([
		[0, 0, 1, 0],
		[1, 0, 0, 0],
		[0, 0, -1, 0],
		[-1, 0, 0, 0],
		[0, 1, 0, 0],
		[0, -1, 0, 0]
	]..., dims=2) .|> Float32
	
	normalData = repeat(faceNormal, inner=(1, 4))

	cube = Cube(
		nothing, 		# gpuDevice
		vertexData, 
		colorData, 
		indexData, 
		normalData, 
		nothing, 		# TODO fill UVs later
		nothing, 		# uniformData
		nothing, 		# uniformBuffer
		nothing, 		# indexBuffer
		nothing,	 	# vertexBuffer
		nothing,		# bindGroup
		nothing			# renderPipeline
	)
	cube
end


Base.setproperty!(cube::Cube, f::Symbol, v) = begin
	setfield!(cube, f, v)
	setfield!(cube, :uniformData, f==:uniformData ? v : computeUniformData(cube))
	updateUniformBuffer(cube)
end


Base.getproperty(cube::Cube, f::Symbol) = begin
	if f != :uniformBuffer
		return getfield(cube, f)
	else
		return readUniformBuffer(cube)
	end
end


function getUniformData(cube::Cube)
	return cube.uniformData
end


function updateUniformBuffer(cube::Cube)
	data = SMatrix{4, 4}(cube.uniformData[:])
	@info :UniformBuffer data
	WGPUCore.writeBuffer(
		cube.gpuDevice[].queue, 
		getfield(cube, :uniformBuffer),
		data,
	)
end


function readUniformBuffer(cube::Cube)
	data = WGPUCore.readBuffer(
		cube.gpuDevice,
		getfield(cube, :uniformBuffer),
		0,
		getfield(cube, :uniformBuffer).size
	)
	datareinterpret = reinterpret(Mat4{Float32}, data)[1]
	@info "Received Buffer" datareinterpret
end


function getUniformBuffer(cube::Cube)
	getfield(cube, :uniformBuffer)
end

function getShaderCode(::Type{Cube}; islight=false, binding=0)
	name = Symbol(:cube, binding)
	shaderCode = quote
		struct CubeUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 $binding $name::@user CubeUniform
 	end
 	
	return shaderCode
end

# TODO check it its called multiple times
function getVertexBuffer(gpuDevice, cube::Cube)
	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat([cube.vertexData, cube.colorData, cube.normalData]...), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end

function getIndexBuffer(gpuDevice, cube::Cube)
	(indexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		cube.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end

# TODO remove kwargs offset
function getVertexBufferLayout(::Type{Cube}; offset = 0)
	WGPUCore.GPUVertexBufferLayout => [
		:arrayStride => 12*4,
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
			],
			:attribute => [
				:format => "Float32x4",
				:offset => 8*4,
				:shaderLocation => offset + 2
			]
		]
	]
end


function getBindingLayouts(::Type{Cube}; binding=0)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		]
	]
	return bindingLayouts
end


function getBindings(::Type{Cube}, uniformBuffer; binding=0)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
	]
end

function getRenderPipelineOptions(scene, cube::Cube)
	renderpipelineOptions = [
		WGPUCore.GPUVertexState => [
			:_module => scene.cshader.internal[],						# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",							# SET THIS (FIXED FOR NOW)
			:buffers => [
					getVertexBufferLayout(typeof(cube))
				]
		],
		WGPUCore.GPUPrimitiveState => [
			:topology => "TriangleList",
			:frontFace => "CCW",
			:cullMode => "Front",
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

function render(renderPass, renderPassOptions, cube::Cube)
	WGPUCore.setPipeline(renderPass, cube.renderPipeline)
	WGPUCore.setIndexBuffer(renderPass, cube.indexBuffer, "Uint32")
	WGPUCore.setVertexBuffer(renderPass, 0, cube.vertexBuffer)
	WGPUCore.setBindGroup(renderPass, 0, cube.bindGroup, UInt32[], 0, 99)
	WGPUCore.drawIndexed(renderPass, Int32(cube.indexBuffer.size/sizeof(UInt32)); instanceCount = 1, firstIndex=0, baseVertex= 0, firstInstance=0)
end


function toMesh(::Type{Cube})
	
end
