using WGPUNative
using WGPUCore

export defaultBBox, WGPUBBox

mutable struct WGPUBBox <: Renderable
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

function defaultBBox(object::Renderable; color=[0.6, 0.2, 0.5, 1.0])
	aabb = WGPUgfx.AABB(object)
	mId = Matrix{Float32}(I, (4, 4))
	coordinates = []
	minCoords = aabb[:, 1]
	maxCoords = aabb[:, 2]
	
	for j in 1:2
		srcCoords = aabb[:, j]
		dstCoords = aabb[:, j%2 + 1]
		for i in 1:4
			push!(coordinates, srcCoords .+ (dstCoords.*mId[:, i] .- mId[:, i].*srcCoords))
		end
	end
	
	vertexData = cat(coordinates..., dims=2) .|> Float32

	unitColor = cat([
		color,
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 8))

	indexData =   cat([
			[0, 6],
			[6, 1],
			[1, 3],
			[3, 0],
			[5, 7],
			[7, 4],
			[4, 2],
			[2, 5],
			[2, 3],
			[4, 1],
			[5, 0],
			[7, 6],
	    ]..., dims=2) .|> UInt32
	
	box = WGPUBBox(
		nothing, 		# gpuDevice
		"LineList",
		vertexData, 
		colorData, 
		indexData, 
		nothing, 		# uniformData
		nothing, 		# uniformBuffer
		nothing, 		# indexBuffer
		nothing,	 	# vertexBuffer
		Dict(),		# pipelineLayout
		Dict(),		# renderPipeline
		Dict(),		# cshader
	)
	box
end

