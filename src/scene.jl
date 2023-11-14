using WGPUNative
using WGPUCore
using Rotations
using CoordinateTransformations
using LinearAlgebra
using StaticArrays
using GeometryBasics: Mat4

export Scene, composeShader, defaultCamera, Camera, defaultCube,
	defaultPlane, Plane, Cube, Triangle3D, defaultTriangle3D,
	defaultCircle, Circle, setup, runApp, defaultLighting, Lighting,
	defaultWGPUMesh, addObject!

mutable struct Scene
	gpuDevice
	canvas
	cameraSystem::CameraSystem
	cameraId::Int					# TODO cameras
	light						# TODO lights
	objects 					# ::Union{WorldObject, ObjectGroup}
	function Scene()
		canvas = WGPUCore.getCanvas(:GLFW)
		gpuDevice = WGPUCore.getDefaultDevice();
		camera = defaultCamera()
		light = defaultLighting()
		cameraSystem = CameraSystem(Camera[])
		addCamera!(cameraSystem, camera)
		return new(gpuDevice, canvas, cameraSystem, 1, light, [])
	end
end

function Base.getproperty(scene::Scene, x::Symbol)
	if x == :camera
		return scene.cameraSystem[scene.cameraId]
	end
	getfield(scene, x)
end


# # TODO viewport dependent addObject
# function addObject!(scene, obj)
# 	push!(scene.objects, obj)
# 	# for camera in scene.cameraSystem
# 	# 	push!(scene.objects, deepcopy(obj)) # TODO just id is enough
# 	# end
# 	# setup(scene)
# end

addCamera!(scene, camera::Camera) = addCamera!(scene.cameraSystem, camera)
# addLight!(scene, light::Light) = addLight!(scene.lightSystem, light)

# setup(scene) = setup(scene.gpuDevice, scene)

# runApp(scene) = runApp(scene.gpuDevice, scene)
