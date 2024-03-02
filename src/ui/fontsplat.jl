
using PlyIO

export GSplatAxis, gsplatAxis

mutable struct GSplatAxisData
	points
	scale
	colors
	quaternions
end

mutable struct GSplatAxis <: Renderable
	gpuDevice
    topology
    vertexData
    colorData
    indexData
    uvData
    uniformData
    uniformBuffer
	splatBuffer
	splatData::Union{Nothing, GSplatAxisData}
	filepath
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

# Goal is to define three splats on each axis and visualize them

function getQuaternion(x)
	qxyz = RotXYZ(x...) |> Rotations.QuatRotation	
	q =	getproperty(qxyz, :q)
	return [q.s, q.v1, q.v2, q.v3]
end


function getSplatData()
	point = [0.4, 0.0, 0.0] .|> Float32
	scale = [0.6, 0.4, 0.4] .|> Float32
	color = [1.0, 0.0, 0.0]  .|> Float32
	quat = [pi/2, 0, 0] .|> Float32
	scales = []
	points = []
	colors = []
	quats = []
	for i in 1:3
		push!(colors, circshift(color, (i-1,)))
		push!(points, circshift(point, (i-1,)))
		push!(scales, circshift(scale, (i-1,)))
		push!(quats, circshift(quat, (i-1,)) |> getQuaternion)
	end
	colors = cat(colors..., dims=(2,))
	scales = cat(scales..., dims=(2,))
	quats = cat(quats..., dims=(2,))
	points = cat(points..., dims=(2,))
	splatData = GSplatAxisData(points, scales, colors, quats) 
	return splatData
end

"""
function getSplatData()
	scales = []
	points = []
	colors = []
	quats = []
	for i in 1:1000
		point = rand(3) .|> Float32
		color = rand(3) .|> Float32
		scale = rand(3) .|> Float32
		quat = rand(3) .|> Float32
		push!(quats, quat |> getQuaternion)
		push!(colors, color)
		push!(points, point)
		push!(scales, scale)
	end
	colors = cat(colors..., dims=(2,))
	scales = cat(scales..., dims=(2,))
	quats = cat(quats..., dims=(2,))
	points = cat(points..., dims=(2,))
	splatData = GSplatAxisData(points, scales, colors, quats) 
	return splatData
end
"""

