using WGPUNative
using WGPUCore

export defaultCube, Cube

mutable struct Cube <: Renderable
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
	pipelineLayout
	renderPipeline
	cshader
end

function defaultCube()
	vertexData = cat([
	    [-1, -1, 1, 1],
	    [1, -1, 1, 1],
	    [1, 1, 1, 1],
	    [-1, 1, 1, 1],
	    [-1, 1, -1, 1],
	    [1, 1, -1, 1],
	    [1, -1, -1, 1],
	    [-1, -1, -1, 1],
	    [1, -1, -1, 1],
	    [1, 1, -1, 1],
	    [1, 1, 1, 1],
	    [1, -1, 1, 1],
	    [-1, -1, 1, 1],
	    [-1, 1, 1, 1],
	    [-1, 1, -1, 1],
	    [-1, -1, -1, 1],
	    [1, 1, -1, 1],
	    [-1, 1, -1, 1],
	    [-1, 1, 1, 1],
	    [1, 1, 1, 1],
	    [1, -1, 1, 1],
	    [-1, -1, 1, 1],
	    [-1, -1, -1, 1],
	    [1, -1, -1, 1],
	]..., dims=2) .|> Float32

	unitColor = cat([
		[0.6, 0.4, 0.5, 1],
		[0.5, 0.6, 0.3, 1],
		[0.4, 0.5, 0.6, 1],
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 8))

	indexData =   cat([
	        [0, 1, 2, 2, 3, 0], 
	        [4, 5, 6, 6, 7, 4],  
	        [8, 9, 10, 10, 11, 8], 
	        [12, 13, 14, 14, 15, 12], 
	        [16, 17, 18, 18, 19, 16], 
	        [20, 21, 22, 22, 23, 20], 
	    ]..., dims=2) .|> UInt32

	faceNormal = cat([
		[0, 0, 1, 0],
		[0, 0, -1, 0],
		[1, 0, 0, 0],
		[-1, 0, 0, 0],
		[0, 1, 0, 0],
		[0, -1, 0, 0]
	]..., dims=2) .|> Float32
	
	normalData = repeat(faceNormal, inner=(1, 4))

	cube = Cube(
		nothing, 		# gpuDevice
		"TriangleList",
		vertexData, 
		colorData, 
		indexData, 
		normalData, 
		nothing, 		# TODO fill later
		nothing, 		# uniformData
		nothing, 		# uniformBuffer
		nothing, 		# indexBuffer
		nothing,	 	# vertexBuffer
		nothing,	 	# textureData
		nothing,	 	# texture
		nothing,	 	# textureView
		nothing,	 	# sampler
		nothing,		# pipelineLayout
		nothing,		# renderPipeline
		nothing,		# cshader
	)
	cube
end

