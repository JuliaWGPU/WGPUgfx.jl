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

scene = Scene((750, 750));
renderer = getRenderer(scene);

circle = defaultUICircle(;nSectors=20, radius=0.2, color = [0.4, 0.3, 0.5, 0.6]);

addObject!(renderer, circle, scene.camera);

# quad.uniformData = Matrix{Float32}(I, (4, 4))

mouseState = defaultMouseState()

keyboardState= defaultKeyboardState()

attachEventSystem(renderer, mouseState, keyboardState)

function runApp(renderer)
	init(renderer)
	render(renderer)
	deinit(renderer)
end

main = () -> begin
	try
		pos = [0.0,0.0]
		speed = 0.05
		while !WindowShouldClose(scene.canvas.windowRef[])
			runApp(renderer)
		    if keyboardState.action in (GLFW.PRESS, GLFW.REPEAT)
				if keyboardState.key == GLFW.KEY_RIGHT
					pos[1]+=speed
				elseif keyboardState.key == GLFW.KEY_LEFT
					pos[1]-=speed
	            elseif keyboardState.key == GLFW.KEY_UP
					pos[2]+=speed
				elseif keyboardState.key == GLFW.KEY_DOWN
					pos[2]-=speed
				end
				renderer.scene.objects[1].uniformData = translate([pos[1], pos[2] ,0.0]).linear 
			end
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
