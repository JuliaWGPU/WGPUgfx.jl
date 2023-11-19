export isNormalDefined, isTextureDefined

abstract type RenderableUI end


isNormalDefined(renderObj::RenderableUI) = isdefined(renderObj, :normalData)
isNormalDefined(T::Type{<:RenderableUI}) = :normalData in fieldnames(T)
isTextureDefined(renderObj::RenderableUI) = isdefined(renderObj, :textureData)

function prepareObject(gpuDevice, quad::RenderableUI)
	uniformData = computeUniformData(quad)
	if isTextureDefined(quad) && quad.textureData !== nothing
		textureSize = (size(quad.textureData)[2:3]..., 1)
		texture = WGPUCore.createTexture(
			gpuDevice,
			"Quad Texture",
			textureSize,
			1,
			1,
			WGPUCore.WGPUTextureDimension_2D,
			WGPUCore.WGPUTextureFormat_RGBA8UnormSrgb,
			WGPUCore.getEnum(
				WGPUCore.WGPUTextureUsage, 
				[
					"CopyDst",
					"TextureBinding"
				]
			)
		)
		textureView = WGPUCore.createView(texture)
		sampler = WGPUCore.createSampler(gpuDevice)
		setfield!(quad, :texture, texture)
		setfield!(quad, :textureView, textureView)
		setfield!(quad, :sampler, sampler)
		dstLayout = [
			:dst => [
				:texture => texture,
				:mipLevel => 0,
				:origin => ((0, 0, 0) .|> Float32)
			],
			:textureData => quad.textureData,
			:layout => [
				:offset => 0,
				:bytesPerRow => (textureSize[1]*4) |> UInt32, # TODO should be multiple of 256
				:rowsPerImage => textureSize[2] |> UInt32
			],
			:textureSize => textureSize
		]
		try
			WGPUCore.writeTexture(gpuDevice.queue; dstLayout...)
		catch(e)
			@error "Writing texture in QuadLoader failed !!!"
			rethrow(e)
		end

	end
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"Quad Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(quad, :uniformData, uniformData)
	setfield!(quad, :uniformBuffer, uniformBuffer)
	setfield!(quad, :gpuDevice, gpuDevice)
	setfield!(quad, :indexBuffer, getIndexBuffer(gpuDevice, quad))
	setfield!(quad, :vertexBuffer, getVertexBuffer(gpuDevice, quad))
	return quad
end


function preparePipeline(gpuDevice, renderer, quad::RenderableUI, camera; binding=0)
	scene = renderer.scene
	lightUniform = getfield(scene.light, :uniformBuffer)
	vertexBuffer = getfield(quad, :vertexBuffer)
	uniformBuffer = getfield(quad, :uniformBuffer)
	indexBuffer = getfield(quad, :indexBuffer)

	# BindingLayouts
	bindingLayouts = []
	append!(bindingLayouts, getBindingLayouts(quad; binding= binding ))

	# Bindings
	bindings = []
	append!(bindings, getBindings(quad, uniformBuffer; binding= binding))
	
	pipelineLayout = WGPUCore.createPipelineLayout(
		gpuDevice, 
		"PipeLineLayout", 
		bindingLayouts, 
		bindings
	)
	quad.pipelineLayouts[camera.id] = pipelineLayout
	renderPipelineOptions = getRenderPipelineOptions(
		renderer,
		quad,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label=" QUAD RENDER PIPELINE "
	)
	quad.renderPipelines[camera.id] = renderPipeline
end

function preparePipeline(gpuDevice, renderer, quad::RenderableUI; binding=binding)
	scene = renderer.scene
	lightUniform = getfield(scene.light, :uniformBuffer)
	vertexBuffer = getfield(quad, :vertexBuffer)
	uniformBuffer = getfield(quad, :uniformBuffer)
	indexBuffer = getfield(quad, :indexBuffer)

	# BindingLayouts
	bindingLayouts = []
	append!(bindingLayouts, getBindingLayouts(quad; binding=binding))

	# Bindings
	bindings = []

	append!(bindings, getBindings(quad, uniformBuffer; binding=binding))
	
	pipelineLayout = WGPUCore.createPipelineLayout(
		gpuDevice, 
		"PipeLineLayout", 
		bindingLayouts, 
		bindings
	)
	quad.pipelineLayouts = pipelineLayout
	renderPipelineOptions = getRenderPipelineOptions(
		scene,
		quad,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label=" QUAD RENDER PIPELINE "
	)
	quad.renderPipelines = renderPipeline
