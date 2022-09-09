using Debugger
using WGPUgfx
using WGPU
using WGPU_jll
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays

WGPU.SetLogLevel(WGPU.WGPULogLevel_Off)
canvas = WGPU.defaultCanvas(WGPU.WGPUCanvas);
gpuDevice = WGPU.getDefaultDevice();

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

mesh = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "cube.obj"))

addObject!(scene, mesh)

attachEventSystem(scene)

# @enter	runApp(scene, gpuDevice, renderPipeline)
main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			# camera = scene.camera
			# rotxy = RotXY(pi/3, time())
			# camera.scale = [1, 1, 1] .|> Float32
			runApp(gpuDevice, scene)
			PollEvents()
		end
	finally
		WGPU.destroyWindow(canvas)
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	main()
else
	main()
end
