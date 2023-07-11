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
	repeat([nothing], 6)...,
)

mesh1 = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "sphere.obj"); color=[0.6, 0.4, 0.5, 1.0])
mesh2 = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "sphere.obj"); color=[0.8, 0.4, 0.3, 0.5])
mesh3 = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "sphere.obj"); color=[0.3, 0.6, 0.9, 0.5])
mesh4 = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "sphere.obj"); color = [0.4, 0.3, 0.5, 0.3])
# mesh5 = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "monkey.obj"); color = [0.4, 0.3, 0.5, 0.3])

addObject!(scene, mesh1)
addObject!(scene, mesh2)
addObject!(scene, mesh3)
addObject!(scene, mesh4)
# addObject!(scene, mesh5)

attachEventSystem(scene)

# @enter	runApp(scene, gpuDevice, renderPipeline)
main = () -> begin
	trans = WGPUgfx.translate([1.5, 0.0, 0.0])
	scale = WGPUgfx.scaleTransform([0.2, 0.2, 0.2])
	mesh2Translation = (trans∘scale).linear
	trans = WGPUgfx.translate([0.0, 0.0, 1.5])
	scale = WGPUgfx.scaleTransform([0.3, 0.3, 0.3])
	mesh3Translation = (trans∘scale).linear

	try
		while !WindowShouldClose(canvas.windowRef[])
			rot = RotXY(0.15, time())
			mat = MMatrix{4, 4}(mesh1.uniformData)
			mat[1:3, 1:3] .= rot
			mesh1.uniformData = mat

			rot = RotXY(-0.2, time())
			mat = MMatrix{4, 4}(mesh4.uniformData)
			mat[1:3, 1:3] .= rot
			mesh4.uniformData = mat

			rot = RotXY(-0.4, time())
			mat = MMatrix{4, 4}(mesh4.uniformData)
			mat[1:3, 1:3] .= rot
			mesh2.uniformData = mat*mesh2Translation*mat

			rot = RotXY(-0.3, time())
			mat = MMatrix{4, 4}(mesh2.uniformData)
			mat[1:3, 1:3] .= rot
			mesh3.uniformData = mat*mesh3Translation*mat
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
