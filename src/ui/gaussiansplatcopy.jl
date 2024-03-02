
using PlyIO

export GaussianSplat, defaultGaussianSplat

mutable struct GaussianSplatData
	points
	scale
	sphericalHarmonics
	quaternions
	opacity
	features
end

mutable struct GaussianSplat <: Renderable
	gpuDevice
    topology
	splatData::GaussianSplatData
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

function readPlyFileGaussian(path)
	plyData = PlyIO.load_ply(path);
	vertexElement = plyData["vertex"]
	sh = cat(map((x) -> getindex(vertexElement, x), ["f_dc_0", "f_dc_1", "f_dc_2"])..., dims=2)
	scale = cat(map((x) -> getindex(vertexElement, x), ["scale_0", "scale_1", "scale_2"])..., dims=2)
	# normals = cat(map((x) -> getindex(vertexElement, x), ["nx", "ny", "nz"])..., dims=2)
	points = cat(map((x) -> getindex(vertexElement, x), ["x", "y", "z"])..., dims=2)
	quaternions = cat(map((x) -> getindex(vertexElement, x), ["rot_0", "rot_1", "rot_2", "rot_3"])..., dims=2)
	features = cat(map((x) -> getindex(vertexElement, x), ["f_rest_$i" for i in 0:44])..., dims=2)
	opacity = vertexElement["opacity"]
	splatData = GaussianSplatData(points, scale, sh, quaternions, opacity, features) 
	return splatData
end

