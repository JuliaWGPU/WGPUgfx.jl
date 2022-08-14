
using GeometryBasics: Vec2, Vec4, Vec3, Mat
using LinearAlgebra
using StaticArrays
using Rotations
using CoordinateTransformations

export defaultCamera, Camera

xCoords(bb) = bb[1:2:end]
yCoords(bb) = bb[2:2:end]

lowerCoords(bb) = bb[1:2]
upperCoords(bb) = bb[3:4]


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

function lookAtRightHanded(eye, center, up)
	z = normalize(eye-center)
	x =	cross(up, z) |> normalize
	y = cross(z, x) |> normalize
	m = Matrix{Float32}(I, (4, 4))
	m[1:3, 1:3] .= (cat([x, y, z]..., dims=2) .|> Float32 |> collect)
	return m
end


function perspectiveMatrix(fov::Float32, aspectRatio::Float32, near, far)
	yscale = 1/tan(fov/2)
	xscale = yscale/aspectRatio
	zn = near
	zf = far
	s = zf/(zn - zf)
	t =
	return LinearMap(
		@SMatrix(
			[
				xscale	0      	0 		0;
				0		yscale	0		0;
				0	   	0		s		-1;
				0		0		zn*s	0;
			]
		)
	)
end


function perspectiveMatrix(w::Int, h::Int, near, far)
	yscale = 1/tan(fov/2)
	xscale = yscale/aspectRatio
	zn = near
	zf = far
	s = zf/(zn - zf)
	t =
	return LinearMap(
		@SMatrix(
			[
				2*zn/w 	0      	0 		0;
				0		2*zn/h	0		0;
				0	   	0		s		-1;
				0		0		zn*s	0;
			]
		)
	)
end


function orthographicMatrix(w::Int, h::Int, near, far)
	yscale = 1/tan(fov/2)
	xscale = yscale/aspectRatio
	zn = near
	zf = far
	s = 1/(zn - zf)
	t =
	return LinearMap(
		@SMatrix(
			[
				2*w 	0      	0 		0;
				0		2/h		0		0;
				0	   	0		s		0;
				0		0		zn*s	1;
			]
		)
	)
end


struct Camera
	position
	orientation
end

function defaultCamera()
	position = [1, 0, 0, 0] .|> Float32
	orientation = [-1, 0, 0, 0] .|> Float32
	return Camera(
		position,
		orientation
	)
end


function defaultUniformData(::Type{Camera}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

function getUniformData(camera::Camera)
	return defaultUniformData(Camera)
end

function getUniformBuffer(gpuDevice, camera::Camera)
	uniformData = defaultUniformData(Camera)
	(uniformBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"uniformBuffer", 
		uniformData, 
		["Uniform", "CopyDst"]
	)
	uniformBuffer
end


function getShaderCode(::Type{Camera})
	shaderSource = quote
		struct CameraUniform
			transform::Mat4{Float32}
		end

		@var Uniform 0 1 camera::@user CameraUniform
		
	end
	return shaderSource
end


function getVertexBufferLayout(::Type{Camera})
	WGPU.GPUVertexBufferLayout => []
end

function getBindingLayouts(::Type{Camera})
	return []
end

function getBindings(::Type{Camera}, buffers)
	return []
end

