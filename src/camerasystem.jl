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

function getShaderCode(camSys::CameraSystem;binding=1)
	# This will be same as camera getShaderCode but seperating it 
	# for now as placeholder for any changes
	shaderSource = quote 
		struct CameraUniform
			eye::Vec3{Float32}
			fov::Float32
			viewMatrix::Mat4{Float32}
			projMatrix::Mat4{Float32}
		end
		@var Uniform 0 $(binding) camera::CameraUniform
	end
	return shaderSource
end

function prepareObject(gpuDevice, camSys::CameraSystem)
	for camera in camSys
		prepareObject(gpuDevice, camera)
		camera.up = [0, 1, 0] .|> Float32
		camera.eye = ([0.0, 0, 4.0] .|> Float32)
		camera.fov = 1.30f0
	end
end