function defaultGaussianSplat(path::String; color=[0.2, 0.9, 0.0, 1.0], scale::Union{Vector{Float32}, Float32} = 1.0f0)

	if typeof(scale) == Float32
		scale = [scale.*ones(Float32, 3)..., 1.0f0] |> diagm
	else
		scale = scale |> diagm
	end

	swapMat = [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1] .|> Float32;
	# swapMat = [1 0 0 0; 0 0 -1 0; 0 1 0 0; 0 0 0 1] .|> Float32;

    splatData = readPlyFileGaussian(path);  # TODO remove 

	vertices = cat(splatData.points, ones(size(splatData.points, 1)), dims=2) |> adjoint |> collect .|> Float32;

	vertexData = scale*swapMat*vertices[:, 1:min(size(vertices, 2), 268435456/4 |> Int)]

	unitColor = cat([
		color,
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, size(vertices, 2)))

	indexData = cat([
		(1:length(vertices)) |> collect,
	]..., dims=2) .|> UInt32
	
	box = GaussianSplat(
		nothing, 		# gpuDevice
		"PointList",
		splatData,
		vertexData, 
		colorData, 
		indexData, 
		nothing,
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


function getShaderCode(gsplat::GaussianSplat, cameraId::Int; binding=0)
	name = Symbol(typeof(gsplat), binding)
	renderableType = typeof(gsplat)
	renderableUniform = Symbol(renderableType, :Uniform)

	# Following https://arxiv.org/pdf/2312.02121.pdf

	shaderSource = quote

		function scaleMatrix(s::Vec3{Float32})::Mat4{Float32}
			return Mat4{Float32}(
				s.x, 0.0, 0.0, 0.0,
				0.0, s.y, 0.0, 0.0,
				0.0, 0.0, s.z, 0.0,
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
			@let x = q.x
			@let y = q.y
			@let z = q.z
			@let w = q.w
			return Mat4{Float32}(
				1.0 - 2.0*(y*y + z*z), 2.0*(x*y - w*z), 2.0*(x*z + w*y), 0.0,
				2.0*(x*y + w*z), 1.0 - 2.0*(x*x - z*z), 2.0*(y*z - w*x), 0.0, 
				2.0*(x*z - w*z), 2.0*(y*z + w*x), 1.0 - 2.0*(x*x + y*y), 0.0,
				0.0, 0.0, 0.0, 1.0
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

		struct GSplatIn
			@location 0 gpos::Vec4{Float32}
			@location 1 gscale::Vec3{Float32}
			@location 2 opacity::Float32
			@location 3 quaternions::Vec4{Float32}
			@location 4 sh::Vec3{Float32}
		end

		# Matrices are not allowed ...
		struct GSplatOut
			@builtin position pos::Vec4{Float32}
			@location 0 vColor::Vec4{Float32}
			@location 1 vCov2d::Vec4{Float32}
			@location 2 vOpacity::Float32
		end

		struct $renderableUniform
			transform::Mat4{Float32}
		end

		@var Uniform 0 $binding $name::$renderableUniform

		@vertex function vs_main(vertexIn::GSplatIn)::GSplatOut
			@var out::GSplatOut
			@let R::Mat4{Float32} = quatToRotMat(vertexIn.quaternions)
			@let S::Mat4{Float32} = scaleMatrix(vertexIn.gscale)
			@let M = R*S
			@let sigma = M*transpose(M)
			@let ortho = orthoMatrix(camera)
			out.pos = $(name).transform*vertexIn.gpos
			@let tx = out.pos.x 
			@let ty = out.pos.y
			@let tz = out.pos.z
			out.pos = camera.transform*out.pos
			# out.pos = ortho*out.pos
			@let f::Float32 = 2.0*(tan(camera.fov/2.0))

			@let J = SMatrix{2, 4, Float32, 8}(
				f/tz, 0.0, -f*tx/(tz*tz), 0.0,
				0.0, f/tz, -f*ty/(tz*tz), 0.0,
			)

			@let Rcam = transToRotMat(camera.transform)
			@let W = Rcam*J
			@let cov4D = transpose(W)*(sigma*W)
			@let d = SMatrix{2, 2, Float32, 4}(
				1.0, 1.0,
				1.0, 1.0,
			)
			@let cov2D = Vec4{Float32}(
				cov4D[0][0], cov4D[0][1],
				cov4D[1][0], cov4D[1][1],
			)

			# @let dir = normalize(out.pos - Vec4{Float32}(camera.eye, 1.0));
			@let SH_C0 = 0.28209479177387814;
			@var result = SH_C0 * vertexIn.sh;
			out.vCov2d = cov2D
			out.vOpacity = vertexIn.opacity
			out.vColor = Vec4{Float32}(result, out.vOpacity)
			return out
		end

		@fragment function fs_main(fragmentIn::GSplatOut)::@location 0 Vec4{Float32}
			@let cov2d = Mat2{Float32}(
				fragmentIn.vCov2d[0],
				fragmentIn.vCov2d[1],
				fragmentIn.vCov2d[2],
				fragmentIn.vCov2d[3],
			)
			@let delta = Vec2{Float32}(10.0, 10.0)
			@let invCov2dAdj = Mat2{Float32}(
				cov2d[1][1], -cov2d[0][1],
				-cov2d[1][0], cov2d[0][0]
			)
			@let det::Float32 = determinant(invCov2dAdj)
			@let invCov2d::Mat2{Float32} = Mat2{Float32}(
				invCov2dAdj[0][0]/det,
				invCov2dAdj[0][1]/det,
				invCov2dAdj[1][0]/det,
				invCov2dAdj[1][1]/det,
			)
			@let intensity = dot(delta*invCov2d, delta)

			@let color::Vec4{Float32} = fragmentIn.vColor
			return color
		end
	end
	return shaderSource
end

function prepareObject(gpuDevice, gsplat::GaussianSplat)
	uniformData = computeUniformData(gsplat)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"Mesh Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(gsplat, :uniformData, uniformData)
	setfield!(gsplat, :uniformBuffer, uniformBuffer)
	setfield!(gsplat, :gpuDevice, gpuDevice)
	setfield!(gsplat, :indexBuffer, getIndexBuffer(gpuDevice, gsplat))
	setfield!(gsplat, :vertexBuffer, getVertexBuffer(gpuDevice, gsplat))
end

function preparePipeline(gpuDevice, renderer, gsplat::GaussianSplat)
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
		"PipeLineLayout", 
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
		label=" MESH RENDER PIPELINE "
	)
	gsplat.renderPipelines = renderPipeline
end


function getVertexBuffer(gpuDevice, gsplat::GaussianSplat)
	splatData = gsplat.splatData
	data = [
		gsplat.vertexData,
		splatData.scale .|> Float32 |> adjoint,
		splatData.opacity .|> Float32 |> adjoint,
		splatData.quaternions  .|> Float32 |> adjoint,
		splatData.sphericalHarmonics .|> Float32 |> adjoint
	]

	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"vertexBuffer",
		vcat(data...),
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end

function getVertexBufferLayout(gsplat::GaussianSplat; offset=0)
	WGPUCore.GPUVertexBufferLayout => [
		:arrayStride => 15*4,
		:stepMode => "Vertex",
		:attributes => [
			:attribute => [
				:format => "Float32x4",
				:offset => 0,
				:shaderLocation => offset + 0
			],
			:attribute => [
				:format => "Float32x3",
				:offset => 4*4,
				:shaderLocation => offset + 1
			],
			:attribute => [
				:format => "Float32",
				:offset => 7*4,
				:shaderLocation => offset + 2
			],
			:attribute => [
				:format => "Float32x4",
				:offset => 8*4,
				:shaderLocation => offset + 3
			],
			:attribute => [
				:format => "Float32x3",
				:offset => 12*4,
				:shaderLocation => offset + 4
			]
		]
	]
end

