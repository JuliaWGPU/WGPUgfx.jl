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
canvas = scene.canvas
camera = scene.camera
gpuDevice = scene.gpuDevice

renderer = getRenderer(scene)

mesh = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "pixarlamp.obj"))
addObject!(renderer, mesh)

attachEventSystem(renderer)

function runApp(renderer)
	init(renderer)
	render(renderer)
	deinit(renderer)
end

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			rot = RotY(0.01) .|> Float32
			mat = MMatrix{4, 4, Float32}(I)
			mat[1:3, 1:3] .= rot
			camera.transform = camera.transform*mat
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
