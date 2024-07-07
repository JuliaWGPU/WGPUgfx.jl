using WGPUNative
using WGPUCore

export Triangle3D, defaultTriangle3D

mutable struct Triangle3D <: Renderable
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

function defaultTriangle3D()
	vertexData =  cat([
   	    [1.0, -1.0, 0.0, 1],	    
	    [-1.0, -1.0, 0.0, 1],
   	    [0.0, 1.0, 0.0, 1],
	]..., dims=2) .|> Float32

	indexData = cat([[0, 1, 2]]..., dims=2) .|> UInt32

	faceNormal = cat([
		[0, 0, 1, 0],
	]..., dims=2) .|> Float32

	normalData = repeat(faceNormal, inner=(1, 3))
	
	# colorData = repeat(cat([[0.5, 0.3, 0.3, 1]]..., dims=2), 1, 3) .|> Float32

	colorData = [
		1.0f0 0.0f0 0.0f0 1.0f0; 
		0.0f0 1.0f0 0.0f0 1.0f0; 
		0.0f0 0.0f0 1.0f0 1.0f0; 
	] |> adjoint
	
	triangle = Triangle3D(
		nothing,
		"TriangleList",
		vertexData, 
		colorData, 
		indexData, 
		normalData, 
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		Dict(),
		Dict(),
		Dict(),
	)
	triangle
end
