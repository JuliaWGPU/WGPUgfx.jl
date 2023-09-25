mutable struct Quad <: Renderable
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

function defaultQuad(object::Renderable; color=[0.6, 0.4, 0.5, 1.0])
    coordinates = [
        [0, 0],
        [1, 0],
        [0, 1],
        [1, 1],
    ]

	vertexData = cat(coordinates..., dims=2) .|> Float32

	unitColor = cat([
		color,
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 4))

	indexData =   cat([[0, 1, 2], [0, 2, 3]]..., dims=2) .|> UInt32
	
	box = Quad(
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

function defaultUniformData(::Quad)
	uniformData = ones(Float32, (4,)) |> diagm
	return uniformData
end

function computeUniformData(quad::Quad)
	return defaultUniformData(quad)
end

function prepareObject(gpuDevice, quad::Quad)
	
end

