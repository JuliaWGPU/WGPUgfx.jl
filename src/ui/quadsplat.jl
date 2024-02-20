
using PlyIO

export QSplat, defaultQSplat

struct QuadData
	points
	colors
	radius
end

mutable struct QSplat <: Renderable
	gpuDevice
    topology
    vertexData
    colorData
    indexData
    uvData
    uniformData
    uniformBuffer
	splatBuffer
	splatData::Union{Nothing, QuadData}
	nSplats
    indexBuffer
    vertexBuffer
	vertexStorage
    textureData
    texture
    textureView
    sampler
    pipelineLayouts
    renderPipelines
    cshaders
end

function sigmoid(x)
	if x > 0.0
		return 1 ./(1 .+ exp(-x))
	else
		z = exp(x)
		return z/(1 + z)
	end
end

function generateData(n)
	colors = rand(Float32, n, 3)
	radius = ones(Float32, n, 1)
	points = 0.5*rand(Float32, n, 2)
	splatData = QuadData(points, colors, radius) 
	return splatData
end


function defaultQSplat(nSplats::Int; color=[0.2, 0.9, 0.0, 1.0], scale::Union{Vector{Float32}, Float32} = 1.0f0)

	if typeof(scale) == Float32
		scale = [scale.*ones(Float32, 3)..., 1.0f0] |> diagm
	else
		scale = scale |> diagm
	end

	swapMat = [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1] .|> Float32;
	#swapMat = [1 0 0 0; 0 0 -1 0; 0 1 0 0; 0 0 0 1] .|> Float32;

	vertexData = cat([
		[1, -1, 0, 1],
		[1, 1, 0, 1],
		[-1, -1, 0, 1],
		[-1, -1, 0, 1],
		[1, 1, 0, 1],
		[-1, 1, 0, 1],
	]..., dims=2) .|> Float32

	vertexData = scale*swapMat*vertexData

	indexData = cat([
		[0, 1, 2, 3, 4, 5],
	]..., dims=2) .|> UInt32
	
	box = QSplat(
		nothing, 		# gpuDevice
		"TriangleList",
		vertexData, 
		nothing, 
		indexData, 
		nothing,
		nothing, 		# uniformData
		nothing, 		# uniformBuffer
		nothing,		# splatData
		nothing, 		# splatBuffer
		nSplats,
		nothing, 		# indexBuffer
		nothing,	 	# vertexBuffer
		nothing,
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


function getShaderCode(qsplat::QSplat, cameraId::Int; binding=0)
	name = Symbol(typeof(qsplat), binding)
	renderableType = typeof(qsplat)
	renderableUniform = Symbol(renderableType, :Uniform)

	shaderSource = quote

		struct QuadVertex
			@builtin position vertexPos::Vec4{Float32}
		end

		struct QSplatIn
			pos::Vec2{Float32}
			radius::Float32
			color::Vec3{Float32}
		end

		# Matrices are not allowed yet in wgsl ... 
		struct QSplatOut
			@builtin position pos::Vec4{Float32}
			@location 0 mu::Vec2{Float32}
			@location 1 color::Vec4{Float32}
			@location 2 radius::Float32
			@location 4 offset::Vec2{Float32}
		end

		struct $renderableUniform
			transform::Mat4{Float32}
		end

		@var Uniform 0 $binding $name::$renderableUniform
		@var StorageRead 0 $(binding+1) splatArray::Array{QSplatIn}
		@var StorageRead 0 $(binding+2) vertexArray::Array{Vec4{Float32}, 6}
		# @var StorageRead 0 $(binding+2) vertexArray::Array{Vec3{Float32}, 4}

		@vertex function vs_main(
				@builtin(vertex_index, vIdx::UInt32),
				@builtin(instance_index, iIdx::UInt32),
				@location 0 quadPos::Vec4{Float32}
			)::QSplatOut
			@var out::QSplatOut
			@let splatIn  = splatArray[iIdx]
			@var pos = Vec4{Float32}(splatIn.pos, 0.0, 1.0)
			@let radius = splatIn.radius
			@let quadpos = vertexArray[vIdx]
			out.pos = Vec4{Float32}(pos.xy + 2.0*radius*quadpos.xy, pos.zw)
			out.mu = pos.xy
			# TODO fix this string versions in WGSLTypes ...
			#@let s = "vIdx%6u"
			#@let t = "3u"
			#@escif if s == t
			out.offset = radius*quadpos.xy
			#end
			out.color = Vec4{Float32}(splatIn.color, 1.0)
			return out
		end

		@fragment function fs_main(splatOut::QSplatOut)::@location 0 Vec4{Float32}
			@let mu = -splatOut.mu
			@var fragPos = splatOut.pos
			@var fragColor = splatOut.color
			@let radius = splatOut.radius
			@let offset = splatOut.offset
			
			#@let delta = Vec2{Float32}(mu.xy - fragPos.xy/500.0)
			@let delta = offset.xy
			@let intensity::Float32 = 0.5*dot(delta, delta)/0.1
			
			@escif if (intensity < 0.0)
				@esc discard
			end
			
			@let alpha = min(0.9, exp(-intensity))

			@let color::Vec4{Float32} = Vec4{Float32}(
				fragColor.xyz*alpha,
				alpha
			)
			
			return color
		end
	end
	return shaderSource
end

function prepareObject(gpuDevice, qsplat::QSplat)
	uniformData = computeUniformData(qsplat)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"QSplat Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)

	splatData = generateData(qsplat.nSplats); 
	points = splatData.points .|> Float32;
	colors = splatData.colors .|> Float32;
	radius = splatData.radius .|> Float32;
	
	storageData = hcat(
		points,
		radius, 
		zeros(UInt32, size(points, 1)),
		colors,
		zeros(UInt32, size(points, 1))
	) |> adjoint .|> Float32

	storageData = reinterpret(UInt8, storageData)

	(splatBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"QSplatIn Buffer",
		storageData[:],
		["Storage", "CopySrc"]
	)

	data = [
		qsplat.vertexData
	]

	(vertexStorageBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"vertexBuffer",
		vcat(data...),
		["Storage", "CopySrc"]
	)

	setfield!(qsplat, :uniformData, uniformData)
	setfield!(qsplat, :uniformBuffer, uniformBuffer)	
	setfield!(qsplat, :splatData, splatData)
	setfield!(qsplat, :splatBuffer, splatBuffer)
	setfield!(qsplat, :gpuDevice, gpuDevice)
	setfield!(qsplat, :indexBuffer, getIndexBuffer(gpuDevice, qsplat))
	setfield!(qsplat, :vertexBuffer, getVertexBuffer(gpuDevice, qsplat))
	setfield!(qsplat, :vertexStorage, vertexStorageBuffer)
end

function getBindingLayouts(qsplat::QSplat; binding=0)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
		WGPUCore.WGPUBufferEntry => [ 
			:binding => binding + 1,
			:visibility=> ["Vertex", "Fragment"],
			:type => "ReadOnlyStorage" # TODO VERTEXWRITABLESTORAGE feature needs to be enabled if its not read-only
		],
		WGPUCore.WGPUBufferEntry => [
			:binding => binding + 2,
			:visibility => ["Vertex", "Fragment"],
			:type => "ReadOnlyStorage"
		]
	]
	return bindingLayouts
