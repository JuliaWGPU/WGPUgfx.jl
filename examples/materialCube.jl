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
canvas = WGPUCore.defaultCanvas(WGPUCore.WGPUCanvas);
gpuDevice = WGPUCore.getDefaultDevice();
camera = defaultCamera()

light = defaultLighting()

scene = Scene(
	gpuDevice, 
	canvas, 
	camera, 
	light, 
	[], 
	repeat([nothing], 4)...
)

cube = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "cube.obj"); image= "/Users/arhik/Pictures/OIP.jpeg")

addObject!(scene, cube)

attachEventSystem(scene)

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			runApp(scene)
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
