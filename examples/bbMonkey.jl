# TODO this example should showcase `RenderType`
# A blender monkey as an example mesh is display with Bounding Box.
# Also a wireframe version is display which will remain static.
# Animating the mesh version should showcase how a bounding box and axis defined using RenderType
# follows the mesh

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

renderer = getRenderer(scene)

mesh = WGPUgfx.WorldObject(
	defaultWGPUMesh(
		joinpath(pkgdir(WGPUgfx), "assets", "monkey.obj")
	),
	RenderType(VISIBLE | SURFACE | BBOX | AXIS),
	nothing,
	nothing,
	nothing,
	nothing,
)

wireFrame = WGPUgfx.WorldObject(
	defaultWGPUMesh(
		joinpath(pkgdir(WGPUgfx), "assets", "monkey.obj")
	),
	RenderType(VISIBLE | WIREFRAME),
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
