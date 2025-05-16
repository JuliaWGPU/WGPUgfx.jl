using WGPUCore
using LinearAlgebra
using StaticArrays
using Rotations
using CoordinateTransformations
using Quaternions

const MAX_CAMERAS = 4
const CAMERA_BINDING_START = 0

export defaultCamera, Camera, lookAtLeftHanded, perspectiveMatrix, orthographicMatrix,
	windowingTransform, translateCamera, openglToWGSL, translate, rotateTransform, scaleTransform,
	getUniformBuffer, getUniformData, getShaderCode, updateUniformBuffer, updateViewTransform, updateProjTransform, getTransform

coordinateTransform = [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1] .|> Float32
invCoordinateTransform = inv(coordinateTransform)

@enum WGPUProjectionType ORTHO=0 PERSPECTIVE=1 # TODO add others projection types

mutable struct Camera
	gpuDevice
	eye
	lookAt
	up
	scale
	fov
	aspectRatio
	nearPlane
	farPlane
	uniformData
	uniformBuffer
	id
	projectionType
end

function prepareObject(gpuDevice, camera::Camera)
	scale = [1, 1, 1] .|> Float32
	uniformData = computeUniformData(camera)
	uniformDataBytes = uniformData |> toByteArray
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		" CAMERA $(camera.id-1) BUFFER ",
		uniformDataBytes,
		["Uniform", "CopyDst", "CopySrc"] # CopySrc during development only
	)
	setfield!(camera, :uniformData, uniformData)
	setfield!(camera, :uniformBuffer, uniformBuffer)
	setfield!(camera, :gpuDevice, gpuDevice)
	# TODO could be general design
	# TODO setting parameters that are common in CPU and GPU structures automatically
	camera.fov = camera.fov
	camera.lookAt = camera.lookAt
	camera.aspectRatio = camera.aspectRatio
	return camera
end


function preparePipeline(gpuDevice, scene, camera::Camera; binding=0)
	uniformBuffer = getfield(camera, :uniformBuffer)
	# Check if this camera's binding is already in the layout
	if !any(layout -> layout isa Pair && get(layout[2], :binding, -1) == binding, scene.bindingLayouts)
		push!(scene.bindingLayouts, getBindingLayouts(camera; binding=binding)...)
		push!(scene.bindings, getBindings(camera, uniformBuffer; binding=binding)...)
	end
end


function computeTransform(camera::Camera)
	viewMatrix = lookAtLeftHanded(camera) ∘ scaleTransform(camera.scale .|> Float32)
	# TODO should use dispatch instead
	if camera.projectionType == ORTHO
		projectionMatrix = orthographicMatrix(camera)
	elseif camera.projectionType == PERSPECTIVE
		projectionMatrix = perspectiveMatrix(camera)
	end
	return (viewMatrix.linear, projectionMatrix.linear)
end


function computeUniformData(camera::Camera)
	(viewMatrix, projMatrix) = computeTransform(camera)
	return WGPUgfx.CameraUniform(
		camera.eye,
		camera.aspectRatio,
		camera.lookAt,
		camera.fov,
		viewMatrix,
		projMatrix
	)
end


function defaultCamera(;
		id=0,
		eye = [0.0, 0.0, 3.0] .|> Float32,
		lookAt = [0, 0, 0] .|> Float32,
		up = [0, 1, 0] .|> Float32,
		scale = [1, 1, 1] .|> Float32,
		fov = (45/180)*pi |> Float32,
		aspectRatio = 1.0 |> Float32,
		nearPlane = 0.1 |> Float32,
		farPlane = 100.0 |> Float32,
		projectionType::Union{Symbol, WGPUProjectionType} = :PERSPECTIVE
	)
	projectionType = eval(projectionType) # Handles both symbol and direct Enum
	@assert projectionType in instances(WGPUProjectionType) "This projection Type is not defined"
	return Camera(
		nothing,
		eye,
		lookAt,
		up,
		scale,
		fov,
		aspectRatio,
		nearPlane,
		farPlane,
		nothing,
		nothing,
		id,
		projectionType
	)
end

Base.setproperty!(camera::Camera, f::Symbol, v) = begin
	setfield!(camera, f, v)
	if isdefined(camera, :gpuDevice) && camera.gpuDevice !== nothing && 
	   isdefined(camera, :uniformBuffer) && camera.uniformBuffer !== nothing
		# Recompute the entire uniform data
		setfield!(camera, :uniformData, computeUniformData(camera))
		updateUniformBuffer(camera)
	end
end

