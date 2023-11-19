export defaultQuad, Quad

mutable struct Quad <: RenderableUI
	gpuDevice
    topology
    vertexData
    colorData
    indexData
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

function defaultQuad(; color=[0.2, 0.4, 0.8, 1.0], image="", imgData=nothing)
	vertexData = cat([
		[1, -1, 0, 1],
		[1, 1, 0, 1],
		[-1, -1, 0, 1],
		[-1, -1, 0, 1],
		[1, 1, 0, 1],
		[-1, 1, 0, 1],
	]..., dims=2) .|> Float32

	unitColor = cat([
		color,
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 6))

	indexData = cat([
		[0, 1, 2, 3, 4, 5],
	]..., dims=2) .|> UInt32

	uvData = nothing
	texture = nothing
	textureData = nothing
	textureView = nothing

	if imgData !== nothing 
		uvData = cat([
			[1, 0],
			[1, 1],
			[0, 0],
			[0, 0],
			[1, 1],
			[0, 1]
		]..., dims=2) .|> Float32
		textureData = imgData[]
	elseif image != ""
		uvData = cat([
			[1, 0],
			[1, 1],
			[0, 0],
			[0, 0],
			[1, 1],
			[0, 1]
		]..., dims=2) .|> Float32
		textureData = begin
			img = load(image)
			img = imresize(img, (256, 256)) # TODO hardcoded size
			img = imrotate(RGBA.(img), pi/2)
			imgview = channelview(img) |> collect
		end
	end

	# Skipping normals for now
	
	box = Quad(
		nothing, 		# gpuDevice
		"TriangleList",
		vertexData, 
		colorData, 
		indexData, 
		uvData,
		nothing, 		# uniformData
		nothing, 		# uniformBuffer
		nothing, 		# indexBuffer
		nothing,	 	# vertexBuffer
		textureData,
		nothing,	# texture
		nothing,	# textureView
		nothing,	# sampler
		Dict(),		# pipelineLayout
		Dict(),		# renderPipeline
		Dict(),		# cshader
	)
	box
end
