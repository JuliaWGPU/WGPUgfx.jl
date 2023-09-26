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

mesh = WGPUgfx.defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "monkey.obj"))

wf = defaultWireFrame(mesh)
addObject!(scene, mesh)
addObject!(scene, wf)

attachEventSystem(scene)

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			tz = translate([sin(time()), 0, 0]).linear
			mat = MMatrix{4, 4}(mesh.uniformData)
			mat .= tz
			mesh.uniformData = mat
			runApp(gpuDevice, scene)
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
