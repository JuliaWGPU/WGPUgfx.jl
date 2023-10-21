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
canvas = scene.canvas
gpuDevice = scene.gpuDevice

renderer = getRenderer(scene)

mesh = WGPUgfx.defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "monkey.obj"))

wf = defaultWireFrame(mesh)
addObject!(renderer, mesh)
addObject!(renderer, wf)

attachEventSystem(renderer)

function runApp(renderer)
	init(renderer)
	render(renderer)
	deinit(renderer)
end

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			tz = translate([sin(time()), 0, 0]).linear
			mat = MMatrix{4, 4}(mesh.uniformData)
			mat .= tz
			mesh.uniformData = mat
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