function updateViewTransform!(camera::Camera, transform)
	if !isdefined(camera, :uniformData) || camera.uniformData === nothing
		return
	end
	
	# Make sure transform is the right type
	try
		transform = ensureSMatrix(transform)
	catch e
		@error "Could not convert transform to SMatrix{4,4,Float32}: $(typeof(transform))" exception=e
		return
	end
	
	# Create a new uniform with the updated view matrix
	uniformData = WGPUgfx.CameraUniform(
		camera.eye,
		camera.aspectRatio,
		camera.lookAt,
		camera.fov,
		transform,
		camera.uniformData.projMatrix
	)
	setfield!(camera, :uniformData, uniformData)
	
	if isdefined(camera, :gpuDevice) && camera.gpuDevice !== nothing && 
	   isdefined(camera, :uniformBuffer) && camera.uniformBuffer !== nothing
		updateUniformBuffer(camera)
	end
end

function updateProjTransform!(camera::Camera, transform)
	if !isdefined(camera, :uniformData) || camera.uniformData === nothing
		return
	end
	
	# Make sure transform is the right type
	try
		transform = ensureSMatrix(transform)
	catch e
		@error "Could not convert transform to SMatrix{4,4,Float32}: $(typeof(transform))" exception=e
		return
	end
	
	# Create a new uniform with the updated projection matrix
	uniformData = WGPUgfx.CameraUniform(
		camera.eye,
		camera.aspectRatio,
		camera.lookAt,
		camera.fov,
		camera.uniformData.viewMatrix,
		transform
	)
	setfield!(camera, :uniformData, uniformData)
	
	if isdefined(camera, :gpuDevice) && camera.gpuDevice !== nothing && 
	   isdefined(camera, :uniformBuffer) && camera.uniformBuffer !== nothing
		updateUniformBuffer(camera)
	end
end

function getViewTransform(camera::Camera)
	uniformData = camera.uniformData
	return uniformData.viewMatrix
end

function getProjTransform(camera::Camera)
	uniformData = camera.uniformData
	return uniformData.projMatrix
end


xCoords(bb) = bb[1:2:end]
yCoords(bb) = bb[2:2:end]


lowerCoords(bb) = bb[1:2]
upperCoords(bb) = bb[3:4]


function rotmatrix_from_quat(q::Quaternion)
    sx, sy, sz = 2q.s * q.v1, 2q.s * q.v2, 2q.s * q.v3
    xx, xy, xz = 2q.v1^2, 2q.v1 * q.v2, 2q.v1 * q.v3
    yy, yz, zz = 2q.v2^2, 2q.v2 * q.v3, 2q.v3^2
    r = [1 - (yy + zz)     xy - sz     xz + sy;
            xy + sz   1 - (xx + zz)    yz - sx;
            xz - sy      yz + sx  1 - (xx + yy)]
    return r
end


function translate(loc)
	# Handle different input types
	if length(loc) >= 3
		x = Float32(loc[1])
		y = Float32(loc[2])
		z = Float32(loc[3])
	elseif length(loc) == 2
		x = Float32(loc[1])
		y = Float32(loc[2])
		z = 0.0f0
	else
		error("translate: location must have at least 2 components")
	end
	
	mat = coordinateTransform*[
		1 	0 	0 	x;
		0 	1 	0 	y;
		0 	0 	1 	z;
		0 	0 	0 	1;
	]

	return LinearMap(
		convertMatrixToSMatrix(mat)
	)
end


function rotateTransform(q::Quaternion)
	rotMat = coordinateTransform[1:3, 1:3]*rotmatrix_from_quat(q)
	mat = Matrix{Float32}(I, (4, 4))
	mat[1:3, 1:3] .= rotMat
	return LinearMap(
		convertMatrixToSMatrix(mat)
	)
end


function scaleTransform(loc)
	(x, y, z) = coordinateTransform[1:3, 1:3]*loc
	mat = [
		x 	0 	0 	0;
		0	y   0	0;
		0	0	z 	0;
		0	0	0	1;
	]
	return LinearMap(
		convertMatrixToSMatrix(mat)
	)
end


function translateCamera(camera::Camera)
	(x, y, z) = coordinateTransform[1:3, 1:3]*camera.eye
	mat = [
		1 	0 	0 	x;
		0 	1 	0 	y;
		0 	0 	1 	z;
		0 	0 	0 	1;
	]
	return LinearMap(
		convertMatrixToSMatrix(mat)
	) |> inv
end


function computeScaleFromBB(bb1, bb2)
	scaleX = reduce(-, xCoords(bb2))./reduce(-, xCoords(bb1))
	scaleY = reduce(-, yCoords(bb2))./reduce(-, yCoords(bb1))
	scaleZ = 1
	return LinearMap(@SMatrix([scaleX 0 0 0; 0 scaleY 0 0; 0 0 scaleZ 0; 0 0 0 1]))
end


function windowingTransform(fromSize, toSize)
	trans1 = Translation([-lowerCoords(fromSize)..., 0, 0])
	trans2 = Translation([lowerCoords(toSize)..., 0, 0])
	scale = computeScaleFromBB(fromSize, toSize)
	return trans2 ∘ scale ∘ trans1
end