end


function getBindings(qsplat::QSplat, uniformBuffer; binding=0)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
		WGPUCore.GPUBuffer => [
			:binding => binding + 1,
			:buffer => qsplat.splatBuffer,
			:offset => 0,
			:size => qsplat.splatBuffer.size
		],
		WGPUCore.GPUBuffer => [
			:binding => binding + 2,
			:buffer => qsplat.vertexStorage,
			:offset => 0,
			:size => qsplat.vertexStorage.size
		],
	]
	return bindings
end


function preparePipeline(gpuDevice, renderer, qsplat::QSplat)
	scene = renderer.scene
	vertexBuffer = getfield(qsplat, :vertexBuffer)
	uniformBuffer = getfield(qsplat, :uniformBuffer)
	indexBuffer = getfield(qsplat, :indexBuffer)
	bindingLayouts = []
	for camera in scene.cameraSystem
		append!(bindingLayouts, getBindingLayouts(camera; binding = camera.id-1))
	end
	append!(bindingLayouts, getBindingLayouts(qsplat; binding=LIGHT_BINDING_START + MAX_LIGHTS))

	bindings = []
	for camera in scene.cameraSystem
		cameraUniform = getfield(camera, :uniformBuffer)
		append!(bindings, getBindings(camera, cameraUniform; binding = camera.id - 1))
	end

	append!(bindings, getBindings(qsplat, uniformBuffer; binding=LIGHT_BINDING_START + MAX_LIGHTS))
	pipelineLayout = WGPUCore.createPipelineLayout(
		gpuDevice, 
		"[ QSplat PIPELINE LAYOUT ]", 
		bindingLayouts, 
		bindings
	)
	gslat.pipelineLayouts = pipelineLayout
	renderPipelineOptions = getRenderPipelineOptions(
		scene,
		qsplat,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label="[ QSplat RENDER PIPELINE ]"
	)
	qsplat.renderPipelines = renderPipeline
