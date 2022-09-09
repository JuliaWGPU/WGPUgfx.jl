using WGPU
using LinearAlgebra
using StaticArrays
using Rotations
using CoordinateTransformations

export defaultVision, Vision, lookAtRightHanded, perspectiveMatrix, orthographicMatrix,
	windowingTransform, translateVision, openglToWGSL, scaleTransform,
	getUniformBuffer, getUniformData, getShaderCode

mutable struct Vision
	gpuDevice
	lefteye::Union{Nothing, Camera}
	righteye::Union{Nothing, Camera}		
	ipd 									# interpupilary distance
	eye										
	lookat
	up
	scale
	fov
	aspectRatio
	nearPlane
	farPlane
	transform
	uniformData
	uniformBuffer
end


function prepareObject(gpuDevice, vision::Vision)
	setfield!(vision, :lefteye, defaultCamera())
	setfield!(vision, :righteye, defaultCamera())
	prepareObject(gpuDevice, vision.lefteye)
	prepareObject(gpuDevice, vision.righteye)
	setfield!(vision, :uniformBuffer, [
		getfield(getfield(vision, :lefteye), :uniformBuffer),
		getfield(getfield(vision, :righteye), :uniformBuffer)
	])
	setVal!(vision, Val(:transform), computeTransform(vision))
end


# TODO should think about binding here
function preparePipeline(gpuDevice, scene, vision::Vision; binding=1)
	# uniformBuffer = getfield(camera, :uniformBuffer)
	# push!(scene.bindingLayouts, getBindingLayouts(camera; binding=binding)...)
	# push!(scene.bindings, getBindingLayouts(camera, uniformBuffer; binding=binding)...)
	preparePipeline(gpuDevice, scene, vision.lefteye; binding=1)
	preparePipeline(gpuDevice, scene, vision.righteye; binding=2)
end

# TODO this is copy of camera version (refactor)


