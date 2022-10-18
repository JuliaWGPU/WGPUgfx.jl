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
canvas = WGPUCore.defaultCanvas(WGPUCore.WGPUCanvas; size=(500, 500));
gpuDevice = WGPUCore.getDefaultDevice();
camera = defaultCamera()

light = defaultLighting()

scene = Scene(
	gpuDevice, 
	canvas, 
	camera, 
	light, 
	[], 
	repeat([nothing], 6)...
)

mesh = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "pixarlamp.obj"))
addObject!(scene, mesh)

attachEventSystem(scene)

# @enter	runApp(scene, gpuDevice, renderPipeline)
main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			rot = RotY(0.01) .|> Float32
			mat = MMatrix{4, 4, Float32}(I)
			mat[1:3, 1:3] .= rot
			camera.transform = camera.transform*mat
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
