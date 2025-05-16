# WIP
# This example showcases a 2D quad rendering on top of 3D render scene.
# This will allow GUI interaction with GUI elements like textboxes etc ...
# Currently it draws only the Quad with transparency since we need transparency for Text only fields.
# Fully function example should render text and stay at a place with interaction possibilty. 
# TODOMore dynamic 3D environment will be more evident for showcasing purposes.

# import Pkg
# Pkg.add([
# 	"WGPUgfx", 
# 	"WGPUCore", 
# 	"WGPUCanvas", 
# 	"GLFW", 
# 	"Rotations", 
# 	"StaticArrays", 
# 	"WGPUNative", 
# 	"Images"
# ])

using Tracy
using TracyProfiler_jll

run(TracyProfiler_jll.tracy(); wait=false)

sleep(5)

using WGPUgfx
using WGPUgfx: updateViewTransform!
using WGPUCore
using WGPUCanvas
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays
using WGPUNative
using Images


WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Off)

# axis = defaultAxis()

scene = Scene()
renderer = getRenderer(scene)

axis1 = defaultAxis()
axis2 = defaultAxis()

camera1 = defaultCamera()
camera2 = defaultCamera()
setfield!(camera1, :id, 1)
setfield!(camera2, :id, 2)

scene.cameraSystem = CameraSystem([camera1, camera2])

addObject!(renderer, axis1)
addObject!(renderer, axis2)

quad = defaultQuad()
# setfield!(quad, :textureData, textureData)

addObject!(renderer, quad, camera1)

attachEventSystem(renderer)

function runApp(renderer)
	@tracepoint "init" init(renderer)
	@tracepoint "render" render(renderer)
	# render(renderer, renderer.scene.objects; dims=(50, 50, 300, 300))
	# render(renderer, renderer.scene.objects[2]; dims=(150, 150, 400, 400))
	@tracepoint "deinit" deinit(renderer)
end

mainApp = () -> begin
	try
		count = 0
		camera1 = scene.cameraSystem[1]
		while !WindowShouldClose(scene.canvas.windowRef[])
			# Create rotation matrix
			rot = RotXY(0.01, 0.02)
			rotMatrix = convertToMatrix(rot)
			
			# Get current view matrix and apply rotation
			viewMatrix = camera1.uniformData.viewMatrix
			newViewMatrix = viewMatrix * rotMatrix
			
			# Update camera view transform
			updateViewTransform!(camera1, newViewMatrix)
			
			# Animate quad position
			theta = time()
			quad.uniformData = translate([
				1.0*sin(theta), 
				1.0*cos(theta), 
				0.0f0
			]).linear
			@tracepoint "runAppLoop" runApp(renderer)
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(scene.canvas)
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	mainApp()
else
	mainApp()
end
