using Debugger
using WGPUgfx
using WGPU
using WGPU_jll
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays
using CoordinateTransformations

WGPU.SetLogLevel(WGPU.WGPULogLevel_Debug)
canvas = WGPU.defaultCanvas(WGPU.WGPUCanvas; size=(500, 500));
gpuDevice = WGPU.getDefaultDevice();

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

mesh1 = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "sphere.obj"); image="/Users/arhik/Pictures/rainbow.jpeg")
mesh2 = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "torus.obj"); image="/Users/arhik/Pictures/people.jpeg")
addObject!(scene, mesh1)
addObject!(scene, mesh2)


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
	mat = MMatrix{4, 4, Float32}(I)
	camera.uniformData = mat
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
				delta = (mouseState.prevPosition .- (x, y)).*mouseState.speed
				@info delta
				rot = RotXY(delta...)
				mat = MMatrix{4, 4, Float32}(I)
				mat[1:3, 1:3] = rot
				camera.transform = camera.transform*mat 
				mouseState.prevPosition = (x, y)
			elseif mouseState.rightClick
				delta = (mouseState.prevPosition .- (x, y)).*mouseState.speed
				mat = MMatrix{4, 4, Float32}(I)
				mat[1:3, 3] .= [delta..., 0] .|> Float32
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

			rot = RotXY(0.3, time())
			mat = MMatrix{4, 4}(mesh1.uniformData)
			mat[1:3, 1:3] .= rot
			mesh1.uniformData = mat
			
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
