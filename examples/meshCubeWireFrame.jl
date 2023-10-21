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


mesh = WorldObject(
	WGPUgfx.defaultWGPUMesh(
		joinpath(pkgdir(WGPUgfx), "assets", "cube.obj")
	), 
	RenderType(VISIBLE | SURFACE | BBOX ), 
	nothing, 
	nothing, 
	nothing, 
	nothing
)

wireFrame = WorldObject(
	WGPUgfx.defaultWGPUMesh(
		joinpath(pkgdir(WGPUgfx), "assets", "cube.obj")
	), 
	RenderType(VISIBLE | WIREFRAME ), 
	nothing, 
	nothing, 
	nothing, 
	nothing
)

addObject!(renderer, mesh)
addObject!(renderer, wireFrame)

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
			tz = translate([sin(time()), 0, 0]).linear
			mat = MMatrix{4, 4}(mesh.uniformData)
			mat .= tz
			mesh.uniformData = mat
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
