
using PlyIO

export GSplat, defaultGSplat

mutable struct GSplatData
	points
	scale
	sphericalHarmonics
	quaternions
	opacity
	features
end

mutable struct GSplat <: Renderable
	gpuDevice
    topology
    vertexData
    colorData
    indexData
    uvData
    uniformData
    uniformBuffer
	splatBuffer
	splatData::Union{Nothing, GSplatData}
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
    splatScale
    splatScaleBuffer
end

function readPlyFile(path)
	plyData = PlyIO.load_ply(path);
	vertexElement = plyData["vertex"]
	sh = cat(map((x) -> getindex(vertexElement, x), ["f_dc_0", "f_dc_1", "f_dc_2"])..., dims=2)
	scale = cat(map((x) -> getindex(vertexElement, x), ["scale_0", "scale_1", "scale_2"])..., dims=2)
	# normals = cat(map((x) -> getindex(vertexElement, x), ["nx", "ny", "nz"])..., dims=2)
	points = cat(map((x) -> getindex(vertexElement, x), ["x", "y", "z"])..., dims=2)
	quaternions = cat(map((x) -> getindex(vertexElement, x), ["rot_0", "rot_1", "rot_2", "rot_3"])..., dims=2)
	features = cat(map((x) -> getindex(vertexElement, x), ["f_rest_$i" for i in 0:44])..., dims=2)
	opacity = vertexElement["opacity"] .|> sigmoid
	splatData = GSplatData(points, scale, sh, quaternions, opacity, features) 
	return splatData
end


function defaultGSplat(
		path::String; 
		color=[0.2, 0.9, 0.0, 1.0], 
		scale::Union{Vector{Float32}, Float32} = 1.0f0,
		splatScale::Float32 = 1.0f0
	)

	if typeof(scale) == Float32
		scale = [scale.*ones(Float32, 3)..., 1.0f0] |> diagm
	else
		scale = scale |> diagm
	end

	swapMat = [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1] .|> Float32;
	# swapMat = [1 0 0 0; 0 0 -1 0; 0 1 0 0; 0 0 0 1] .|> Float32;

	vertexData = cat([
		[-1, 1, 0, 1],
		[-1, -1, 0, 1],
		[1, 1, 0, 1],
		[1, 1, 0, 1],
		[-1, -1, 0, 1],
		[1, -1, 0, 1],
	]..., dims=2) .|> Float32

	vertexData = scale*swapMat*vertexData

	indexData = cat([
		[0, 1, 2, 3, 4, 5],
	]..., dims=2) .|> UInt32
	
	box = GSplat(
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
		splatScale,	# splatScale
		nothing,	# splatScaleBuffer
	)
	box
end


