using WGPUNative
using WGPUCore

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
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"uniformBuffer",
		uniformData,
		["Uniform", "CopyDst"]
	)
	uniformBuffer
end

function defaultTriangle3D()
	vertexData =  cat([
	    [-1.0, -1.0, 1.0, 1],
	    [1.0, -1.0, 1.0, 1],
	    [0.0, 1.0, 1.0, 1],
	]..., dims=2) .|> Float32

	indexData = cat([[0, 1, 2]]..., dims=2) .|> UInt32
	colorData = repeat(cat([[0.5, 0.3, 0.3, 1]]..., dims=2), 1, 3) .|> Float32
	triangle = Triangle3D(vertexData, indexData, colorData)
	triangle
end

function getVertexBuffer(gpuDevice, tri::Triangle3D)
	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"vertexBuffer",
		vcat(tri.vertexData, tri.colorData),
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end

function getIndexBuffer(gpuDevice, tri::Triangle3D)
	(indexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		tri.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end

function getVertexBufferLayout(tri::Type{Triangle3D}; offset=0)
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

function getBindingLayouts(::Type{Triangle3D}; binding=0)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end

function getBindings(::Type{Triangle3D}, uniformBuffer; binding=0)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
	]
end

function getShaderCode(::Type{Triangle3D}; binding=0)
	shaderSource = quote
		struct TriUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 $binding triuniform::@user TriUniform
 	end
 	
	return shaderSource
end

function toMesh(::Type{Triangle3D})
	
end
