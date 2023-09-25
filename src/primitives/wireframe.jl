using WGPUNative
using WGPUCore

export defaultWireFrame, WGPUWireFrame

mutable struct WGPUWireFrame <: Renderable
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

function defaultWireFrame(object::Renderable; color=[1.0, 1.0, 1.0, 1.0])
	vertexData = object.vertexData
	colorData = object.colorData
	indexData = object.indexData
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
		Dict(),			# pipelineLayout
		Dict(),			# renderPipeline
		Dict(),			# cshader
	)
	box
end

