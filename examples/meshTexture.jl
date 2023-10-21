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

scene = Scene()
canvas = scene.canvas
gpuDevice = scene.canvas

renderer = getRenderer(scene)

mesh1 = defaultWGPUMesh(
			joinpath(pkgdir(WGPUgfx), "assets", "sphere.obj"); 
			image="$(pkgdir(WGPUgfx))/assets/R.png"
)
mesh2 = defaultWGPUMesh(
	joinpath(pkgdir(WGPUgfx), "assets", "torus.obj"); 
	image="$(pkgdir(WGPUgfx))/assets/R.png"
)

addObject!(renderer, mesh1)
addObject!(renderer, mesh2)

attachEventSystem(renderer)

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])

			rot = RotXY(0.3, time())
			mat = MMatrix{4, 4}(mesh1.uniformData)
			mat[1:3, 1:3] .= rot
			mesh1.uniformData = mat
			
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
