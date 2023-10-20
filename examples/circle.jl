# This example doesn't work yet. Circle Primitive needs to be finished for this work.
# TODO git issue link here [( )]

using WGPUgfx
using WGPUCore
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)


scene = Scene()
canvas = scene.canvas

renderer = getRenderer(scene)

# TODO circle is not defined yet.

circle = defaultCircle()
addObject!(renderer, circle)

function runApp(renderer)
	init(renderer)
	render(renderer)
	deinit(renderer)
end

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			camera = scene.camera
			rotxy = RotXY(pi/3, time())
			camera.scale = [1, 1, 1] .|> Float32
			camera.eye = rotxy*([0.0, 0.0, -10.0] .|> Float32)
			runApp(scene, gpuDevice, renderPipeline)
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(canvas)
	end
end

task = Task(main)

schedule(task)
