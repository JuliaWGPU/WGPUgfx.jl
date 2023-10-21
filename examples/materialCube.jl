using Debugger
using WGPUgfx
using WGPUCore
using WGPUNative
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Off)

scene = Scene()
renderer = getRenderer(scene)

canvas = scene.canvas
gpuDevice = scene.gpuDevice


cube = defaultWGPUMesh(
	joinpath(pkgdir(WGPUgfx), "assets", "cube.obj"); 
	image= "$(pkgdir(WGPUgfx))/assets/R.png"
)

addObject!(renderer, cube)

attachEventSystem(renderer)

function runApp(renderer)
	init(renderer)
	render(renderer)
	deinit(renderer)
end

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
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
