# WIP
# This example showcases a 2D quad rendering on top of 3D render scene.
# This will allow GUI interaction with GUI elements like textboxes etc ...
# Currently it draws only the Quad with transparency since we need transparency for Text only fields.
# Fully function example should render text and stay at a place with interaction possibilty. 
# TODOMore dynamic 3D environment will be more evident for showcasing purposes.


using Revise
using WGPUgfx
using WGPUCore
using WGPUGUI
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays
using WGPUNative
using Debugger
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
	init(renderer)
	render(renderer)
	# render(renderer, renderer.scene.objects; dims=(50, 50, 300, 300))
	# render(renderer, renderer.scene.objects[2]; dims=(150, 150, 400, 400))
	deinit(renderer)
end

run = () -> begin
	try
		count = 0
		camera1 = scene.cameraSystem[1]
		while !WindowShouldClose(scene.canvas.windowRef[])
			rot = RotXY(0.01, 0.02)
			mat = MMatrix{4, 4, Float32}(I)
			mat[1:3, 1:3] = rot
			camera1.transform = camera1.transform*mat
			theta = time()
			quad.uniformData = translate((				
				1.0*(sin(theta)), 
				1.0*(cos(theta)), 
				0, 
				1
			)).linear
			runApp(renderer)
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(scene.canvas)
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	run()
else
	run()
end
