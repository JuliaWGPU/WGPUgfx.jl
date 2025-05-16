export isNormalDefined, isTextureDefined

using Tracy

abstract type Renderable end

abstract type WGPUPrimitive <: Renderable end
abstract type MeshSurface <: Renderable end
abstract type MeshWireFrame <: Renderable end
abstract type MeshAxis <: Renderable end

function AABB(mesh::Renderable)
	minCoords = minimum(mesh.vertexData, dims=2)
	maxCoords = maximum(mesh.vertexData, dims=2)
	return hcat([minCoords, maxCoords]...)
end

renderableCount(mesh::Renderable) = 1

isNormalDefined(renderObj::Renderable) = isdefined(renderObj, :normalData)
isNormalDefined(T::Type{<:Renderable}) = :normalData in fieldnames(T)
isTextureDefined(renderObj::Renderable) = isdefined(renderObj, :textureData)

function prepareObject(gpuDevice, mesh::Renderable)
	uniformData = computeUniformData(mesh)
	if isTextureDefined(mesh) && mesh.textureData != nothing
		textureSize = (size(mesh.textureData)[2:3]..., 1)
		texture = WGPUCore.createTexture(
			gpuDevice,
			"Mesh Texture",
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
		setfield!(mesh, :texture, texture)
		setfield!(mesh, :textureView, textureView)
		setfield!(mesh, :sampler, sampler)
		dstLayout = [
			:dst => [
				:texture => texture,
				:mipLevel => 0,
				:origin => ((0, 0, 0) .|> Float32)
			],
			:textureData => mesh.textureData,
			:layout => [
				:offset => 0,
				:bytesPerRow => textureSize[1]*4 |> UInt32, # TODO should be multiple of 256
				:rowsPerImage => textureSize[2] |> UInt32
			],
			:textureSize => textureSize
		]
		try
			WGPUCore.writeTexture(gpuDevice.queue; dstLayout...)
		catch(e)
			@error "Writing texture in MeshLoader failed !!!"
			rethrow(e)
		end

	end
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"Mesh Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(mesh, :uniformData, uniformData)
	setfield!(mesh, :uniformBuffer, uniformBuffer)
	setfield!(mesh, :gpuDevice, gpuDevice)
	setfield!(mesh, :indexBuffer, getIndexBuffer(gpuDevice, mesh))
	setfield!(mesh, :vertexBuffer, getVertexBuffer(gpuDevice, mesh))
	return mesh
end


function preparePipeline(gpuDevice, renderer, mesh::Renderable, camera; binding=MAX_LIGHTS + LIGHT_BINDING_START)
	scene = renderer.scene
	lightUniform = getfield(scene.light, :uniformBuffer)
	vertexBuffer = getfield(mesh, :vertexBuffer)
	uniformBuffer = getfield(mesh, :uniformBuffer)
	indexBuffer = getfield(mesh, :indexBuffer)

	# BindingLayouts
	bindingLayouts = []
	append!(bindingLayouts, getBindingLayouts(camera; binding = camera.id-1))
	if isNormalDefined(mesh)
		append!(bindingLayouts, getBindingLayouts(scene.light; binding = LIGHT_BINDING_START))
	end
	append!(bindingLayouts, getBindingLayouts(mesh; binding= LIGHT_BINDING_START+MAX_LIGHTS))

	# Bindings
	bindings = []
	cameraUniform = getfield(camera, :uniformBuffer)
	append!(bindings, getBindings(camera, cameraUniform; binding = camera.id-1))

	if isNormalDefined(mesh)
		append!(bindings, getBindings(scene.light, lightUniform; binding = LIGHT_BINDING_START))
	end
	append!(bindings, getBindings(mesh, uniformBuffer; binding= LIGHT_BINDING_START + MAX_LIGHTS))
	
	pipelineLayout = WGPUCore.createPipelineLayout(
		gpuDevice, 
		"PipeLineLayout", 
		bindingLayouts, 
		bindings
	)
	mesh.pipelineLayouts[camera.id] = pipelineLayout
	renderPipelineOptions = getRenderPipelineOptions(
		renderer,
		mesh,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label=" MESH RENDER PIPELINE "
	)
	mesh.renderPipelines[camera.id] = renderPipeline
end

function preparePipeline(gpuDevice, renderer, mesh::Renderable; binding=MAX_LIGHTS + LIGHT_BINDING_START)
	scene = renderer.scene
	lightUniform = getfield(scene.light, :uniformBuffer)
	vertexBuffer = getfield(mesh, :vertexBuffer)
	uniformBuffer = getfield(mesh, :uniformBuffer)
	indexBuffer = getfield(mesh, :indexBuffer)

	# BindingLayouts
	bindingLayouts = []
	for camera in scene.cameraSystem
		append!(bindingLayouts, getBindingLayouts(camera; binding = camera.id-1))
	end
	if isNormalDefined(mesh)
		append!(bindingLayouts, getBindingLayouts(scene.light; binding = LIGHT_BINDING_START))
	end
	append!(bindingLayouts, getBindingLayouts(mesh; binding=LIGHT_BINDING_START + MAX_LIGHTS))

	# Bindings
	bindings = []
	for camera in scene.cameraSystem
		cameraUniform = getfield(camera, :uniformBuffer)
		append!(bindings, getBindings(camera, cameraUniform; binding = camera.id - 1))
	end

	if isNormalDefined(mesh)
		append!(bindings, getBindings(scene.light, lightUniform; binding = LIGHT_BINDING_START))
	end
	append!(bindings, getBindings(mesh, uniformBuffer; binding=LIGHT_BINDING_START + MAX_LIGHTS))
	
	pipelineLayout = WGPUCore.createPipelineLayout(
		gpuDevice, 
		"PipeLineLayout", 
		bindingLayouts, 
		bindings
	)
	mesh.pipelineLayouts = pipelineLayout
	renderPipelineOptions = getRenderPipelineOptions(
		scene,
		mesh,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label=" MESH RENDER PIPELINE "
	)
	mesh.renderPipelines = renderPipeline
end

function defaultUniformData(::Type{<:Renderable}) 
	uniformData = ones(Float32, (4,)) |> diagm
	return uniformData
end

# TODO for now mesh is static
# definitely needs change based on position, rotation etc ...
function computeUniformData(mesh::Renderable)
	return defaultUniformData(typeof(mesh))
end


Base.setproperty!(mesh::Renderable, f::Symbol, v) = begin
	setfield!(mesh, f, v)
	setfield!(mesh, :uniformData, f==:uniformData ? v : computeUniformData(mesh))
	updateUniformBuffer(mesh)
end


Base.getproperty(mesh::Renderable, f::Symbol) = begin
	getfield(mesh, f)
end


function getUniformData(mesh::Renderable)
	return mesh.uniformData
end


function updateUniformBuffer(mesh::Renderable)
	data = SMatrix{4, 4}(mesh.uniformData[:])
	# @info :UniformBuffer data
	WGPUCore.writeBuffer(
		mesh.gpuDevice.queue, 
		getfield(mesh, :uniformBuffer),
		data,
	)
end

function readUniformBuffer(mesh::Renderable)
	data = WGPUCore.readBuffer(
		mesh.gpuDevice,
		getfield(mesh, :uniformBuffer),
		0,
		getfield(mesh, :uniformBuffer).size
	)
	datareinterpret = reinterpret(Mat4{Float32}, data)[1]
	# @info "Received Buffer" datareinterpret
end

function getUniformBuffer(mesh::Renderable)
	getfield(mesh, :uniformBuffer)
end

function getShaderCode(mesh::Renderable, cameraId::Int; binding=0)
	name = Symbol(typeof(mesh).name.name, binding)
	meshType = typeof(mesh).name.name
	meshUniform = Symbol(meshType, :Uniform)
	isTexture = isTextureDefined(mesh) && mesh.textureData !== nothing
	isLight = isNormalDefined(mesh)
	vertexInputName = Symbol(
		meshType,
		:VertexInput,
		isLight ? (:LL) : (:NL),
		isTexture ? (:TT) : (:NT),
	)

	vertexOutputName = Symbol(
		meshType,
		:VertexOutput,
		isLight ? (:LL) : (:NL),
		isTexture ? (:TT) : (:NT),
	)

	shaderSource = quote
		struct $vertexInputName
			@location 0 pos::Vec4{Float32}
			@location 1 vColor::Vec4{Float32}
			if $isLight
				@location 2 vNormal::Vec4{Float32}
			end
			if $isTexture
				@location 3 vTexCoords::Vec2{Float32}
			end
		end

		struct $vertexOutputName
			@location 0 vColor::Vec4{Float32}
			@builtin position pos::Vec4{Float32}

			if $isLight
				@location 1 vNormal::Vec4{Float32}
			end
			if $isTexture
				@location 2 vTexCoords::Vec2{Float32}
			end
		end

		struct $meshUniform
			transform::Mat4{Float32}
		end
		
		@var Uniform 0 $binding $name::$meshUniform
		
		if $isTexture
			@var Generic 0 $(binding + 1)  tex::Texture2D{Float32}
			@var Generic 0 $(binding + 2)  smplr::Sampler
		end

		@vertex function vs_main(vertexIn::$vertexInputName)::$vertexOutputName
			@var out::$vertexOutputName
			out.pos = $(name).transform*vertexIn.pos
			out.pos = camera.viewMatrix*out.pos
			out.pos = camera.projMatrix*out.pos
			out.vColor = vertexIn.vColor
			if $isTexture
				out.vTexCoords = vertexIn.vTexCoords
			end
			if $isLight
				out.vNormal = $(name).transform*vertexIn.vNormal
				out.vNormal = camera.viewMatrix*out.vNormal
				out.vNormal = camera.projMatrix*out.vNormal
			end
			return out
		end

		@fragment function fs_main(fragmentIn::$vertexOutputName)::@location 0 Vec4{Float32}
			if $isTexture
				@var color::Vec4{Float32} = textureSample(tex, smplr, fragmentIn.vTexCoords)
			else
				@var color::Vec4{Float32} = fragmentIn.vColor
			end
			if $isLight
				@let N::Vec3{Float32} = normalize(fragmentIn.vNormal.xyz)
				@let L::Vec3{Float32} = normalize(lighting.position.xyz - fragmentIn.pos.xyz)
				@let V::Vec3{Float32} = normalize(camera.eye.xyz - fragmentIn.pos.xyz)
				@let H::Vec3{Float32} = normalize(L + V)
				@let diffuse::Float32 = lighting.diffuseIntensity*max(dot(N, L), 0.0)
				@let specular::Float32 = lighting.specularIntensity*pow(max(dot(N, H), 0.0), lighting.specularShininess)
				@let ambient::Float32 = lighting.ambientIntensity
				return color*(ambient + diffuse) + lighting.specularColor*specular
			else
				return color
			end
		end

 	end
 	
	return shaderSource
end


# TODO check it its called multiple times
function getVertexBuffer(gpuDevice, mesh::Renderable)
	data = [
		mesh.vertexData,
		mesh.colorData
	]
	
	if isNormalDefined(mesh)
		push!(data, mesh.normalData)
	else
		push!(data, zeros(size(mesh.vertexData)))
	end

	if isTextureDefined(mesh) && mesh.textureData !== nothing
		push!(data, mesh.uvData)
	end
	
	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat(data...), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end


function getIndexBuffer(gpuDevice, mesh::Renderable)
	(indexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		mesh.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end


function getVertexBufferLayout(mesh::Renderable; offset=0)
	WGPUCore.GPUVertexBufferLayout => [
		:arrayStride => (isTextureDefined(mesh) && mesh.textureData !== nothing) ? 14*4 : 12*4,
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
		][(isTextureDefined(mesh) && mesh.textureData !== nothing) ? (1:end) : (1:end-1)]
	]
end


function getBindingLayouts(mesh::Renderable; binding=0)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		]
	]
	if isTextureDefined(mesh) && mesh.textureData !== nothing
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