"""
# Usage
bb1 = [20, 20, 400, 400]
bb2 = [40, 60, 500, 600]

transform = windowingTransform(bb1, bb2)

transform([upperCoords(bb1)..., 0, 0])

# Should write tests on it
"""


function lookAtLeftHanded(camera::Camera)
	eye = camera.eye
	lookAt = camera.lookAt
	up = camera.up
	w = ((lookAt .- eye) |> normalize)
	u =	cross(up, w) |> normalize
	v = cross(w, u)
	m = MMatrix{4, 4, Float32}(I)
	m[1:3, 1:3] .= coordinateTransform[1:3, 1:3]*(cat([u, v, w]..., dims=2) |> adjoint .|> Float32 |> collect)
	m = convertMatrixToSMatrix(m)
	return LinearMap(m) ∘ translateCamera(camera)
end


function perspectiveMatrix(camera::Camera)
	fov = camera.fov
	ar = camera.aspectRatio
	n = camera.nearPlane
	f = camera.farPlane
	t = n*tan(fov/2)
	b = -t
	r = ar*t
	l = -r
	return perspectiveMatrix(((n, f, l, r, t, b) .|> Float32)...)
end

function orthographicMatrix(camera::Camera)
	n = camera.nearPlane
	f = camera.farPlane
	t = n*tan(fov/2)
	b = -t
	r = ar*t
	l = -r
	return orthographicMatrix(t-b, r-l, n, f)
end


function perspectiveMatrix(near::Float32, far::Float32, l::Float32, r::Float32, t::Float32, b::Float32)
	n = near
	f = far
	xS = 2*n/(r-l) # r-l is width
	yS = 2*n/(t-b) # (t-b) is height
	xR = (r+l)/(r-l)
	yR = (t+b)/(t-b)
	zR = (f+n)/(f-n)
	oR = -2*f*n/(f-n)
	pmat = coordinateTransform * [
		xS		0		0		0	;
		0		yS		0		0	;
		0		0		zR		oR	;
		0		0		1		0	;
	]

	return LinearMap(
		convertMatrixToSMatrix(pmat)
	)
end


function orthographicMatrix(w::Int, h::Int, near, far)
	yscale = 1/tan(fov/2)
	xscale = yscale/aspectRatio
	zn = near
	zf = far
	s = 1/(zn - zf)
	mat = [
		2/w 	0      	0 		0;
		0		2/h		0		0;
		0	   	0		s		0;
		0		0		zn*s	1;
	]
	return LinearMap(
		convertMatrixToSMatrix(mat)
	)
end


function getUniformData(camera::Camera)
	return camera.uniformData
end


function updateUniformBuffer(camera::Camera)
	if !isdefined(camera, :uniformData) || camera.uniformData === nothing ||
	   !isdefined(camera, :gpuDevice) || camera.gpuDevice === nothing ||
	   !isdefined(camera, :uniformBuffer) || camera.uniformBuffer === nothing
		return
	end
	
	try
		uniformData = getfield(camera, :uniformData)
		data = reinterpret(UInt8, [uniformData]) |> collect
		WGPUCore.writeBuffer(
			camera.gpuDevice.queue,
			getfield(camera, :uniformBuffer),
			data,
		)
	catch e
		@error "Failed to update uniform buffer" exception=e
	end
end


function readUniformBuffer(camera::Camera)
	if !isdefined(camera, :gpuDevice) || camera.gpuDevice === nothing ||
	   !isdefined(camera, :uniformBuffer) || camera.uniformBuffer === nothing
		@warn "Cannot read uniform buffer: device or buffer not initialized"
		return nothing
	end
	
	try
		data = WGPUCore.readBuffer(
			camera.gpuDevice,
			getfield(camera, :uniformBuffer),
			0,
			getfield(camera, :uniformBuffer).size
		)
		datareinterpret = reinterpret(WGPUgfx.CameraUniform, data)[1]
		return datareinterpret
	catch e
		@error "Failed to read uniform buffer" exception=e
		return nothing
	end
end


function getUniformBuffer(camera::Camera)
	getfield(camera, :uniformBuffer)
end


function getShaderCode(camera::Camera; binding=CAMERA_BINDING_START)
	shaderSource = quote
		struct CameraUniform
		    eye::Vec3{Float32}
		    aspectRatio::Float32
		    lookAt::Vec3{Float32}
		    fov::Float32
		    viewMatrix::Mat4{Float32}
		    projMatrix::Mat4{Float32}
		end
		@var Uniform 0 $(binding) camera::CameraUniform
	end
	return shaderSource
end


function getVertexBufferLayout(camera::Camera; offset = 0)
	WGPUCore.GPUVertexBufferLayout => []
end


function getBindingLayouts(camera::Camera; binding=CAMERA_BINDING_START)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end


function getBindings(camera::Camera, uniformBuffer; binding=CAMERA_BINDING_START)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer  => uniformBuffer,
			:offset  => 0,
			:size    => uniformBuffer.size
		],
	]
end
