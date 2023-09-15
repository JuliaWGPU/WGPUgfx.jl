export LightSystem, addLight!

struct LightSystem <: ArraySystem
	lightArray::Array{Lighting}
end

function addLight(camSys::LightSystem, light::Lighting)
	push!(camSys.lightArray, light)
	setfield!(light, :id, length(camSys.lightArray))
end

@forward  LightSystem.lightArray Base.iterate, Base.length, Base.getindex