end


function getVertexBuffer(gpuDevice, qsplat::QSplat)
	data = [
		qsplat.vertexData
	]

	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"vertexBuffer",
		vcat(data...),
		["Vertex", "CopySrc", "CopyDst"]
	)
	vertexBuffer
end

function getVertexBufferLayout(qsplat::QSplat; offset=0)
	WGPUCore.GPUVertexBufferLayout => [
		:arrayStride => 4*4,
		:stepMode => "Vertex",
		:attributes => [
			:attribute => [
				:format => "Float32x4",
				:offset => 0,
				:shaderLocation => offset + 0
			]
		]
	]
end

function getRenderPipelineOptions(renderer, splat::QSplat)
	scene = renderer.scene
	camIdx = scene.cameraId
	renderpipelineOptions = [
		WGPUCore.GPUVertexState => [
			:_module => splat.cshaders[camIdx].internal[],		# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",							# SET THIS (FIXED FOR NOW)
			:buffers => [
					getVertexBufferLayout(splat)
				]
		],
		WGPUCore.GPUPrimitiveState => [
			:topology => splat.topology,
			:frontFace => "CW",
			:cullMode => "None",
			:stripIndexFormat => "Undefined"
		],
		WGPUCore.GPUDepthStencilState => [
			:depthWriteEnabled => false,
			:depthCompare => WGPUCompareFunction_LessEqual,
			:format => WGPUTextureFormat_Depth24Plus
		],
		WGPUCore.GPUMultiSampleState => [
			:count => 1,
			:mask => typemax(UInt32),
			:alphaToCoverageEnabled=>false,
		],
		WGPUCore.GPUFragmentState => [
			:_module => splat.cshaders[camIdx].internal[],		# SET THIS
			:entryPoint => "fs_main",							# SET THIS (FIXED FOR NOW)
			:targets => [
				WGPUCore.GPUColorTargetState =>	[
					:format => renderer.renderTextureFormat,	# SET THIS
					:color => [
						:srcFactor => "One",
						:dstFactor => "OneMinusSrcAlpha",
						:operation => "Add"
					],
					:alpha => [
						:srcFactor => "One",
						:dstFactor => "OneMinusDstAlpha",
						:operation => "Add",
					]
				],
			]
		]
	]
	renderpipelineOptions
end

function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, qsplat::QSplat, camIdx::Int)
	WGPUCore.setPipeline(renderPass, qsplat.renderPipelines[camIdx])
	WGPUCore.setIndexBuffer(renderPass, qsplat.indexBuffer, "Uint32")
	WGPUCore.setVertexBuffer(renderPass, 0, qsplat.vertexBuffer)
	WGPUCore.setBindGroup(renderPass, 0, qsplat.pipelineLayouts[camIdx].bindGroup, UInt32[], 0, 99)
	WGPUCore.drawIndexed(renderPass, Int32(qsplat.indexBuffer.size/sizeof(UInt32)); instanceCount = size(qsplat.splatData.points, 1), firstIndex=0, baseVertex= 0, firstInstance=0)
end

Base.show(io::IO, ::MIME"text/plain", qsplat::QSplat) = begin
	print("QSplat : $(typeof(qsplat))")
end
