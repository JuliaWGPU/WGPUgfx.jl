using WGPUCore
using WGPUgfx
using LinearAlgebra
using StaticArrays
using Rotations
using CoordinateTransformations

const LIGHT_BINDING_START = MAX_CAMERAS + 1
const MAX_LIGHTS = 4

export defaultLighting, Lighting, lookAtRightHanded, 
	translateLighting, translate, scaleTransform,
	getUniformBuffer, getUniformData


mutable struct Lighting
	gpuDevice
	position
	specularColor
	ambientIntensity
	diffuseIntensity
	specularIntensity
	specularShininess
	uniformData
	uniformBuffer
end


function prepareObject(gpuDevice, lighting::Lighting)
	uniformData = computeUniformData(lighting)
	uniformDataBytes = toByteArray(uniformData)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"LightingBuffer",
		uniformDataBytes,
		["Uniform", "CopyDst", "CopySrc"] # CopySrc during development only
	)
	setfield!(lighting, :uniformData, uniformData)
	setfield!(lighting, :uniformBuffer, uniformBuffer)
	setfield!(lighting, :gpuDevice, gpuDevice)
	return lighting
end

function preparePipeline(gpuDevice, scene, light::Lighting; binding=LIGHT_BINDING_START)
	uniformBuffer = getfield(light, :uniformBuffer)
	push!(scene.bindingLayouts, getBindingLayouts(light; binding=binding)...)
	push!(scene.bindings, getBindings(light, uniformBuffer; binding=binding)...)
end

# TODO not used
function defaultUniformData(::Lighting) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end


function computeUniformData(lighting::Lighting)
	return WGPUgfx.LightingUniform(
		lighting.position,
		lighting.specularColor,
		lighting.ambientIntensity,
		lighting.diffuseIntensity,
		lighting.specularIntensity,
		lighting.specularShininess
	)
end


function defaultLighting()
	position = [2.0, 2.0, 2.0, 1.0] .|> Float32
	specularColor = [1.0, 1.0, 1.0, 1.0] .|> Float32
	ambientIntensity = 0.9 |> Float32
	diffuseIntensity = 0.5 |> Float32
	specularIntensity = 0.2 |> Float32
	specularShininess = 0.2 |> Float32
	return Lighting(
		nothing,
		position,
		specularColor,
		ambientIntensity,
		diffuseIntensity,
		specularIntensity,
		specularShininess,
		nothing,
		nothing
	)
end

Base.setproperty!(lighting::Lighting, f::Symbol, v) = begin
	setfield!(lighting, f, v)
	if lighting.gpuDevice !== nothing && lighting.uniformBuffer !== nothing
		# Recompute the entire uniform data
		setfield!(lighting, :uniformData, computeUniformData(lighting))
		updateUniformBuffer(lighting)
	end
end


Base.getproperty(lighting::Lighting, f::Symbol) = begin
	getfield(lighting, f)
end


function translateLighting(lighting::Lighting)
	(x, y, z) = (lighting.eye...,)
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


"""
# Usage
bb1 = [20, 20, 400, 400]
bb2 = [40, 60, 500, 600]

transform = windowingTransform(bb1, bb2)

transform([upperCoords(bb1)..., 0, 0])

# Should write tests on it
"""


function lookAtRightHanded(lighting::Lighting)
	eye = lighting.eye
	lookAt = lighting.lookAt
	up = lighting.up
	w = -(eye .- lookAt) |> normalize
	u =	cross(up, w) |> normalize
	v = cross(w, u)
	m = Matrix{Float32}(I, (4, 4))
	m[1:3, 1:3] .= (cat([u, v, w]..., dims=2) |> adjoint .|> Float32 |> collect)
	return LinearMap(m) ∘ translateLighting(lighting)
end


function getUniformData(lighting::Lighting)
	return lighting.uniformData
end


function updateUniformBuffer(lighting::Lighting)
	uniformData = getfield(lighting, :uniformData)
	data = toByteArray(uniformData)
	WGPUCore.writeBuffer(
		lighting.gpuDevice.queue, 
		getfield(lighting, :uniformBuffer),
		data,
	)
end


function readUniformBuffer(lighting::Lighting)
	data = WGPUCore.readBuffer(
		lighting.gpuDevice,
		getfield(lighting, :uniformBuffer),
		0,
		getfield(lighting, :uniformBuffer).size
	)
	datareinterpret = reinterpret(WGPUgfx.LightingUniform, data)[1]
	return datareinterpret
end


function getUniformBuffer(lighting::Lighting)
	getfield(lighting, :uniformBuffer)
end


function getShaderCode(lighting::Lighting; binding=LIGHT_BINDING_START)
	shaderSource = quote
		struct LightingUniform
			position::Vec4{Float32}
			specularColor::Vec4{Float32}
			ambientIntensity::Float32
			diffuseIntensity::Float32
			specularIntensity::Float32
			specularShininess::Float32
		end
		@var Uniform 0 $binding lighting::LightingUniform
	end
	return shaderSource
end


function getVertexBufferLayout(lighting::Lighting; offset=0)
	WGPUCore.GPUVertexBufferLayout => []
end


function getBindingLayouts(lighting::Lighting; binding=LIGHT_BINDING_START)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end


function getBindings(lighting::Lighting, uniformBuffer; binding=LIGHT_BINDING_START)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer  => uniformBuffer,
			:offset  => 0,
			:size    => uniformBuffer.size
		],
	]
end

