using Revise
using WGPUgfx
using WGPUCore
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays
using WGPUNative
using Debugger

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)

scene = Scene();
renderer = getRenderer(scene);
camera = defaultCamera();
addCamera!(scene, camera)

quad = defaultQuad();

addObject!(renderer, quad, camera);

# quad.uniformData = Matrix{Float32}(I, (4, 4))

# attachEventSystem(renderer)

function runApp(renderer)
	init(renderer)
    render(renderer)
	# render(renderer, renderer.scene.objects[1], camera; dims=(50, 50, 300, 300))
	deinit(renderer)
end


main = () -> begin
	try
		while !WindowShouldClose(scene.canvas.windowRef[])
			runApp(renderer)
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
