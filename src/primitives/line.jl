export defaultLine, WGPULine

mutable struct WGPULine <: Renderable
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


function defaultLine(; startPoint=[0, 0, 0], endPoint=[1, 1, 0]) #, len=4.0)
	vertexData = cat([
		[startPoint..., 			1],
		[endPoint..., 			1],
	]..., dims=2) .|> Float32

	unitColor = cat([
		[0.2, 0.2, 0.2, 0.4],
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 2))

	indexData = cat([
		[0, 1],
	]..., dims=2) .|> UInt32

	WGPULine(
		nothing,
		"LineList",
		vertexData,
		colorData,
		indexData,
		nothing,
		nothing,
		nothing,
		nothing,
		Dict(),
		Dict(),
		Dict(),
	)
end

