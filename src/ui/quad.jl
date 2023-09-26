export defaultQuad, Quad

mutable struct Quad <: RenderableUI
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

function defaultQuad(; color=[0.2, 0.4, 0.8, 0.7])
	vertexData = cat([
		[0, 0, 0, 1],
		[1, 0, 0, 1],
		[1, 1, 0, 1],
		[1, 1, 0, 1],
		[0, 1, 0, 1],
		[0, 0, 0, 1],
	]..., dims=2) .|> Float32

	unitColor = cat([
		color,
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 6))

	indexData = cat([
		[0, 1, 2, 3, 4, 5],
	]..., dims=2) .|> UInt32

	box = Quad(
		nothing, 		# gpuDevice
		"TriangleList",
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
