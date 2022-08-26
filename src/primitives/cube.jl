
using WGPU_jll

using WGPU

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
end

function prepareObject(gpuDevice, cube::Cube)
	uniformData = computeUniformData(cube)
	(uniformBuffer, _) = WGPU.createBufferWithData(
		gpuDevice,
		"Cube Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(cube, :uniformData, uniformData)
	setfield!(cube, :uniformBuffer, uniformBuffer)
	setfield!(cube, :gpuDevice, gpuDevice)
	return cube
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

	cube = Cube(nothing, vertexData, colorData, indexData, normalData, nothing, nothing, nothing)
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
	WGPU.writeBuffer(
		cube.gpuDevice[].queue, 
		getfield(cube, :uniformBuffer),
		data,
	)
end


function readUniformBuffer(cube::Cube)
	data = WGPU.readBuffer(
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


function getShaderCode(::Type{Cube})
	shaderSource = quote
		struct CubeUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 0 cube::@user CubeUniform
 	end
 	
	return shaderSource
end


# TODO check it its called multiple times
function getVertexBuffer(gpuDevice, cube::Cube)
	(vertexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat([cube.vertexData, cube.colorData, cube.normalData]...), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end


function getIndexBuffer(gpuDevice, cube::Cube)
	(indexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		cube.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end


function getVertexBufferLayout(::Type{Cube})
	WGPU.GPUVertexBufferLayout => [
		:arrayStride => 12*4,
		:stepMode => "Vertex",
		:attributes => [
			:attribute => [
				:format => "Float32x4",
				:offset => 0,
				:shaderLocation => 0
			],
			:attribute => [
				:format => "Float32x4",
				:offset => 4*4,
				:shaderLocation => 1
			],
			:attribute => [
				:format => "Float32x4",
				:offset => 8*4,
				:shaderLocation => 2
			]
		]
	]
end


function getBindingLayouts(::Type{Cube})
	bindingLayouts = [
		WGPU.WGPUBufferEntry => [
			:binding => 0,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end


function getBindings(::Type{Cube}, uniformBuffer)
	bindings = [
		WGPU.GPUBuffer => [
			:binding => 0,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
	]
end


function toMesh(::Type{Cube})
	
end
