using Debugger
using WGPUgfx
using WGPUCore
using WGPUNative
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays
using CoordinateTransformations
WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)
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
	repeat([nothing], 4)...,
)

mesh1 = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "sphere.obj"); image="/Users/arhik/Pictures/rainbow.jpeg")
mesh2 = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "torus.obj"); image="/Users/arhik/Pictures/people.jpeg")
addObject!(scene, mesh1)
addObject!(scene, mesh2)

attachEventSystem(scene)

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])

			rot = RotXY(0.3, time())
			mat = MMatrix{4, 4}(mesh1.uniformData)
			mat[1:3, 1:3] .= rot
			mesh1.uniformData = mat
			
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
