using Revise
using Tracy
using WGPUgfx
using WGPUCore
using WGPUCanvas
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays
using WGPUNative
using Images

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Off)

scene = Scene()
renderer = getRenderer(scene)

# pc = defaultGSplat(joinpath(pkgdir(WGPUgfx), "assets", "bonsai", "bonsai_30000.ply"))
pc = defaultGSplat(joinpath(ENV["HOME"], "Downloads", "train", "train_30000.ply"))
# pc = defaultGSplat(joinpath(ENV["HOME"], "Downloads", "bonsai", "bonsai_30000.ply"))

axis = defaultAxis()

addObject!(renderer, pc)
addObject!(renderer, axis)

attachEventSystem(renderer)

function runApp(renderer)
    init(renderer)
    render(renderer)
    deinit(renderer)
end

mainApp = () -> begin
	try
		while !WindowShouldClose(scene.canvas.windowRef[])
			runApp(renderer)
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(scene.canvas)
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	mainApp()
else
	mainApp()
end



