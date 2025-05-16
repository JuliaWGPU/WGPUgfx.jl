export CameraSystem, addCamera!

struct CameraSystem <: ArraySystem
	cameraArray::Array{Camera}
end

function addCamera!(camSys::CameraSystem, camera::Camera)
	push!(camSys.cameraArray, camera)
	setfield!(camera, :id, length(camSys.cameraArray))
end

# function addObject!(camSys::CameraSystem, obj::Renderable)
# 	for camera in camSys
# 		push!(camera.objects, deepcopy(obj))
# 	end
# end

@forward  CameraSystem.cameraArray Base.iterate, Base.length, Base.getindex

function getShaderCode(camSys::CameraSystem; binding=1)
	# Define CameraUniform structure directly in shader
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

function getShaderCodeForAllCameras(camSys::CameraSystem)
	# For multi-camera setups, generate shader code for all cameras
	# First define the structure once
	code = quote
		struct CameraUniform
			eye::Vec3{Float32}
			aspectRatio::Float32
			lookAt::Vec3{Float32}
			fov::Float32
			viewMatrix::Mat4{Float32}
			projMatrix::Mat4{Float32}
		end
	end
	
	# Then add binding for each camera
	for (idx, camera) in enumerate(camSys.cameraArray)
		push!(code.args, :(
			@var Uniform 0 $(camera.id-1) camera$(camera.id)::CameraUniform
		))
	end
	
	return code
end

function prepareObject(gpuDevice, camSys::CameraSystem)
	for camera in camSys
		prepareObject(gpuDevice, camera)
		camera.up = [0, 1, 0] .|> Float32
		camera.eye = ([0.0, 0, 4.0] .|> Float32)
		camera.fov = 1.30f0
	end
end

function preparePipeline(gpuDevice, scene, camSys::CameraSystem)
	for camera in camSys
		preparePipeline(gpuDevice, scene, camera; binding=camera.id-1)
	end
end

