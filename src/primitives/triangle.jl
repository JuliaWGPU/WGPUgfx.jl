using WGPU_jll

using WGPU

export Triangle3D, defaultTriangle3D

mutable struct Triangle3D
	vertexData
	indexData
	colorData
end

function defaultUniformData(::Type{Triangle3D})
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

function getUniformData(tri::Triangle3D)
	return defaultUniformData(Triangle3D)
end

function getShaderSource(::Triangle3D)
	shaderSource = quote
		struct Triangle3DUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 0 rLocals::@user Triangle3DUniform
 	end
 	
	return shaderSource

end

function getUniformBuffer(gpuDevice, tri::Triangle3D)
	uniformData = defaultUniformData(Triangle3D)
	(uniformBuffer, _) = WGPU.createBufferWithData(
		gpuDevice,
		"uniformBuffer",
		uniformData,
		["Uniform", "CopyDst"]
	)
	uniformBuffer
end

function defaultTriangle3D()
	vertexData =  cat([
	    [-1.0, -1.0, 1, 1.5],
	    [1.0, -1.0, 1, 1.5],
	    [0.0, 1, 1, 1.5],
	]..., dims=2) .|> Float32

	indexData = cat([[0, 1, 2]]..., dims=2) .|> UInt32
	colorData = repeat(cat([[1, 0, 0, 1]]..., dims=2), 1, 3) .|> Float32
	triangle = Triangle3D(vertexData, indexData, colorData)
	triangle
end

function getVertexBuffer(gpuDevice, tri::Triangle3D)
	(vertexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice,
		"vertexBuffer",
		tri.vertexData,
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end

function getIndexBuffer(gpuDevice, tri::Triangle3D)
	(indexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		tri.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end

function getVertexBufferLayout(tri::Type{Triangle3D})
	WGPU.GPUVertexBufferLayout => [
		:arrayStride => 8*4,
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
			]
		]
	]
end

function getBindingLayouts(::Type{Triangle3D})
	bindingLayouts = [
		WGPU.WGPUBufferEntry => [
			:binding => 0,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end

function getBindings(::Type{Triangle3D}, uniformBuffer)
	bindings = [
		WGPU.GPUBuffer => [
			:binding => 0,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
	]
end

function getShaderCode(::Type{Triangle3D})
	shaderSource = quote
		struct TriUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 0 rLocals::@user TriUniform
 	end
 	
	return shaderSource
end

function toMesh(::Type{Triangle3D})
	
end
