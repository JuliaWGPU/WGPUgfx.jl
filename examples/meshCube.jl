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
scene = Scene()
renderer = getRenderer(scene)
canvas = scene.canvas
gpuDevice = scene.gpuDevice

mesh = WGPUgfx.defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "cube.obj"))

addObject!(renderer, mesh)

attachEventSystem(renderer)

function runApp(renderer)
	init(renderer)
	render(renderer)
	deinit(renderer)
end

# @enter	runApp(scene, gpuDevice, renderPipeline)
main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			# camera = scene.camera
			# rotxy = RotXY(pi/3, time())
			# camera.scale = [1, 1, 1] .|> Float32
			runApp(renderer)
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
