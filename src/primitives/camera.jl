using WGPUCore
using LinearAlgebra
using StaticArrays
using Rotations
using CoordinateTransformations

export defaultCamera, Camera, lookAtRightHanded, perspectiveMatrix, orthographicMatrix, 
	windowingTransform, translateCamera, openglToWGSL, translate, scaleTransform,
	getUniformBuffer, getUniformData, getShaderCode


mutable struct Camera
	gpuDevice
	eye
	lookat
	up
	scale
	fov
	aspectRatio
	nearPlane
	farPlane
	uniformData
	uniformBuffer
end


function prepareObject(gpuDevice, camera::Camera)
	scale = [1, 1, 1] .|> Float32
	io = computeUniformData(camera)
	uniformDataBytes = io |> read
	seek(io, 0)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		" CAMERA BUFFER ",
		uniformDataBytes, 
		["Uniform", "CopyDst", "CopySrc"] # CopySrc during development only
	)
	setfield!(camera, :uniformData, io)
	setfield!(camera, :uniformBuffer, uniformBuffer)
	setfield!(camera, :gpuDevice, gpuDevice)
	seek(io, 0)
	return camera
end


function preparePipeline(gpuDevice, scene, camera::Camera; binding=1)
	uniformBuffer = getfield(camera, :uniformBuffer)
	push!(scene.bindingLayouts, getBindingLayouts(camera; binding=binding)...)
	push!(scene.bindings, getBindings(camera, uniformBuffer; binding=binding)...)
end


function computeTransform(camera::Camera)
	viewMatrix = lookAtRightHanded(camera) ∘ scaleTransform(camera.scale .|> Float32)
	projectionMatrix = perspectiveMatrix(camera)
	viewProject = projectionMatrix ∘ viewMatrix
	return viewProject.linear
end


function computeUniformData(camera::Camera)
	UniformType = getproperty(WGSLTypes, :CameraUniform)
	uniformData = Ref{UniformType}() # TODO only first is necessary
	io = getfield(camera, :uniformData)
	unsafe_write(io, uniformData, sizeof(uniformData))
	seek(io, 0)
	setVal!(camera, Val(:transform), computeTransform(camera))
	seek(io, 0)
	return io
end


function defaultCamera()
	eye = [1.0, 1.0, 1.0] .|> Float32
	lookat = [0, 0, 0] .|> Float32
	up = [0, 1, 0] .|> Float32
	scale = [1, 1, 1] .|> Float32
	fov = pi/2 |> Float32
	aspectRatio = 1.0 |> Float32
	nearPlane = -1.0 |> Float32
	farPlane = -100.0 |> Float32
	return Camera(
		nothing,
		eye,
		lookat,
		up,
		scale,
		fov,
		aspectRatio,
		nearPlane,
		farPlane,
		IOBuffer(),
		nothing
	)
end


function setVal!(camera::Camera, ::Val{:transform}, v)
	UniformType = getproperty(WGSLTypes, :CameraUniform)
	offset = Base.fieldoffset(UniformType, Base.fieldindex(UniformType, :transform))
	io = getfield(camera, :uniformData)
	seek(io, offset)
	write(io, v)
	seek(io, 0)
end

function setVal!(camera::Camera, ::Val{:eye}, v)
	setfield!(camera, :eye, v)
	UniformType = getproperty(WGSLTypes, :CameraUniform)
	offset = Base.fieldoffset(UniformType, Base.fieldindex(UniformType, :eye))
	io = getfield(camera, :uniformData)
	seek(io, offset)
	write(io, v)
	setVal!(camera, Val(:transform), computeTransform(camera))
	seek(io, 0)
end

function setVal!(camera::Camera, ::Val{:scale}, v)
	setfield!(camera, :scale, v)
	setVal!(camera, Val(:transform), computeTransform(camera))
end

function setVal!(camera::Camera, ::Val{:lookat}, v)
	setfield!(camera, :lookat, v)
	setVal!(camera, Val(:transform), computeTransform(camera))
end

function setVal!(camera::Camera, ::Val{:farPlane}, v)
	setfield!(camera, :farPlane, v)
	setVal!(camera, Val(:transform), computeTransform(camera))
end

function setVal!(camera::Camera, ::Val{:fov}, v)
	setfield!(camera, :fov, v)
	setVal!(camera, Val(:transform), computeTransform(camera))
end

function setVal!(camera::Camera, ::Val{:aspectRatio}, v)
	setfield!(camera, :aspectRatio, v)
	setVal!(camera, Val(:transform), computeTransform(camera))
end

function setVal!(camera::Camera, ::Val{:nearPlane}, v)
	setfield!(camera, :nearPlane, v)
	setVal!(camera, Val(:transform), computeTransform(camera))
end

function setVal!(camera::Camera, ::Val{N}, v) where N
	setfield!(camera, N, v)
end

function setVal!(camera::Camera, ::Val{:uniformData}, v)
	UniformType = getproperty(WGSLTypes, :CameraUniform)
	t = Ref{UniformType}()
	io = getfield(camera, :uniformData)
	seek(io, 0)
	unsafe_write(io, t, sizeof(t)) # TODO BUG v should be passed instead of t.
	seek(io, 0)
