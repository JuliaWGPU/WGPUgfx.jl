using Revise
using WGPUgfx
using WGPUCore
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)

axis = defaultAxis()

scene = Scene()

addCamera!(scene, defaultCamera())
addObject!(scene, axis)
attachEventSystem(scene)

main = () -> begin
	try
		while !WindowShouldClose(scene.canvas.windowRef[])
			runApp(scene)
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