function gsplatAxis(;scale::Union{Vector{Float32}, Float32} = 1.0f0)

	if typeof(scale) == Float32
		NDCscale = [scale.*ones(Float32, 3)..., 1.0f0] |> diagm
	else
		scale = scale |> diagm
	end

	swapMat = [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1] .|> Float32;
	# swapMat = [1 0 0 0; 0 0 -1 0; 0 1 0 0; 0 0 0 1] .|> Float32;

	vertexData = cat([
		[-1, -1, 0, 1],
		[1, 1, 0, 1],
		[1, -1, 0, 1],
		[-1, 1, 0, 1],
		[-1, -1, 0, 1],
		[1, 1, 0, 1],
	]..., dims=2) .|> Float32

	vertexData = scale*swapMat*vertexData

	indexData = cat([
		[0, 1, 2, 3, 4, 5],
	]..., dims=2) .|> UInt32
	
	box = GSplatAxis(
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
		path,
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


function getShaderCode(gsplat::GSplatAxis, cameraId::Int; binding=0)
	name = Symbol(typeof(gsplat), binding)
	renderableType = typeof(gsplat)
	renderableUniform = Symbol(renderableType, :Uniform)

	# Following https://arxiv.org/pdf/2312.02121.pdf

	shaderSource = quote

		function scaleMatrix(s::Vec3{Float32})::Mat3{Float32}
			@let scale = 0.5
			return Mat3{Float32}(
				exp(s.x)*scale, 0.0, 0.0,
				0.0, exp(s.y)*scale, 0.0,
				0.0, 0.0, exp(s.z)*scale,
			)
		end

		function transToRotMat(mat::Mat4{Float32})::Mat3{Float32}
			return Mat3{Float32}(
				mat[0][0], mat[0][1], mat[0][2], 
				mat[1][0], mat[1][1], mat[1][2], 
				mat[2][0], mat[2][1], mat[2][2],
			)
		end

		function quatToRotMat(q::Vec4{Float32})::Mat3{Float32}
			@let w = q.x
			@let x = q.y
			@let y = q.z
			@let z = q.w
			return Mat3{Float32}(
				1.0 - 2.0*(y*y + z*z), 2.0*(x*y - w*z), 2.0*(x*z + w*y),
				2.0*(x*y + w*z), 1.0 - 2.0*(x*x - z*z), 2.0*(y*z - w*x), 
				2.0*(x*z - w*z), 2.0*(y*z + w*x), 1.0 - 2.0*(x*x + y*y),
			)
		end

		function orthoMatrix(cam::CameraUniform)::Mat4{Float32}
			@let fov::Float32 = cam.fov
			@let f::Float32 = (2.0*tan(fov/2.0))
			@let fr::Float32 = 100.0
			@let nr::Float32 = 0.1
			return Mat4{Float32}(
				(2.0*f)/500.0, 0.0, 0.0, 0.0,
				0.0, (2.0*f)/500.0, 0.0, 0.0,
				0.0, 0.0, (fr + nr)/(fr - nr), -2.0*fr*nr/(fr - nr),
				0.0, 0.0, -1.0, 0.0,
			)
		end

		struct QuadVertex
			@builtin position vertexPos::Vec4{Float32}
		end

		struct GSplatAxisIn
			pos::Vec3{Float32}
			scale::Vec3{Float32}
			color::Vec3{Float32}
			quaternions::Vec4{Float32}
		end

		# Matrices are not allowed yet in wgsl ... 
		struct GSplatAxisOut
			@builtin position pos::Vec4{Float32}
			@location 0 mu::Vec4{Float32}
			@location 1 color::Vec4{Float32}
			@location 2 cov2d::Vec4{Float32}
			@location 3 opacity::Float32
		end

		struct $renderableUniform
			transform::Mat4{Float32}
		end

		@var Uniform 0 $binding $name::$renderableUniform
		@var StorageRead 0 $(binding+1) splatArray::Array{GSplatAxisIn}
		@var StorageRead 0 $(binding+2) vertexArray::Array{Vec4{Float32}, 6}

		@vertex function vs_main(
				@builtin(vertex_index, vIdx::UInt32), 
				@builtin(instance_index, iIdx::UInt32),
				@location 0 quadPos::Vec4{Float32}
			)::GSplatAxisOut
			@var out::GSplatAxisOut
			@let splatIn  = splatArray[iIdx]
			@let R::Mat3{Float32} = quatToRotMat(splatIn.quaternions)
			@let S::Mat3{Float32} = scaleMatrix(splatIn.scale)
			@let M = transpose(S)*R
			@let sigma = transpose(M)*M
			@let pos = Vec4{Float32}(splatIn.pos, 1.0)
			out.pos = $(name).transform*pos
			out.pos = camera.viewMatrix*out.pos
			@let tx = out.pos.x 
			@let ty = out.pos.y
			@let tz = out.pos.z
			out.pos = camera.projMatrix*out.pos
			out.pos = out.pos/out.pos.w
			@let f::Float32 = 2.0*(tan(camera.fov/2.0))

			@let J = SMatrix{2, 3, Float32, 6}(
				f/tz, 0.0, -f*tx/(tz*tz), 
			 	0.0, f/tz, -f*ty/(tz*tz),
			)

			@let Rcam = transToRotMat(camera.viewMatrix)
			@let W = transpose(Rcam)*J
			@let covinter = transpose(sigma)*W
			@let cov4D = transpose(W)*covinter

			@var cov2D = Vec4{Float32}(
				cov4D[0][0], cov4D[0][1],
				cov4D[1][0], cov4D[1][1],
			)

			cov2D[0] = cov2D[0] + 0.3
			cov2D[3] = cov2D[3] + 0.3

			@let a = cov2D[0]
			@let b = cov2D[1]
			@let c = cov2D[2]
			@let d = cov2D[3]

			@let det2D = a*d - b*c
			@let halfad = (a + d)/2.0
			@let eigendir1 = halfad + sqrt(max(0.1, halfad*halfad - det2D))
			@let eigendir2 = halfad - sqrt(max(0.1, halfad*halfad - det2D))
			@let majorAxis = max(eigendir1, eigendir2)
			@let radiusBB = ceil(3.0 * sqrt(majorAxis))
			@let radiusNDC = Vec2{Float32}(radiusBB/500.0, radiusBB/500.0)

			@let quadpos = vertexArray[vIdx]
			out.pos = Vec4{Float32}(out.pos.xy + 2.0*radiusNDC*quadpos.xy, out.pos.zw)
			out.mu = radiusBB*quadpos
			@let SH_C0 = 0.28209479177387814;
			#@let result = SH_C0 * splatIn.sh[0] + 0.5;
			out.cov2d = cov2D
			out.color = Vec4{Float32}(splatIn.color, 1.0)
			out.opacity = 1.0
			return out
		end

		@fragment function fs_main(splatOut::GSplatAxisOut)::@location 0 Vec4{Float32}
			@let mu = splatOut.mu
			@var fragPos = splatOut.pos
			@var fragColor = splatOut.color
			@let opacity = splatOut.opacity

			@let cov2d = Mat2{Float32}(
				splatOut.cov2d[0],
				splatOut.cov2d[1],
				splatOut.cov2d[2],
				splatOut.cov2d[3],
			)

			@let delta = Vec2{Float32}(mu.x, mu.y)
			
			@let invCov2dAdj = Mat2{Float32}(
				cov2d[1][1], -cov2d[0][1],
				-cov2d[0][1], cov2d[0][0]
			)

			@let det::Float32 = determinant(cov2d)

			@escif if (det < 0.0)
				@esc discard
			end
			
			@let invCov2d::Mat2{Float32} = Mat2{Float32}(
			 	invCov2dAdj[0][0]/det,
				invCov2dAdj[0][1]/det,
				invCov2dAdj[0][1]/det,
				invCov2dAdj[1][1]/det,
			)

			@let intensity::Float32 = 0.5*dot(invCov2d*delta, delta)
			
			@escif if (intensity < 0.0)
				@esc discard
			end
			@let alpha = min(0.99, opacity*exp(-intensity))
			@var color = Vec4{Float32}()
			
			@escifelse if alpha > 0.4
				color.x  = fragColor.x*alpha
				color.y  = fragColor.y*alpha
				color.z  = fragColor.z*alpha
				color.w = alpha
			else
				color = Vec4{Float32}(1.0, 1.0, 1.0, 1.0-alpha)
			end
			return color
		end
	end
	return shaderSource
end

function prepareObject(gpuDevice, gsplat::GSplatAxis)
	uniformData = computeUniformData(gsplat)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"GSplatAxis Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)

	splatData = getSplatData();  # TODO remove 

	storageData = vcat(
		splatData.points,
		zeros(UInt32, 1, size(splatData.points, 2)),
		splatData.scale,
		zeros(UInt32, 1, size(splatData.points, 2)),
		splatData.colors,
		zeros(UInt32, 1, size(splatData.points, 2)),
		splatData.quaternions
	) .|> Float32

	storageData = reinterpret(UInt8, storageData)

	(splatBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"GSplatAxisIn Buffer",
		storageData[:],
		["Storage", "CopySrc"]
	)

	data = [
		gsplat.vertexData
	]

	(vertexStorageBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"vertexBuffer",
		vcat(data...),
		["Storage", "CopySrc"]
	)

	setfield!(gsplat, :uniformData, uniformData)
	setfield!(gsplat, :uniformBuffer, uniformBuffer)	
	setfield!(gsplat, :splatData, splatData)
	setfield!(gsplat, :splatBuffer, splatBuffer)
	setfield!(gsplat, :gpuDevice, gpuDevice)
	setfield!(gsplat, :indexBuffer, getIndexBuffer(gpuDevice, gsplat))
	setfield!(gsplat, :vertexBuffer, getVertexBuffer(gpuDevice, gsplat))
	setfield!(gsplat, :vertexStorage, vertexStorageBuffer)
end

function getBindingLayouts(gsplat::GSplatAxis; binding=0)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
		WGPUCore.WGPUBufferEntry => [ # TODO hardcoded
			:binding => binding + 1,
			:visibility=> ["Vertex", "Fragment"],
			:type => "ReadOnlyStorage" # TODO VERTEXWRITABLESTORAGE feature needs to be enabled if its not read-only
		],
		WGPUCore.WGPUBufferEntry => [ # TODO hardcoded
			:binding => binding + 2,
			:visibility => ["Vertex", "Fragment"],
			:type => "ReadOnlyStorage"
		]
	]
	return bindingLayouts
