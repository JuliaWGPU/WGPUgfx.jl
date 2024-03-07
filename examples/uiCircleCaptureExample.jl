using Revise
using WGPUgfx
using WGPUCore
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow, WaitEvents
using LinearAlgebra
using Rotations
using StaticArrays
using WGPUNative
using Debugger

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Off)

scene = Scene();
renderer = getRenderer(scene);

circle = defaultUICircle(;nSectors=20, radius=0.2, color = [0.4, 0.3, 0.5, 0.6]);
circle2 = defaultUICircle(;nSectors=100, radius=0.1, color = [0.5, 0.9, 0.2, 0.2]);

addObject!(renderer, circle, scene.camera);

# quad.uniformData = Matrix{Float32}(I, (4, 4))

mouseState = defaultMouseState()

keyboardState= defaultKeyboardState()

attachEventSystem(renderer, mouseState, keyboardState)

function runApp(renderer)
	init(renderer)
    render(renderer)
	# render(renderer, renderer.scene.objects[1], camera; dims=(50, 50, 300, 300))
	deinit(renderer)
end


main = () -> begin
	try
		flag = false
		while !WindowShouldClose(scene.canvas.windowRef[])
			runApp(renderer)
			if mouseState.leftClick == true
				if !flag
					popfirst!(renderer.scene.objects)
					addObject!(renderer, circle2, scene.camera)
					flag = true
				end
			else
				if flag
					popfirst!(renderer.scene.objects)
					addObject!(renderer, circle, scene.camera)
					flag = false
				end 
			end 
			@info keyboardState
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