function getShaderCode(gsplat::GSplat, cameraId::Int; binding=0)
	name = Symbol(typeof(gsplat), binding)
	renderableType = typeof(gsplat)
	renderableUniform = Symbol(renderableType, :Uniform)

	# Following https://arxiv.org/pdf/2312.02121.pdf

	shaderSource = quote

		function scaleMatrix(s::Vec3{Float32}, scale::Float32)::Mat4{Float32}
			return Mat4{Float32}(
				exp(s.x)*(scale), 0.0, 0.0, 0.0,
				0.0, exp(s.y)*(scale), 0.0, 0.0,
				0.0, 0.0, exp(s.z)*(scale), 0.0,
				0.0, 0.0, 0.0, 1.0
			)
		end

		function transToRotMat(mat::Mat4{Float32})::Mat4{Float32}
			return Mat4{Float32}(
				mat[0][0], mat[0][1], mat[0][2], 0.0,
				mat[1][0], mat[1][1], mat[1][2], 0.0,
				mat[2][0], mat[2][1], mat[2][2], 0.0,
				0.0, 0.0, 0.0, 1.0
			)
		end

		function quatToRotMat(q::Vec4{Float32})::Mat4{Float32}
			@let w = q.x
			@let x = q.y
			@let y = q.z
			@let z = q.w
			return """mat4x4<f32>(
				1.0 - 2.0*(y*y + z*z), 2.0*(x*y - w*z), 2.0*(x*z + w*y), 0.0,
				2.0*(x*y + w*z), 1.0 - 2.0*(x*x - z*z), 2.0*(y*z - w*x), 0.0, 
				2.0*(x*z - w*y), 2.0*(y*z + w*x), 1.0 - 2.0*(x*x + y*y), 0.0,
				0.0, 0.0, 0.0, 1.0
			)
			"""
		end

		struct QuadVertex
			@builtin position vertexPos::Vec4{Float32}
		end

		struct GSplatIn
			pos::Vec3{Float32}
			scale::Vec3{Float32}
			opacity::Float32
			sh::SMatrix{3, 4, Float32, 12} # Temporary solution for size limits
			quaternions::Vec4{Float32}
		end

		# Matrices are not allowed yet in wgsl ... 
		struct GSplatOut
			@builtin position pos::Vec4{Float32}
			@location 0 mu::Vec2{Float32}
			@location 1 color::Vec4{Float32}
			@location 2 cov2d::Vec4{Float32}
			@location 3 opacity::Float32
		end

		struct $renderableUniform
			transform::Mat4{Float32}
		end

		@var Uniform 0 $binding $name::$renderableUniform
		@var StorageRead 0 $(binding+1) splatArray::Array{GSplatIn}
		@var StorageRead 0 $(binding+2) vertexArray::Array{Vec4{Float32}, 6}
		@var Uniform 0 $(binding + 3) scale::Float32
		# @var StorageRead 0 $(binding+2) vertexArray::Array{Vec3{Float32}, 4}

		@vertex function vs_main(
				@builtin(vertex_index, vIdx::UInt32), 
				@builtin(instance_index, iIdx::UInt32),
				@location 0 quadPos::Vec4{Float32}
			)::GSplatOut
			@var out::GSplatOut
			@var splatIn  = splatArray[iIdx]
			@let R::Mat4{Float32} = quatToRotMat(splatIn.quaternions)
			@let S::Mat4{Float32} = scaleMatrix(splatIn.scale, scale)
			@let M = S*R
			@let sigma = transpose(M)*(M)
			@var pos = Vec4{Float32}(splatIn.pos, 1.0)
			# pos = $(name).transform*pos
			@let t = camera.viewMatrix*pos
			# t = t/t.w
			# splatIn.pos = t.xyz

			@let limx = 1.3*camera.fov;
			@let limy = 1.3*camera.fov;
			@let txtz = t.x/t.z
			@let tytz = t.y/t.z
			@let tx = min(limx, max(-limx, txtz)) * t.z;
			@let ty = min(limy, max(-limy, tytz)) * t.z;
			@let tz = t.z
			
			@let f::Float32 = 1200.0*(tan(camera.fov/2.0))
			
			@let J = """
				mat2x4<f32>(
				f/tz, 0.0, -f*tx/(tz*tz), 0.0, 
			 	0.0, f/tz, -f*ty/(tz*tz), 0.0,
				)
			"""
			
			@let Rcam = transToRotMat(camera.viewMatrix)
			@let W::SMatrix{2, 4, Float32, 8} = Rcam*J
			@let covinter::SMatrix{2, 4, Float32, 8} = sigma*W
			@let cov4D::Mat2{Float32} = transpose(W)*covinter
			
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
			@let halfadtmp = (a + d)
			@let halfad = halfadtmp/2.0
			@let eigendir1 = halfad - sqrt(max(0.1, halfad*halfad - det2D))
			@let eigendir2 = halfad + sqrt(max(0.1, halfad*halfad - det2D))
			@let majorAxis = max(eigendir1, eigendir2)
			@let radiusBB = ceil(3.0 * sqrt(majorAxis))
			@let radiusNDC = Vec2{Float32}(radiusBB/1000.0, radiusBB/1000.0)
			
			@let quadpos = vertexArray[vIdx]
			# t′ value
			out.pos = camera.projMatrix*t
			out.pos = out.pos/out.pos.w
			# out.mu = out.pos
			out.pos = Vec4{Float32}(out.pos.xy + 2.0*radiusNDC*quadpos.xy, out.pos.zw)
			# out.pos = out.pos/out.pos.w
			# splatIn.pos = out.pos.xyz
			out.mu = radiusBB*quadpos.xy
			@let SH_C0 = 0.28209479177387814
			@let SH_C1 = 0.48860251190291990
			@let SH_Mat = SMatrix{4, 3, Float32, 12}(
				splatIn.sh[0][0], splatIn.sh[0][1], splatIn.sh[0][2], splatIn.sh[0][3],
				splatIn.sh[1][0], splatIn.sh[1][1], splatIn.sh[1][2], splatIn.sh[1][3],
				splatIn.sh[2][0], splatIn.sh[2][1], splatIn.sh[2][2], splatIn.sh[2][3]
			);
			#@let eye = Vec3{Float32}(0.0, 0.0, 4.0)
			@let dir = normalize(out.pos.xyz + (camera.eye.xyz - camera.lookAt.xyz))
			
			@let x = dir.x;
			@let y = dir.y;
			@let z = dir.z;
			@var result = SH_C0*SH_Mat[0]
			result = result + SH_C1 * (-y * SH_Mat[1] + z * SH_Mat[2] - x * SH_Mat[3]);
			result = result + 0.5
			result = max(result, Vec3{Float32}(0.0))
			out.cov2d = cov2D
			out.opacity = splatIn.opacity
			out.color = Vec4{Float32}(result, out.opacity)
			return out
		end

		@fragment function fs_main(splatOut::GSplatOut)::@location 0 Vec4{Float32}
			@let mu = -splatOut.mu
			@var fragPos = splatOut.pos
			@var fragColor = splatOut.color
			@let opacity = splatOut.opacity
			
			@let cov2d = Mat2{Float32}(
				splatOut.cov2d[0],
				splatOut.cov2d[1],
				splatOut.cov2d[2],
				splatOut.cov2d[3],
			)
			
			@let delta = Vec2{Float32}(mu.xy)
			
			@let invCov2dAdj = Mat2{Float32}(
				cov2d[1][1], -cov2d[0][1],
				-cov2d[1][0], cov2d[0][0]
			)
			
			@let det::Float32 = determinant(cov2d)
			
			@escif if (det <= 0.0)
				@esc discard
			end
			
			@let invCov2d::Mat2{Float32} = Mat2{Float32}(
			 	invCov2dAdj[0][0]/det,
				invCov2dAdj[0][1]/det,
				invCov2dAdj[1][0]/det,
				invCov2dAdj[1][1]/det,
			)
			
			@let intensity::Float32 = 0.5*dot(invCov2d*delta, delta)
			
			@escif if (intensity < 0.0)
				@esc discard
			end
			
			@let alpha = min(0.99, opacity*exp(-intensity))

			@let color::Vec4{Float32} = Vec4{Float32}(
				fragColor.xyz*alpha,
				alpha
			)
			
			return color
		end
	end
	return shaderSource
