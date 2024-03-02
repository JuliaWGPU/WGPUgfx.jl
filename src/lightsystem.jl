export LightSystem, addLight!

struct LightSystem <: ArraySystem
	lightArray::Array{Lighting}
end

function addLight(lightSys::LightSystem, light::Lighting)
	push!(lightSys.lightArray, light)
	setfield!(light, :id, length(lightSys.lightArray))
end

@forward  LightSystem.lightArray Base.iterate, Base.length, Base.getindex

function getShaderCode(lightSystem::LightSystem)
	lightUniform = Symbol(:LightingUniform, light.id-1)
	lightVar = Symbol(:light, light.id-1)
	shaderSource = quote end
	for light in lightSystem
		push!(
			shaderSource, 
			quote
				struct $lightUniform
					eye::Vec3{Float32}
					transform::Mat4{Float32}
				end
				@var Uniform 0 $(light.id-1) $lightVar::$lightUniform
			end
		)
	end
	return shaderSource
end
