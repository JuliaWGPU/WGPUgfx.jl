using WGPU_jll

using WGPU

export defaultPlane, Plane

struct Plane
	width
	height
	wSegments
	hSegments
	vertexData
	indexData
	colorData
end

function defaultUniformData(::Type{Plane}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

function getUniformData(plane::Plane)
	return defaultUniformData(Plane)
end

function getUniformBuffer(gpuDevice, plane::Plane)
	uniformData = defaultUniformData(Plane)
	(uniformBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"uniformBuffer", 
		uniformData, 
		["Uniform", "CopyDst"]
	)
	uniformBuffer
end

function generatePlane(width, height, wSegments, hSegments)
	w, h = width, height
	nx, ny = wSegments, hSegments
	wsegments = 1:wSegments |> collect
	hsegments = 1:hSegments |> collect
	x = (wsegments .- sum(wsegments)/length(wsegments))./length(wsegments)
	x = (x./maximum(x)).*width
	y = (hsegments .- sum(hsegments)/length(hsegments))./length(hsegments)
	y = (y./maximum(y)).*height
	xx = repeat(x , 1, size(y) |> first)[:] 
	yy = repeat(-y |> adjoint, size(x) |> first)[:]
	positions = cat(xx, yy, ones(size(xx)), 1.5.*ones(size(xx)), dims=2)
	dim = (w, h)
	indices = (1:(nx*ny)) |> collect |> (x) -> reshape(x, (nx, ny))
	index = zeros(wSegments, hSegments, 2, 3)
	index[:, :, 1, 1] = indices[1:hSegments, 1:wSegments]
	index[:, :, 1, 2] = index[:, :, 1, 1] .+ 1
	index[:, :, 1, 3] = index[:, :, 1, 1] .+ nx
	index[:, :, 2, 1] = index[:, :, 1, 1] .+ nx .+ 1
	index[:, :, 2, 2] = index[:, :, 2, 1] .- 1
	index[:, :, 2, 3] = index[:, :, 2, 1] .- nx
	return (positions .|> Float32, index)
end

function defaultPlane()
	width = 1
	height = 1
	wSegments = 10
	hSegments = 10
	(vertexData, indices) = generatePlane(width, height, wSegments, hSegments)
	vertexData = vertexData |> adjoint |> collect
	indexData = permutedims(indices, (1, 2, 4, 3))
	indexData = reshape(indexData, reduce(*, size(indices)[1:2]), reduce(*, size(indices)[3:4])) .|> UInt32
	indexData = indexData |> adjoint |> collect
	colorData = repeat([0.3, 0.2, 0.7, 1.0] |> adjoint, inner=(size(vertexData)[2] |> Int, 1)) .|> Float32
	colorData = colorData |> adjoint |> collect
	Plane(width, height, wSegments, hSegments, vertexData, indexData, colorData)
end

function getVertexBuffer(gpuDevice, plane::Plane)
	(vertexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat([plane.vertexData, plane.colorData]...), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end

function getIndexBuffer(gpuDevice, plane::Plane)
	(indexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		plane.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end

function getVertexBufferLayout(plane::Type{Plane})
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

function getBindingLayouts(::Type{Plane})
	bindingLayouts = [
		WGPU.WGPUBufferEntry => [
			:binding => 0,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end

function getBindings(::Type{Plane}, uniformBuffer)
	bindings = [
		WGPU.GPUBuffer => [
			:binding => 0,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
	]
end

function getShaderCode(::Type{Plane})
	shaderSource = quote
		struct PlaneUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 0 rLocals::@user PlaneUniform
 	end
 	
	return shaderSource
end

function toMesh(::Type{Plane})
	
end


