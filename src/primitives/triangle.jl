using WGPU_jll

using WGPU

export Triangle, defaultTriangle

struct Triangle
	vertexData
	indexData
	colorData
end

function defaultUniformData(::Type{Triangle})
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

function getUniformData(tri::Triangle)
	return defaultUniformData(Triangle)
end

function getShaderSource(::Triangle)
	shaderSource = quote
		struct TriangleUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 0 rLocals::@user TriangleUniform
 	end
 	
	return shaderSource

end

function getUniformBuffer(gpuDevice, tri::Triangle)
	uniformData = defaultUniformData(Triangle)
	(uniformBuffer, _) = WGPU.createBufferWithData(
		gpuDevice,
		"uniformBuffer",
		uniformData,
		["Uniform", "CopyDst"]
	)
	uniformBuffer
end

function defaultTriangle()
	vertexData =  cat([
	    [-1.0, -1.0, 1, 1.5],
	    [1.0, -1.0, 1, 1.5],
	    [0.0, 1, 1, 1.5],
	]..., dims=2) .|> Float32

	indexData = cat([[0, 1, 2]]..., dims=2)
	colorData = repeat(cat([[1, 0, 0, 1]]..., dims=2), 1, 3)

	triangle = Triangle(vertexData, indexData, colorData)
	triangle
end

function getVertexBuffer(gpuDevice, tri::Triangle)
	(vertexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice,
		"vertexBuffer",
		tri.vertexData,
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end

function getIndexBuffer(gpuDevice, tri::Triangle)
	(indexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		tri.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end

function getVertexBufferLayout(tri::Type{Triangle})
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

function getBindingLayouts(::Type{Triangle})
	bindingLayouts = [
		WGPU.WGPUBufferEntry => [
			:binding => 0,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end

function getBindings(::Type{Triangle}, uniformBuffer)
	bindings = [
		WGPU.GPUBuffer => [
			:binding => 0,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
	]
end

function getShaderCode(::Type{Triangle})
	shaderSource = quote
		struct TriUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 0 rLocals::@user TriUniform
 	end
 	
	return shaderSource
end

function toMesh(::Type{Triangle})
	
end
