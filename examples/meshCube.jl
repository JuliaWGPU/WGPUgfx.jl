using Debugger
using WGPUgfx
using WGPUCore
using WGPUNative
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)
canvas = WGPUCore.defaultCanvas(WGPUCore.WGPUCanvas);
gpuDevice = WGPUCore.getDefaultDevice();

camera = defaultCamera()
light = defaultLighting()
scene = Scene(
	gpuDevice, 
	canvas, 
	camera, 
	light, 
	[], 
	repeat([nothing], 4)...
)

mesh = WGPUgfx.defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "cube.obj"))

addObject!(scene, mesh)

attachEventSystem(scene)

# @enter	runApp(scene, gpuDevice, renderPipeline)
main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			# camera = scene.camera
			# rotxy = RotXY(pi/3, time())
			# camera.scale = [1, 1, 1] .|> Float32
			runApp(gpuDevice, scene)
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(canvas)
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	main()
else
	main()
end
