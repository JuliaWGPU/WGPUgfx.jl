# This example should simple display CUBE mesh primitive
# TODO show two different ways to render them. 
# One version grouped together version with axis, bbox

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
renderer = getRenderer(scene)

cube = defaultWGPUMesh("$(pkgdir(WGPUgfx))/assets/monkey.obj")
grid = defaultGrid()
axis = defaultAxis(; len=2)
wo = WorldObject(cube, RenderType(VISIBLE | SURFACE | WIREFRAME | BBOX | AXIS ), nothing, nothing, nothing, nothing)

addObject!(renderer, wo)
addObject!(renderer, grid)
addObject!(renderer, axis)

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
