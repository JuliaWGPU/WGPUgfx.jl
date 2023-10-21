# TODO this is a bit incomplete.
# The wireframe does not convert the all vertices and lines yet but a good start for now

using Debugger
using WGPUgfx
using WGPUgfx: RenderType
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

mesh = WGPUgfx.defaultCube(
	joinpath(pkgdir(WGPUgfx), "assets", "cube.obj")
)

wo = WorldObject{Cube}(
	mesh, 
	RenderType(VISIBLE | WIREFRAME | AXIS), 
	nothing, 
	nothing, 
	nothing, 
	nothing
)

addObject!(renderer, wo)

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
			mat = MMatrix{4, 4}(wo.uniformData)
			mat .= tz
			wo.uniformData = mat
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
