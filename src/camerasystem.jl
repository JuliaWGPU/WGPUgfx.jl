export CameraSystem, addCamera!

struct CameraSystem <: ArraySystem
	cameraArray::Array{Camera}
end

function addCamera!(camSys::CameraSystem, camera::Camera)
	push!(camSys.cameraArray, camera)
	setfield!(camera, :id, length(camSys.cameraArray))
end

@forward  CameraSystem.cameraArray Base.iterate, Base.length, Base.getindex