end


function getBindings(gsplat::GSplatAxis, uniformBuffer; binding=0)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
		WGPUCore.GPUBuffer => [
			:binding => binding + 1,
			:buffer => gsplat.splatBuffer,
			:offset => 0,
			:size => gsplat.splatBuffer.size
		],
		WGPUCore.GPUBuffer => [
			:binding => binding + 2,
			:buffer => gsplat.vertexStorage,
			:offset => 0,
			:size => gsplat.vertexStorage.size
		],
	]
	return bindings
end


function preparePipeline(gpuDevice, renderer, gsplat::GSplatAxis)
	scene = renderer.scene
	vertexBuffer = getfield(gsplat, :vertexBuffer)
	uniformBuffer = getfield(gsplat, :uniformBuffer)
	indexBuffer = getfield(gsplat, :indexBuffer)
	bindingLayouts = []
	for camera in scene.cameraSystem
		append!(bindingLayouts, getBindingLayouts(camera; binding = camera.id-1))
	end
	append!(bindingLayouts, getBindingLayouts(gsplat; binding=LIGHT_BINDING_START + MAX_LIGHTS))

	bindings = []
	for camera in scene.cameraSystem
		cameraUniform = getfield(camera, :uniformBuffer)
		append!(bindings, getBindings(camera, cameraUniform; binding = camera.id - 1))
	end

	append!(bindings, getBindings(gsplat, uniformBuffer; binding=LIGHT_BINDING_START + MAX_LIGHTS))
	pipelineLayout = WGPUCore.createPipelineLayout(
		gpuDevice, 
		"[ GSPLAT PIPELINE LAYOUT ]", 
		bindingLayouts, 
		bindings
	)
	gslat.pipelineLayouts = pipelineLayout
	renderPipelineOptions = getRenderPipelineOptions(
		scene,
		gsplat,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label="[ GSplatAxis RENDER PIPELINE ]"
	)
	gsplat.renderPipelines = renderPipeline
