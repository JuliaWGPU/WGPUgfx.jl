
using WGPUgfx
using WGPUCore
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)

canvas = WGPUCore.defaultInit(WGPUCore.WGPUCanvas);
gpuDevice = WGPUCore.getDefaultDevice();

scene = Scene(canvas, [], repeat([nothing], 9)...)
camera = defaultCamera()
push!(scene.objects, camera)

circle = defaultCircle(12)
push!(scene.objects, circle)

(renderPipeline, _) = setup(scene, gpuDevice);

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
