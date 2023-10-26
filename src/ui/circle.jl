# This should shader based but for now since we have everything inplace for TriangleList Topology
# we can just exploit it and make specialized changes later.

export defaultUICircle, WGPUUICircle

mutable struct WGPUUICircle <: RenderableUI
	radius
	nSectors
	gpuDevice
	topology
	vertexData
	colorData
	indexData
	uniformData
	uniformBuffer
	indexBuffer
	vertexBuffer
	pipelineLayouts
	renderPipelines
	cshaders
end

function generateUICircle(nSectors; radius=1)
	rev = 2*pi
	rotz = RotZ(rev/nSectors)
	positions = [[0.0, 0.0, 1.0, 1.0],]
	indices = []
	vec = [radius, 0, 1]
	for idx in 1:nSectors
		push!(positions, [vec..., 1.0])
		push!(indices, [0, idx, idx+1])
		vec = rotz*vec
	end
	vertexData = cat(positions..., dims=2) .|> Float32
	indexData = cat(indices[1:nSectors]..., dims=2) .|> UInt32
	indexData[end] = 1
	return (vertexData, indexData)
end

function defaultUICircle(;nSectors=10, radius=1, color=[0.4, 0.3, 0.5, 1.0])
	(vData, iData) = generateUICircle(nSectors; radius=radius)
	vertexData = reshape(vData[:, (1 .+ iData[:])], (4, length(iData)))
	indexData = 0:(size(vertexData, 2) -1) |> collect .|> Int32
	unitColor = cat([
		color
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, size(vertexData, 2)))

	circle = WGPUUICircle(
		radius,
		nSectors,
		nothing,
		"TriangleList",
		vertexData, 
		colorData, 
		indexData,
		nothing, #uniformData,
		nothing, #uniformBuffer,
		nothing, #indexBuffer,
		nothing, #vertexBuffer,
		Dict(), #pipelineLayout,
		Dict(), #renderPipeline
		Dict(), #cshader
	)
	return circle
end