end

function defaultUniformData(::Type{<:RenderableUI}) 
	uniformData = ones(Float32, (4,)) |> diagm
	return uniformData
end

# TODO for now quad is static
# definitely needs change based on position, rotation etc ...
function computeUniformData(quad::RenderableUI)
	return defaultUniformData(typeof(quad))
end


Base.setproperty!(quad::RenderableUI, f::Symbol, v) = begin
	setfield!(quad, f, v)
	setfield!(quad, :uniformData, f==:uniformData ? v : computeUniformData(quad))
	updateUniformBuffer(quad)
end


Base.getproperty(quad::RenderableUI, f::Symbol) = begin
	getfield(quad, f)
end


function getUniformData(quad::RenderableUI)
	return quad.uniformData
end


function updateUniformBuffer(quad::RenderableUI)
	data = SMatrix{4, 4}(quad.uniformData[:])
	WGPUCore.writeBuffer(
		quad.gpuDevice.queue, 
		getfield(quad, :uniformBuffer),
		data,
	)
end

function readUniformBuffer(quad::RenderableUI)
	data = WGPUCore.readBuffer(
		quad.gpuDevice,
		getfield(quad, :uniformBuffer),
		0,
		getfield(quad, :uniformBuffer).size
	)
	datareinterpret = reinterpret(Mat4{Float32}, data)[1]
	# @info "Received Buffer" datareinterpret
end

function getUniformBuffer(quad::RenderableUI)
	getfield(quad, :uniformBuffer)
end

function getShaderCode(quad::RenderableUI, cameraId::Int; binding=0)
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
			if $isTexture
				@location 3 vTexCoords::Vec2{Float32}
			end
		end

		struct $vertexOutputName
			@location 0 vColor::Vec4{Float32}
			@builtin position pos::Vec4{Float32}
			if $isTexture
				@location 2 vTexCoords::Vec2{Float32}
			end
		end

		struct $quadUniform
			transform::Mat4{Float32}
		end
		
		@var Uniform 0 $binding $name::@user $quadUniform
		
		if $isTexture
			@var Generic 0 $(binding + 1)  tex::Texture2D{Float32}
			@var Generic 0 $(binding + 2)  smplr::Sampler
		end

		@vertex function vs_main(vertexIn::@user $vertexInputName)::@user $vertexOutputName
			@var out::@user $vertexOutputName
			out.pos = $(name).transform*vertexIn.pos;
			out.vColor = vertexIn.vColor
			if $isTexture
				out.vTexCoords = vertexIn.vTexCoords
			end
			return out
		end

		@fragment function fs_main(fragmentIn::@user $vertexOutputName)::@location 0 Vec4{Float32}
			if $isTexture
				@var color::Vec4{Float32} = textureSample(tex, smplr, fragmentIn.vTexCoords)
			else
				@var color::Vec4{Float32} = fragmentIn.vColor
			end
			return color
		end

 	end
 	
	return shaderSource
end


# TODO check it its called multiple times
function getVertexBuffer(gpuDevice, quad::RenderableUI)
	data = [
		quad.vertexData,
		quad.colorData
	]
	
	if isNormalDefined(quad)
		push!(data, quad.normalData)
	else
		push!(data, zeros(size(quad.vertexData)))
	end
	if isTextureDefined(quad) && quad.textureData !== nothing
		push!(data, quad.uvData)
	end
	
	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat(data...), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end


