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

function defaultQuad(; color=[0.2, 0.4, 0.8, 0.5], scale::Union{Vector{Float32}, Float32} = 1.0f0, image="", imgData=nothing)

	if typeof(scale) == Float32
		scale = [scale.*ones(Float32, 3)..., 1.0f0] |> diagm
	else
		scale = scale |> diagm
	end

	swapMat = [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1] .|> Float32;
	# swapMat = [1 0 0 0; 0 0 -1 0; 0 1 0 0; 0 0 0 1] .|> Float32;
		

	vertexData = cat([
		[1, -1, 0, 1],
		[1, 1, 0, 1],
		[-1, -1, 0, 1],
		[-1, -1, 0, 1],
		[1, 1, 0, 1],
		[-1, 1, 0, 1],
	]..., dims=2) .|> Float32

	vertexData = scale*swapMat*vertexData

	unitColor = cat([
		color,
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 6))

	indexData = cat([
		[0, 1, 2, 3, 4, 5],
	]..., dims=2) .|> UInt32

	uvData = cat([
		[1, 0],
		[1, 1],
		[0, 0],
		[0, 0],
		[1, 1],
		[0, 1]
	]..., dims=2) .|> Float32
	
	texture = nothing
	textureData = nothing
	textureView = nothing

	if imgData !== nothing 
		textureData = imgData
	elseif image != ""
		textureData = begin
			img = load(image)
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
