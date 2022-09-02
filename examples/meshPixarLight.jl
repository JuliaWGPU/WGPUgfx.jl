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
canvas = WGPU.defaultCanvas(WGPU.WGPUCanvas; size=(500, 400));
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


mutable struct MouseState
	leftClick
	rightClick
	middleClick
	prevPosition
	speed
end


mouseState = MouseState(false, false, false, (0, 0), (0.01, 0.01))


istruthy(::Val{GLFW.PRESS}) = true
istruthy(::Val{GLFW.RELEASE}) = false


function setMouseState(mouse, ::Val{GLFW.MOUSE_BUTTON_1}, state)
	mouse.leftClick = istruthy(Val(state))
end


function setMouseState(mouse, ::Val{GLFW.MOUSE_BUTTON_2}, state)
	mouse.rightClick = istruthy(Val(state))
end


function setMouseState(mouse, ::Val{GLFW.MOUSE_BUTTON_3}, state)
	mouse.middleClick = istruthy(Val(state))
	mat = Matrix{Float32}(I, (4, 4))
	a = camera.uniformData
	a[1:3, 1:3] = mat[1:3, 1:3]
	camera.uniformData = a
end


WGPU.setMouseButtonCallback(
	canvas, 
	(_, button, action, a) -> begin
		@info GLFW.MouseButton button action a mouseState
		setMouseState(mouseState, Val(button), action)
	end
)


WGPU.setScrollCallback(
	canvas,
	(_, xoff, yoff) -> begin
		@info "MouseScroll" xoff, yoff
		camera.scale = camera.scale .+ yoff.*maximum(mouseState.speed)
	end
)


# TODO camera.up will be useful in reasonable movements
WGPU.setCursorPosCallback(
	canvas, 
	(_, x, y) -> begin
		@info "Mouse Position" x, y
		if all(((x, y) .- canvas.size) .< 0)
			if mouseState.leftClick
				delta = (mouseState.prevPosition .- (x, y)).*mouseState.speed.*-1
				@info delta
				rot = RotXY((delta |> reverse)...)
				mat = MMatrix{4, 4, Float32}(I)
				mat[1:3, 1:3] = rot
				camera.transform = camera.transform*mat 
				mouseState.prevPosition = (x, y)
			elseif mouseState.rightClick
				delta = (mouseState.prevPosition .- (x, y)).*mouseState.speed
				mat = MMatrix{4, 4, Float32}(I)
				mat[1:3, 3] .= [delta..., 0]
				camera.transform = camera.transform*mat
				mouseState.prevPosition = (x, y)
			elseif mouseState.middleClick
				mat = MMatrix{4, 4, Float32}(I)
				camera.transform = mat
			else
				mouseState.prevPosition = (x, y)
			end
		end
	end
)


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
		WGPU.destroyWindow(canvas)
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	main()
else
	main()
end