end

Base.setproperty!(camera::Camera, f::Symbol, v) = begin
	# setfield!(camera, f, v)
	setVal!(camera, Val(f), v)
	updateUniformBuffer(camera)
end

# TODO not working
function getVal(camera::Camera, ::Val{:unifomBuffer})
	return readUniformBuffer(camera)
end

function getVal(camera::Camera, ::Val{:transform})
	uniformData = getVal(camera, Val(:uniformData))
	return getfield(uniformData, :transform)
end

function getVal(camera::Camera, ::Val{:uniformData})
	UniformType = getproperty(WGSLTypes, :CameraUniform)
	t = Ref{UniformType}()
	io = getfield(camera, :uniformData)
	seek(io, 0)
	unsafe_read(io, t, sizeof(UniformType))
	seek(io, 0)
	t[]
end

function getVal(camera::Camera, ::Val{N}) where N
	return getfield(camera, N)
end

Base.getproperty(camera::Camera, f::Symbol) = begin
	return getVal(camera, Val(f))
end


xCoords(bb) = bb[1:2:end]
yCoords(bb) = bb[2:2:end]

lowerCoords(bb) = bb[1:2]
upperCoords(bb) = bb[3:4]


function translate(loc)
	(x, y, z) = loc
	return LinearMap(
		@SMatrix(
			[
				1 	0 	0 	x;
				0 	1 	0 	y;
				0 	0 	1 	z;
				0 	0 	0 	1;
			]
		) .|> Float32
	)
end


function scaleTransform(loc)
	(x, y, z) = loc
	return LinearMap(
		@SMatrix(
			[
				x 	0 	0 	0;
				0	y   0	0;
				0	0	z 	0;
				0	0	0	1;
			]
		) .|> Float32
	)
end


function translateCamera(camera::Camera)
	(x, y, z) = (camera.eye...,)
	return LinearMap(
		@SMatrix(
			[
				1 	0 	0 	x;
				0 	1 	0 	y;
				0 	0 	1 	z;
				0 	0 	0 	1;
			]
		) .|> Float32
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


function lookAtRightHanded(camera::Camera)
	eye = camera.eye
	lookat = camera.lookat
	up = camera.up
	w = -(eye .- lookat) |> normalize
	u =	cross(up, w) |> normalize
	v = cross(w, u)
	m = MMatrix{4, 4, Float32}(I)
	m[1:3, 1:3] .= (cat([u, v, w]..., dims=2) |> adjoint .|> Float32 |> collect)
	m = SMatrix(m)
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


function perspectiveMatrix(near::Float32, far::Float32, l::Float32, r::Float32, t::Float32, b::Float32)
	n = near
	f = far
	xS = -2*n/(r-l)
	yS = -2*n/(t-b)
	xR = -(r+l)/(r-l)
	yR = -(t+b)/(t-b)
	zR = -(f+n)/(n-f)
	oR = -2*f*n/(n-f)
	return LinearMap(
		@SMatrix(
			[
				xS		0		xR		0	;
				0		yS		yR		0	;
				0		0		zR		oR	;
				0		0		1		0	;
			]
		) .|> Float32
	)
end


function orthographicMatrix(w::Int, h::Int, near, far)
	yscale = 1/tan(fov/2)
	xscale = yscale/aspectRatio
	zn = near
	zf = far
	s = 1/(zn - zf)
	return LinearMap(
		@SMatrix(
			[
				2/w 	0      	0 		0;
				0		2/h		0		0;
				0	   	0		s		0;
				0		0		zn*s	1;
			]
		) .|> Float32
	)
end


function getUniformData(camera::Camera)
	return camera.uniformData
end


function updateUniformBuffer(camera::Camera)
	data = getfield(camera, :uniformData).data
	@info :UniformBuffer camera.uniformData.transform camera.uniformData.eye
	WGPUCore.writeBuffer(
		camera.gpuDevice.queue, 
		getfield(camera, :uniformBuffer),
		data,
	)
end


function readUniformBuffer(camera::Camera)
	data = WGPUCore.readBuffer(
		camera.gpuDevice,
		getfield(camera, :uniformBuffer),
		0,
		getfield(camera, :uniformBuffer).size
	)
	datareinterpret = reinterpret(SMatrix{4, 4, Float32, 16}, data)[1]
	@info "Received Buffer" datareinterpret
end


function getUniformBuffer(camera::Camera)
	getfield(camera, :uniformBuffer)
end


function getShaderCode(camera::Camera; isVision=false, islight=false, binding=1)
	shaderSource = quote
		struct CameraUniform
			eye::Vec3{Float32}
			transform::Mat4{Float32}
		end
		@var Uniform 0 $binding camera::@user CameraUniform
	end
	return shaderSource
end


function getVertexBufferLayout(camera::Camera; offset = 0)
	WGPUCore.GPUVertexBufferLayout => []
end


function getBindingLayouts(camera::Camera; binding=1)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end


function getBindings(camera::Camera, uniformBuffer; binding=1)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer  => uniformBuffer,
			:offset  => 0,
			:size    => uniformBuffer.size
		],
	]
end

