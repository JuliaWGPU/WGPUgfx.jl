
using WGPU_jll

using WGPU

include("macros.jl")

using .MacroMod
using .MacroMod: wgslCode

struct Cube
	vertexData
	colorData
	indexData
end

function defaultUniformData(::Type{Cube}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

function getUniformData(cube::Cube)
	return defaultUniformData(Cube)
end

function getUniformBuffer(gpuDevice, cube::Cube)
	uniformData = defaultUniformData(Cube)
	(uniformBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"uniformBuffer", 
		uniformData, 
		["Uniform", "CopyDst"]
	)
	uniformBuffer
end

function defaultCube()
	vertexData =  cat([
	    [-1, -1, 1, 1.5],
	    [1, -1, 1, 1.5],
	    [1, 1, 1, 1.5],
	    [-1, 1, 1, 1.5],
	    [-1, 1, -1, 1.5],
	    [1, 1, -1, 1.5],
	    [1, -1, -1, 1.5],
	    [-1, -1, -1, 1.5],
	    [1, -1, -1, 1.5],
	    [1, 1, -1, 1.5],
	    [1, 1, 1, 1.5],
	    [1, -1, 1, 1.5],
	    [-1, -1, 1, 1.5],
	    [-1, 1, 1, 1.5],
	    [-1, 1, -1, 1.5],
	    [-1, -1, -1, 1.5],
	    [1, 1, -1, 1.5],
	    [-1, 1, -1, 1.5],
	    [-1, 1, 1, 1.5],
	    [1, 1, 1, 1.5],
	    [1, -1, 1, 1.5],
	    [-1, -1, 1, 1.5],
	    [-1, -1, -1, 1.5],
	    [1, -1, -1, 1.5],
	]..., dims=2) .|> Float32

	colorData = cat([
		[1, 0, 0, 1],
		[1, 0, 0, 1],
		[1, 0, 0, 1],
		[1, 0, 0, 1],
		[1, 0, 0, 1],
		[1, 0, 0, 1],
		[1, 0, 0, 1],
		[1, 0, 0, 1],
		[0, 1, 0, 1],
		[0, 1, 0, 1],
		[0, 1, 0, 1],
		[0, 1, 0, 1],
		[0, 1, 0, 1],
		[0, 1, 0, 1],
		[0, 1, 0, 1],
		[0, 1, 0, 1],
		[0, 0, 1, 1],
		[0, 0, 1, 1],
		[0, 0, 1, 1],
		[0, 0, 1, 1],
		[0, 0, 1, 1],
		[0, 0, 1, 1],
		[0, 0, 1, 1],
		[0, 0, 1, 1],
	]..., dims=2) .|> Float32

	indexData =   cat([
	        [0, 1, 2, 2, 3, 0], 
	        [4, 5, 6, 6, 7, 4],  
	        [8, 9, 10, 10, 11, 8], 
	        [12, 13, 14, 14, 15, 12], 
	        [16, 17, 18, 18, 19, 16], 
	        [20, 21, 22, 22, 23, 20], 
	    ]..., dims=2) .|> UInt32

	cube = Cube(vertexData, colorData, indexData)
	cube
end

function getVertexBuffer(gpuDevice, cube::Cube)
	(vertexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat([cube.vertexData, cube.colorData]...), 
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

function getVertexBufferLayout(cube::Cube)
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

struct ShaderObj
	src
	internal
	desc
end

function defaultShader(gpuDevice, ::Type{Cube})
	shaderSource = quote
		struct Locals
			transform::Mat4{Float32}
		end

		@var Uniform 0 0 rLocals::@user Locals
		
		struct VertexInput
			@location 0 pos::Vec4{Float32}
			@location 1 vColor::Vec4{Float32}
		end
		
		struct VertexOutput
			@location 0 vColor::Vec4{Float32}
			@builtin position pos::Vec4{Float32}
		end
		
		@vertex function vs_main(in::@user VertexInput)::@user VertexOutput
			@var out::@user VertexOutput
			out.pos = rLocals.transform*in.pos
			out.vColor = in.vColor
			return out
		end
		
		@fragment function fs_main(in::@user VertexOutput)::@location 0 Vec4{Float32}
			return in.vColor
		end
		
	end |> wgslCode |> Vector{UInt8}

	# TODO this needs to be changed
	# loadWGSL is awkward name. Shoulde be called descriptor
	descriptor = WGPU.loadWGSL(shaderSource) |> first; 
	
	ShaderObj(
		shaderSource, 
		WGPU.createShaderModule(
			gpuDevice, 
			"shadercode", 
			descriptor, 
			nothing, 
			nothing
		) |> Ref,
		descriptor
	)
end

function toMesh(::Type{Cube})
	
end