end


function getVertexBuffer(gpuDevice, gsplat::GSplatAxis)
	data = [
		gsplat.vertexData
	]

	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"vertexBuffer",
		vcat(data...),
		["Vertex", "CopySrc", "CopyDst"]
	)
	vertexBuffer
end

function getVertexBufferLayout(gsplat::GSplatAxis; offset=0)
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

function getRenderPipelineOptions(renderer, splat::GSplatAxis)
	scene = renderer.scene
	camIdx = scene.cameraId
	renderpipelineOptions = [
		WGPUCore.GPUVertexState => [
			:_module => splat.cshaders[camIdx].internal[],				# SET THIS (AUTOMATICALLY)
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
			:_module => splat.cshaders[camIdx].internal[],						# SET THIS
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

function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, gsplat::GSplatAxis, camIdx::Int)
	WGPUCore.setPipeline(renderPass, gsplat.renderPipelines[camIdx])
	WGPUCore.setIndexBuffer(renderPass, gsplat.indexBuffer, "Uint32")
	WGPUCore.setVertexBuffer(renderPass, 0, gsplat.vertexBuffer)
	WGPUCore.setBindGroup(renderPass, 0, gsplat.pipelineLayouts[camIdx].bindGroup, UInt32[], 0, 99)
	WGPUCore.drawIndexed(renderPass, Int32(gsplat.indexBuffer.size/sizeof(UInt32)); instanceCount = size(gsplat.splatData.points, 2), firstIndex=0, baseVertex= 0, firstInstance=0)
end

Base.show(io::IO, ::MIME"text/plain", gsplat::GSplatAxis) = begin
	print("GSplatAxis : $(typeof(gsplat))")
end
