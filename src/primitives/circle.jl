using WGPUNative
using WGPUCore

export defaultCircle, WGPUCircle

mutable struct WGPUCircle <: Renderable
	radius
	nSectors
	gpuDevice
	topology
	vertexData
	colorData
	indexData
	normalData
	uvData
	uniformData
	uniformBuffer
	indexBuffer
	vertexBuffer
	textureData
	texture
	textureView
	sampler
	pipelineLayouts
	renderPipelines
	cshaders
end

function generateCircle(nDivs, radius=1)
	rev = 2*pi
	rotz = RotZ(rev/nDivs)
	positions = []
	indices = []
	vec = [1, 0, 1]
	for idx in 1:nDivs
		push!(positions, [vec..., 1.0])
		push!(indices, [0, idx, idx+1])
		vec = rotz*vec
	end
	vertexData = cat(positions..., dims=2) .|> Float32
	indexData = cat(indices[1:nDivs]..., dims=2) .|> UInt32
	return (vertexData, indexData)
end

function defaultCircle(nSectors=100, radius=1, color=[0.4, 0.3, 0.5, 1.0])
	(vertexData, indexData) = generateCircle(nSectors, radius)

	unitColor = cat([
		color
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, size(vertexData, 2)))

	indexData = cat([
		1:size(vertexData, 1) |> collect
	]..., dims=2) .|> UInt32

	faceNormal = cat([
		repeat(
			[0, 0, 1, 0],
			size(vertexData, 1)
		)
	]..., dims=2) .|> Float32

	# 	normalData = repeat(faceNormal, inner=(1, 3))

	circle = WGPUCircle(
		radius,
		nSectors,
		nothing,
		"TriangleList",
		vertexData, 
		colorData, 
		indexData,
		nothing, #normalData
		nothing, #uvData,
		nothing, #uniformData,
		nothing, #uniformBuffer,
		nothing, #indexBuffer,
		nothing, #vertexBuffer,
		nothing, #textureData,
		nothing, #texture,
		nothing, #textureView,
		nothing, #sampler,
		Dict(), #pipelineLayout,
		Dict(), #renderPipeline
		Dict(), #cshader
	)
	return circle
end