function internalTx(x, y, z) 
	LinearMap(
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

function translateVision(vision::Vision)
	(x, y, z) = (vision.eye...,)
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

# TODO this is copy of Camera version (refactor)
function lookAtRightHanded(vision::Vision)
	eye = vision.eye
	lookat = vision.lookat
	up = vision.up
	w = -(eye .- lookat) |> normalize
	u =	cross(up, w) |> normalize
	v = cross(w, u)
	m = MMatrix{4, 4, Float32}(I)
	m[1:3, 1:3] .= (cat([u, v, w]..., dims=2) |> adjoint .|> Float32 |> collect)
	m = SMatrix(m)
	return LinearMap(m) ∘ translateVision(vision)
end



function computeTransform(vision::Vision)
	viewMatrix = lookAtRightHanded(vision) ∘ scaleTransform(vision.scale .|> Float32)
	return viewMatrix.linear
end


function defaultVision()
	ipd = 0.3f0
	eye = [1, 1, 1] .|> Float32
	lefteye = nothing
	righteye = nothing
	lookat = [0, 0, 0] .|> Float32
	up = [0, 1, 0] .|> Float32
	scale = [1, 1, 1] .|> Float32
	fov = pi/2 |> Float32
	aspectRatio = 1.0 |> Float32
	nearPlane = -1.0 |> Float32
	farPlane = -100.0 |> Float32
	return Vision(
		nothing,
		lefteye,
		righteye,
		ipd,
		eye,
		lookat,
		up,
		scale,
		fov,
		aspectRatio,
		nearPlane,
		farPlane,
		nothing,
		nothing, 
		nothing
	)
end


function setVal!(vision::Vision, ::Val{:transform}, v)
	setfield!(vision, :transform, v)
	leftTransform = compose(LinearMap(v), internalTx(-vision.ipd, 0.0f0, 0.0f0)) 
	rightTransform = compose(LinearMap(v), internalTx(+vision.ipd, 0.0f0, 0.0f0)) 
	vision.lefteye.transform = leftTransform.linear
	vision.righteye.transform = rightTransform.linear
end

function setVal!(vision::Vision, ::Val{:eye}, v)
	setfield!(vision, :eye, v)
	setVal!(vision.lefteye, Val(:eye), [v[1] - vision.ipd/2, v[2:end]...] .|> Float32)
	setVal!(vision.righteye, Val(:eye), [v[1] + vision.ipd/2, v[2:end]...] .|> Float32)
end

function setVal!(vision::Vision, ::Val{:lefteye}, v)
	setVal!(vision.lefteye, Val(:eye), v)
end

function setVal!(vision::Vision, ::Val{:righteye}, v)
	setVal!(vision.righteye, Val(:eye), v)
end

# TODO should think about scale
function setVal!(vision::Vision, ::Val{:scale}, v)
	setfield!(vision, :scale, v)
	setVal!(vision.lefteye, Val(:scale), v)
	setVal!(vision.righteye, Val(:scale), v)
end

# TODO
# function setVal!(vision::Vision, ::Val{:scale}, v<:Number)
	# v = Vec3(I.*v)
	# setfield!(vision, :scale, v)
	# setVal!(vision.lefteye, Val(:scale), v)
	# setVal!(vision.righteye, Val(:scale), v)
# end


function setVal!(vision::Vision, ::Val{:lookat}, v)
	setfield!(vision, :lookat, v)
	setVal!(vision.lefteye, Val(:lookat), v)
	setVal!(vision.righteye, Val(:lookat), v)
end


function setVal!(vision::Vision, ::Val{:farPlane}, v)
	setfield!(vision, :farPlane, v)
	setVal!(vision.lefteye, Val(:farPlane), v)
	setVal!(vision.righteye, Val(:farPlane), v)
end


function setVal!(vision::Vision, ::Val{:fov}, v)
	setfield!(vision, :fov, v)
	setVal!(vision.lefteye, Val(:fov), v)
	setVal!(vision.righteye, Val(:fov), v)
end


function setVal!(vision::Vision, ::Val{:aspectRatio}, v)
	setfield!(vision, :aspectRatio, v)
	setVal!(vision.lefteye, Val(:aspectRatio), v)
	setVal!(vision.righteye, Val(:aspectRatio), v)
end


function setVal!(vision::Vision, ::Val{:nearPlane}, v)
	setfield!(vision, :nearPlane, v)
	setVal!(vision.lefteye, Val(:nearPlane), v)
	setVal!(vision.righteye, Val(:nearPlane), v)
end


function setVal!(vision::Vision, ::Val{N}, v) where N
	setfield!(vision, N, v)
	setfield!(vision.lefteye, N, v)
	setfield!(vision.righteye, N, v)
end


# TODO 
function setVal!(vision::Vision, ::Val{:uniformData}, v)
	# TODO for now lets just assume that v is a list of uniformData for
	# lefteye and righteye
	setVal!(vision.lefteye, Val(:uniformData), v[1])
	setVal!(vision.righteye, Val(:uniformData), v[2])
end


Base.setproperty!(vision::Vision, f::Symbol, v) = begin
	# setfield!(vision, f, v)
	# TODO check if the field is in appropriate symbols
	setVal!(vision, Val(f), v)
	updateUniformBuffer(vision.lefteye)
	updateUniformBuffer(vision.righteye)
end


# TODO not working
function getVal(vision::Vision, ::Val{:unifomBuffer})
	return [
		readUniformBuffer(vision.lefteye),
		readUniformBuffer(vision.righteye)
	]
end


function getVal(vision::Vision, ::Val{:transform})
	getfield(vision, :transform)
end


function getVal(vision::Vision, ::Val{:uniformData})
	[
		getVal(vision.lefteye, Val(:uniformData)),
		getVal(vision.righteye, Val(:uniformData))
	]
end


function getVal(vision::Vision, ::Val{N}) where N
	return getfield(vision, N)
end


Base.getproperty(vision::Vision, f::Symbol) = begin
	return getVal(vision, Val(f))
end


function getShaderCode(vision::Vision; isVision=true, islight=false, binding=1)
	shaderSource = quote
		struct CameraUniform
			eye::Vec3{Float32}
			transform::Mat4{Float32}
		end
		@var Uniform 0 $binding lefteye::@user CameraUniform
		@var Uniform 0 $(binding+1) righteye::@user CameraUniform
	end
	return shaderSource
end


function getVertexBufferLayout(vision::Vision; offset = 0)
	WGPU.GPUVertexBufferLayout => []
end


function getBindingLayouts(vision::Vision; binding=1)
	bindingLayouts = [
		WGPU.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
		WGPU.WGPUBufferEntry => [
			:binding => binding + 1,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end


function getBindings(vision::Vision, uniformBuffer; binding=1)
	bindings = [
		WGPU.GPUBuffer => [
			:binding => binding,
			:buffer  => uniformBuffer[1],
			:offset  => 0,
			:size    => uniformBuffer[1].size
		],
		WGPU.GPUBuffer => [
			:binding => binding + 1,
			:buffer  => uniformBuffer[2],
			:offset  => 0,
			:size    => uniformBuffer[2].size
		],
	]
end

