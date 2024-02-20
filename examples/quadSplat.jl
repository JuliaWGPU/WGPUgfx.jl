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

pc = defaultQSplat(1)

# scene.cameraSystem = CameraSystem([camera1, camera2])

addObject!(renderer, pc, scene.cameraSystem[1])

# attachEventSystem(renderer)

function runApp(renderer)
    init(renderer)
    render(renderer)
    deinit(renderer)
end

mainApp = () -> begin
	try
		count = 0
		while !WindowShouldClose(scene.canvas.windowRef[])
			@tracepoint "runAppLoop" runApp(renderer)
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