end


#function Base.unsafe_copyto!(gpuDevice, dst::Ptr{T}, src::GPUBuffer)
#	cmdEncoder = WGPUCore.createComm
#end

function prepareObject(gpuDevice, gsplat::GSplat)
	uniformData = computeUniformData(gsplat)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"GSPLAT Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)

	splatData = readPlyFile(gsplat.filepath); 
	points = splatData.points .|> Float32;
	scale = splatData.scale  .|> Float32;
	opacity = splatData.opacity .|> Float32;
	quaternions = splatData.quaternions .|> Float32;
	sh = hcat(splatData.sphericalHarmonics, splatData.features[:, 1:9]) .|> Float32;

	storageData = hcat(
		points,
		zeros(UInt32, size(points, 1)),
		scale,
		opacity,
		sh,
		quaternions
	) |> adjoint .|> Float32

	storageData = reinterpret(UInt8, storageData)

	(splatBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"GSPLATIn Buffer",
		storageData[:],
		["Storage", "CopySrc", "CopyDst"]
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

	(splatScaleBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"SPLAT Scale",
		Float32[gsplat.splatScale,],
		["Uniform", "CopyDst", "CopySrc"]
	)

	setfield!(gsplat, :uniformData, uniformData)
	setfield!(gsplat, :uniformBuffer, uniformBuffer)	
	setfield!(gsplat, :splatData, splatData)
	setfield!(gsplat, :splatBuffer, splatBuffer)
	setfield!(gsplat, :splatScaleBuffer, splatScaleBuffer)
	setfield!(gsplat, :gpuDevice, gpuDevice)
	setfield!(gsplat, :indexBuffer, getIndexBuffer(gpuDevice, gsplat))
	setfield!(gsplat, :vertexBuffer, getVertexBuffer(gpuDevice, gsplat))
	setfield!(gsplat, :vertexStorage, vertexStorageBuffer)
end

function getBindingLayouts(gsplat::GSplat; binding=0)
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
		],
		WGPUCore.WGPUBufferEntry => [
			:binding => binding + 3,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		]
	]
	return bindingLayouts
end


function getBindings(gsplat::GSplat, uniformBuffer; binding=0)
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
		WGPUCore.GPUBuffer => [
			:binding => binding + 3,
			:buffer => gsplat.splatScaleBuffer,
			:offset => 0,
			:size => sizeof(Float32)
		]
	]
	return bindings
end


function preparePipeline(gpuDevice, renderer, gsplat::GSplat)
	scene = renderer.scene
	vertexBuffer = getfield(gsplat, :vertexBuffer)
	uniformBuffer = getfield(gsplat, :uniformBuffer)
	indexBuffer = getfield(gsplat, :indexBuffer)
	bindingLayouts = []
	for camera in scene.cameraSystem
		append!(bindingLayouts, getBindingLayouts(camera; binding = camera.id - 1))
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
		label="[ GSPLAT RENDER PIPELINE ]"
	)
	gsplat.renderPipelines = renderPipeline
end


function getVertexBuffer(gpuDevice, gsplat::GSplat)
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

function getVertexBufferLayout(gsplat::GSplat; offset=0)
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

function getRenderPipelineOptions(renderer, splat::GSplat)
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
					],
					#:writeMask => WGPUColorWriteMask_All 
				],
			]
		]
	]
	renderpipelineOptions
end

function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, gsplat::GSplat, camIdx::Int)
	WGPUCore.setPipeline(renderPass, gsplat.renderPipelines[camIdx])
	WGPUCore.setIndexBuffer(renderPass, gsplat.indexBuffer, "Uint32")
	WGPUCore.setVertexBuffer(renderPass, 0, gsplat.vertexBuffer)
	WGPUCore.setBindGroup(renderPass, 0, gsplat.pipelineLayouts[camIdx].bindGroup, UInt32[], 0, 99)
	WGPUCore.drawIndexed(renderPass, Int32(gsplat.indexBuffer.size/sizeof(UInt32)); instanceCount = size(gsplat.splatData.points, 1), firstIndex=0, baseVertex= 0, firstInstance=0)
end

Base.show(io::IO, ::MIME"text/plain", gsplat::GSplat) = begin
	print("GSplat : $(typeof(gsplat))")
end