function getBindings(mesh::Renderable, uniformBuffer; binding=0)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
	]
	if (isTextureDefined(mesh) && mesh.textureData !== nothing) 
		append!(
			bindings, 	
			[				
				WGPUCore.GPUTextureView => [
					:binding => binding + 1, 
					:textureView => mesh.textureView
				],
				WGPUCore.GPUSampler => [
					:binding => binding + 2,
					:sampler => mesh.sampler
				]
			]
		)
	end
	return bindings
end

function getRenderPipelineOptions(renderer, mesh::Renderable)
	scene = renderer.scene
	camIdx = scene.cameraId
	renderpipelineOptions = [
		WGPUCore.GPUVertexState => [
			:_module => mesh.cshaders[camIdx].internal[],				# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",							# SET THIS (FIXED FOR NOW)
			:buffers => [
					getVertexBufferLayout(mesh)
				]
		],
		WGPUCore.GPUPrimitiveState => [
			:topology => mesh.topology,
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
			:_module => mesh.cshaders[camIdx].internal[],						# SET THIS
			:entryPoint => "fs_main",							# SET THIS (FIXED FOR NOW)
			:targets => [
				WGPUCore.GPUColorTargetState =>	[
					:format => renderer.renderTextureFormat,				# SET THIS
					:color => [
						:srcFactor => "One",
						:dstFactor => "Zero",
						:operation => "Add"
					],
					:alpha => [
						:srcFactor => "One",
						:dstFactor => "Zero",
						:operation => "Add",
					]
				],
			]
		]
	]
	renderpipelineOptions
end

function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, mesh::Renderable, camIdx::Int)
	WGPUCore.setPipeline(renderPass, mesh.renderPipelines[camIdx])
	WGPUCore.setIndexBuffer(renderPass, mesh.indexBuffer, "Uint32")
	WGPUCore.setVertexBuffer(renderPass, 0, mesh.vertexBuffer)
	WGPUCore.setBindGroup(renderPass, 0, mesh.pipelineLayouts[camIdx].bindGroup, UInt32[], 0, 99)
	WGPUCore.drawIndexed(renderPass, Int32(mesh.indexBuffer.size/sizeof(UInt32)); instanceCount = 1, firstIndex=0, baseVertex= 0, firstInstance=0)
end


Base.show(io::IO, ::MIME"text/plain", renderable::Renderable) = begin
	print("Renderable : $(typeof(renderable))")
end
