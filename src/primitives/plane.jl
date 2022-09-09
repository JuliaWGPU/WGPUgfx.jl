using WGPU_jll
using WGPU

export defaultPlane, Plane


mutable struct Plane
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
	nx, ny = wSegments + 1, hSegments + 1
	wsegments = 1:wSegments+1 |> collect
	hsegments = 1:hSegments+1 |> collect
	x = (wsegments .- sum(wsegments)/length(wsegments))./length(wsegments)
	x = (x./maximum(x)).*width
	y = (hsegments .- sum(hsegments)/length(hsegments))./length(hsegments)
	y = (y./maximum(y)).*height
	xx = repeat(x , 1, size(y) |> first)[:]
	yy = repeat(-y |> adjoint, size(x) |> first)[:]
	positions = cat(xx, yy, ones(size(xx)), ones(size(xx)), dims=2) .|> Float32
	positions = positions |> adjoint |> collect
	dim = (w, h)
	indices = (0:(nx*ny)-1)|> (x) -> reshape(x, (nx, ny)) |> adjoint  |> collect 
	index = zeros(nx - 1, ny - 1, 3, 2)
	index[:, :, 1, 1] = indices[1:wSegments, 1:hSegments]
	index[:, :, 2, 1] = index[:, :, 1, 1] .+ wSegments .+ 1
	index[:, :, 3, 1] = index[:, :, 2, 1] .+ 1
	index[:, :, 1, 2] = index[:, :, 1, 1]
	index[:, :, 2, 2] = index[:, :, 3, 1]
	index[:, :, 3, 2] = index[:, :, 1, 1] .+ 1
	return (positions, index)
end


function defaultPlane(width=1, height=1, wSegments=2, hSegments=2, color=[0.6, 0.2, 0.5, 1.0])
	(positions, indices) = generatePlane(width, height, wSegments, hSegments)
	indexData = reshape(indices, reduce(*, size(indices)[1:2]), reduce(*, size(indices)[3:4])) .|> UInt32
	indexData = indexData |> adjoint |> collect
	unitcolor = cat(color, dims=2)
	colorData = repeat(unitcolor, inner=(1, size(unitcolor, 2)), outer=(1, reduce(*, size(indices)))) .|> Float32
	vertexData = hcat([positions[:, idx + 1] for idx in indexData[:]]...)
	indexData = collect(0:reduce(*, size(indices)) - 1) .|> UInt32
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


function getVertexBufferLayout(plane::Type{Plane}; offset=0)
	WGPU.GPUVertexBufferLayout => [
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


function getBindingLayouts(::Type{Plane}; binding=0)
	bindingLayouts = [
		WGPU.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end


function getBindings(::Type{Plane}, uniformBuffer; binding=0)
	bindings = [
		WGPU.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
	]
end


function getShaderCode(::Type{Plane}; islight=false, isVision=false, binding=0)
	shaderSource = quote
		struct PlaneUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 $binding rLocals::@user PlaneUniform
 	end
 	
	return shaderSource
end


function toMesh(::Type{Plane})
	
end


