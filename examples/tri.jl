
using WGPUgfx
using WGPU
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays

WGPU.SetLogLevel(WGPU.WGPULogLevel_Off)

canvas = WGPU.defaultInit(WGPU.WGPUCanvas);
gpuDevice = WGPU.getDefaultDevice();

scene = Scene(canvas, [], repeat([nothing], 9)...)
camera = defaultCamera()
push!(scene.objects, camera)
triangle = defaultTriangle3D()
push!(scene.objects, triangle)

(renderPipeline, _) = setup(scene, gpuDevice);

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			runApp(scene, gpuDevice, renderPipeline)
			PollEvents()
		end
	finally
		WGPU.destroyWindow(canvas)
	end
end

task = Task(main)

schedule(task)
