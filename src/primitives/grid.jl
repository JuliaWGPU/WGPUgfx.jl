export defaultGrid, MainGrid

mutable struct MainGrid <: Renderable
	gpuDevice
	topology
	vertexData
	colorData
	indexData
	uniformData
	uniformBuffer
	indexBuffer
	vertexBuffer
	pipelineLayout
	renderPipeline
end

function defaultGrid(; origin=[0, 0, 0], len=4.0, segments = 10)
	segLen = len/segments
	vertexData = ((len/2.0) |> Float32) .- cat(
		cat(
			[[
				[origin[1] + i*segLen,	origin[2] + len/2.0, 	origin[3] 			, 			1],
				[origin[1] + i*segLen,	origin[2] + len/2.0, 	origin[3] + len 	, 			1],
				[origin[1]			 , 	origin[2] + len/2.0, 	origin[3] + i*segLen, 			1],
				[origin[1] + len	 ,	origin[2] + len/2.0, 	origin[3] + i*segLen, 			1],
			] for i in 0:segments]
			..., 
		dims=2)..., dims=2
	) .|> Float32 

	unitColor = cat([
		[0.3, 0.3, 0.3, 3.0],
		[0.3, 0.3, 0.3, 3.0],
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 2), outer=(1, segments+1))

	indexData = reshape(0:4*(segments+1)-1, 2, 2*(segments + 1)) .|> UInt32
		
	MainGrid(
		nothing,
		"LineList",
		vertexData,
		colorData,
		indexData,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
	)
end