function getIndexBuffer(gpuDevice, quad::RenderableUI)
	(indexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		quad.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end


function getVertexBufferLayout(quad::RenderableUI; offset=0)
	WGPUCore.GPUVertexBufferLayout => [
		:arrayStride => (isTextureDefined(quad) && quad.textureData !== nothing) ? 14*4 : 12*4,
		:stepMode => "Vertex",
		:attributes => [
			:attribute => [
				:format => "Float32x4",
				:offset => 0,
				:shaderLocation => offset + 0
			],
			:attribute => [
				:format => "Float32x4",
				:offset => 4*4,
				:shaderLocation => offset + 1
			],
			:attribute => [
				:format => "Float32x4",
				:offset => 8*4,
				:shaderLocation => offset + 2
			],
			:attribute => [
				:format => "Float32x2",
				:offset => 12*4,
				:shaderLocation => offset + 3
			]
		][(isTextureDefined(quad) && quad.textureData !== nothing) ? (1:end) : (1:end-1)]
	]
end


function getBindingLayouts(quad::RenderableUI; binding=0)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		]
	]
	if isTextureDefined(quad) && quad.textureData !== nothing
		append!(
			bindingLayouts, 
			[			
				WGPUCore.WGPUTextureEntry => [ # TODO hardcoded
					:binding => binding + 1,
					:visibility=> "Fragment",
					:sampleType => "Float",
					:viewDimension => "2D",
					:multisampled => false
				],
				WGPUCore.WGPUSamplerEntry => [ # TODO hardcoded
					:binding => binding + 2,
					:visibility => "Fragment",
					:type => "Filtering"
				]
			]
		)
	end
	return bindingLayouts
end


function getBindings(quad::RenderableUI, uniformBuffer; binding=0)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
	]
	if (isTextureDefined(quad) && quad.textureData !== nothing) 
		append!(
			bindings, 	
			[				
				WGPUCore.GPUTextureView => [
					:binding => binding + 1, 
					:textureView => quad.textureView
				],
				WGPUCore.GPUSampler => [
					:binding => binding + 2,
					:sampler => quad.sampler
				]
			]
		)
	end
	return bindings
end

function getRenderPipelineOptions(renderer, quad::RenderableUI)
	scene = renderer.scene
	camIdx = scene.cameraId
	renderpipelineOptions = [
		WGPUCore.GPUVertexState => [
			:_module => quad.cshaders[camIdx].internal[],				# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",							# SET THIS (FIXED FOR NOW)
			:buffers => [
					getVertexBufferLayout(quad)
				]
		],
		WGPUCore.GPUPrimitiveState => [
			:topology => quad.topology,
			:frontFace => "CCW",
			:cullMode => "Back",
			:stripIndexFormat => "Undefined"
		],
		WGPUCore.GPUDepthStencilState => [
			:depthWriteEnabled => true,
			:depthCompare => WGPUCompareFunction_LessEqual,
			:format => WGPUTextureFormat_Depth24Plus
		],
		WGPUCore.GPUMultiSampleState => [
			:count => 1,
			:mask => typemax(UInt32),
			:alphaToCoverageEnabled=>false,
		],
		WGPUCore.GPUFragmentState => [
			:_module => quad.cshaders[camIdx].internal[],						# SET THIS
			:entryPoint => "fs_main",							# SET THIS (FIXED FOR NOW)
			:targets => [
				WGPUCore.GPUColorTargetState =>	[
					:format => renderer.renderTextureFormat,				# SET THIS
					:color => [
						:srcFactor => "One",
						:dstFactor => "OneMinusSrcAlpha",
						:operation => "Add"
					],
					:alpha => [
						:srcFactor => "One",
						:dstFactor => "OneMinusSrcAlpha",
						:operation => "Add",
					]
				],
			]
		]
	]
	renderpipelineOptions
end

function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, quad::RenderableUI, camIdx::Int)
	WGPUCore.setPipeline(renderPass, quad.renderPipelines[camIdx])
	WGPUCore.setIndexBuffer(renderPass, quad.indexBuffer, "Uint32")
	WGPUCore.setVertexBuffer(renderPass, 0, quad.vertexBuffer)
	WGPUCore.setBindGroup(renderPass, 0, quad.pipelineLayouts[camIdx].bindGroup, UInt32[], 0, 99)
	WGPUCore.drawIndexed(renderPass, Int32(quad.indexBuffer.size/sizeof(UInt32)); instanceCount = 1, firstIndex=0, baseVertex= 0, firstInstance=0)
end
