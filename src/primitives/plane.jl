using WGPUNative
using WGPUCore

export defaultPlane, Plane

mutable struct Plane <: Renderable
	width
	height
	wSegments
	hSegments
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

function defaultPlane(width=1, height=1, wSegments=2, hSegments=2, color=[0.6, 0.2, 0.5, 1.0])

	vertexData = cat([
		[-1, -1, 0, 1],
		[1, -1, 0, 1],
		[1, 1, 0, 1],
		[1, 1, 0, 1],
		[-1, 1, 0, 1],
		[-1, -1, 0, 1],
	]..., dims=2) .|> Float32

	unitColor = cat([
		[0.6, 0.4, 0.5, 1],
		[0.5, 0.6, 0.3, 1],
		[0.4, 0.5, 0.6, 1],
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 2))

	indexData = cat([
		[0, 1, 2, 3, 4, 5],
	]..., dims=2) .|> UInt32

	faceNormal = cat([
		[0, 0, 1, 0],
		[0, 0, 1, 0],
	]..., dims=2) .|> Float32

	normalData = repeat(faceNormal, inner=(1, 3))

	
	Plane(
		width, 
		height, 
		wSegments, 
		hSegments, 
		nothing, #gpuDevice,
		"TriangleList", 
		vertexData,
		colorData,
		indexData,
		normalData,
		nothing, #uvData,
		nothing, #uniformData,
		nothing, #uniformBuffer,
		nothing, #indexBuffer,
		nothing, #vertexBuffer,
		nothing, #textureData,
		nothing, #texture,
		nothing, #textureView,
		nothing, #sampler,
		nothing, #pipelineLayout,
		nothing, #renderPipeline
		nothing, #cshader
	)
end
