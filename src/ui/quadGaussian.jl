export defaultGaussianQuad, GaussianQuad

mutable struct GaussianQuad <: RenderableUI
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

function defaultGaussianQuad(; color=[0.2, 0.4, 0.8, 1.0], scale::Union{Vector{Float32}, Float32} = 1.0f0)

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

	
	box = GaussianQuad(
		nothing, 		# gpuDevice
		"TriangleList",
		vertexData, 
		colorData, 
		indexData, 
		nothing,		# uvData
		nothing, 		# uniformData
		nothing, 		# uniformBuffer
		nothing, 		# indexBuffer
		nothing,	 	# vertexBuffer
		nothing,		# textureData
		nothing,	# texture
		nothing,	# textureView
		nothing,	# sampler
		Dict(),		# pipelineLayout
		Dict(),		# renderPipeline
		Dict(),		# cshader
	)
	box
end


function getShaderCode(quad::GaussianQuad, cameraId::Int; binding=0)
	name = Symbol(typeof(quad), binding)
	quadType = typeof(quad)
	quadUniform = Symbol(quadType, :Uniform)
	isTexture = isTextureDefined(quad) && quad.textureData !== nothing
	isLight = isNormalDefined(quad)
	vertexInputName = Symbol(
		:VertexInput,
		isLight ? (:LL) : (:NL),
		isTexture ? (:TT) : (:NT),
	)

	vertexOutputName = Symbol(
		:VertexOutput,
		isLight ? (:LL) : (:NL),
		isTexture ? (:TT) : (:NT),
	)

	shaderSource = quote
		struct $vertexInputName
			@location 0 pos::Vec4{Float32}
			@location 1 vColor::Vec4{Float32}
		end

		struct $vertexOutputName
			@location 0 vColor::Vec4{Float32}
			@location 1 vPosition::Vec4{Float32}
			@builtin position pos::Vec4{Float32}
		end

		struct $quadUniform
			transform::Mat4{Float32}
		end
		
		@var Uniform 0 $binding $name::$quadUniform
		
		@vertex function vs_main(vertexIn::$vertexInputName)::$vertexOutputName
			@var out::$vertexOutputName
			out.pos = ($(name).transform)*vertexIn.pos
			out.vPosition = vertexIn.pos
			out.vColor = vertexIn.vColor
			return out
		end

		@fragment function fs_main(fragmentIn::$vertexOutputName)::@location 0 Vec4{Float32}
			@let pos::Vec2{Float32} = Vec2{Float32}(fragmentIn.vPosition.x/500.0, fragmentIn.vPosition.y/500.0)
			@let delta = Vec2{Float32}(pos - fragmentIn.pos.xy)
			@let dist = 1.0/sqrt(2.0*3.14*0.1)*(sin(-(delta.x*delta.x + delta.y*delta.y)/0.1))
			@var color::Vec4{Float32} = Vec4{Float32}(fragmentIn.vColor.rgb,  1.0-dist)
			return color
		end
 	end
 	
	return shaderSource
end
