# This is an incomplete example or WIP example.
# Basic idea of this example is to showcase how Text can be rendered on Quads.
# This will be a start for WGPU-UI code base once working and will be moved to WGPU-UI.

# TODO this example should be able to get texture from bitmap using FreeType
# And pass texture to Quad for UV coordinate mapping. End result should be a text rendered
# on screen. This will be useful, lets say, for FPS display (frames per sencond).

using Revise
using WGPUgfx
using WGPUCore
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays
using WGPUNative
using Debugger

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)

scene = Scene();
renderer = getRenderer(scene);
camera = defaultCamera();
addCamera!(scene, camera)

quad = defaultQuad(;scale=[0.3, 0.4, 0.5, 1.0] .|> Float32, 
		image=joinpath(pkgdir(WGPUgfx), "assets", "R.png"));

addObject!(renderer, quad, camera);

attachEventSystem(renderer)

function runApp(renderer)
	init(renderer)
    render(renderer)
	# render(renderer, renderer.scene.objects[1], camera; dims=(50, 50, 300, 300))
	deinit(renderer)
end

main = () -> begin
	try
		while !WindowShouldClose(scene.canvas.windowRef[])
			runApp(renderer)
			quad.uniformData = scaleTransform([abs(sin(time())) + 0.3, abs(sin(time())) + 0.4, 1.0]).linear
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(scene.canvas)
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	main()
else
	main()
end
