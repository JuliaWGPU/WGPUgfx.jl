using WGPU_jll
using WGPU

export defaultCircle, Circle

mutable struct Circle
	vertexData
	colorData
	indexData
end

function defaultUniformData(::Type{Circle}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

function getUniformData(circle::Circle)
	return defaultUniformData(Circle)
end

function getUniformBuffer(gpuDevice, circle::Circle)
	uniformData = defaultUniformData(Circle)
	(uniformBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"uniformBuffer", 
		uniformData, 
		["Uniform", "CopyDst"]
	)
	uniformBuffer
end

function generateCircle(nDivs, radius=1)
	rev = 2*pi
	rotz = RotZ(rev/nDivs)
	positions = []
	indices = []
	vec = [1, 0, 1]
	for idx in 0:nDivs
		push!(positions, [vec..., 1.0])
		push!(indices, [0, idx, idx+1])
		vec = rotz*vec
	end
	vertexData = cat(positions..., dims=2) .|> Float32
	indexData = cat(indices[1:nDivs]..., dims=2) .|> UInt32
	return (vertexData, indexData)
end

function defaultCircle(nDivs=100, radius=1, color=[0.4, 0.3, 0.5, 1.0])
	(vertexData, indexData) = generateCircle(nDivs, radius)

	unitColor = cat([
		color
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, size(vertexData, 2)))

	circle = Circle(vertexData, colorData, indexData)
	return circle
end


function getVertexBuffer(gpuDevice, circle::Circle)
	(vertexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat([circle.vertexData, circle.colorData]...), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end


function getIndexBuffer(gpuDevice, circle::Circle)
	(indexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		circle.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end


function getVertexBufferLayout(::Type{Circle}; offset = 0)
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


function getBindingLayouts(::Type{Circle}; binding=0)
	bindingLayouts = [
		WGPU.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end


function getBindings(::Type{Circle}, uniformBuffer; binding=0)
	bindings = [
		WGPU.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
	]
end


function getShaderCode(::Type{Circle}; binding=0)
	shaderSource = quote
		struct CircleUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 $binding rLocals::@user CircleUniform
 	end
 	
	return shaderSource
end

function toMesh(::Type{Circle})
	
end
