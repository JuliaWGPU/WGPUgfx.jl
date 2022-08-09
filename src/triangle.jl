
using LinearAlgebra

export getVertexBufferLayout, getUniformBuffer, 
		getVertexBuffer, getTextureView, 
		getIndexBuffer,	writeTexture, 
		defaultUniformData, getUniformData, defaultTriangle,
		getShaderSource

flatten(x) = reshape(x, (:,))

using WGPU_jll

using WGPU

struct Triangle
	vertexData
	indexData
	textureData
end

function defaultUniformData(::Type{Cube}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

function getUniformData(tri::Triangle)
	return defaultUniformData(Triangle)
end

function getShaderSource(::Triangle)
	shaderSource = quote

		struct VertexInput
			@location 0 pos::Vec2{Float32}
			@location 1 color pos::Vec4{Float32}
		end

		struct VertexOuput
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
	    [0.0, -1.0, 1, 0, 0, 1],
	    [1.0, 1.0, 0, 1, 0, 1],
	    [-1.0, 1, 0, 0, 1, 1],
	]..., dims=2) .|> Float32

	triangle = Triangle(vertexData, nothing, nothing)
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

function getVertexBufferLayout(tri::Triangle)
	WGPU.GPUVertexBufferLayout => [
		:arrayStride => 6*4,
		:stepMode => "Vertex",
		:attributes => [
			:attribute => [
				:format => "Float32x2",
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

function toMesh(::Type{Cube})
	
end
