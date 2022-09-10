module EventsMod

using WGPU
using GLFW
using WGPUgfx.SceneMod.ShaderMod.PrimitivesMod: Camera, Vision
using CoordinateTransformations
using Rotations
using StaticArrays
using LinearAlgebra

export attachEventSystem

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


function attachMouseButtonCallback(canvas, camera)
	WGPU.setMouseButtonCallback(
		canvas, 
		(_, button, action, a) -> begin
			@info GLFW.MouseButton button action a mouseState
			setMouseState(mouseState, Val(button), action)
		end
	)
end

function attachScrollCallback(canvas, camera::Camera)
	WGPU.setScrollCallback(
		canvas,
		(_, xoff, yoff) -> begin
			@info "MouseScroll" xoff, yoff
			camera.scale = camera.scale .+ yoff.*maximum(mouseState.speed)
		end
	)
end

function attachCursorPosCallback(canvas, camera::Camera)
	WGPU.setCursorPosCallback(
		canvas, 
		(_, x, y) -> begin
			@info "Mouse Position" x, y
			if all(((x, y) .- canvas.size) .< 0)
				if mouseState.leftClick
					delta = (mouseState.prevPosition .- (y, x)).*mouseState.speed
					@info delta
					rot = RotXY(delta...)
					camera.eye = rot*camera.eye 
					mouseState.prevPosition = (y, x)
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
end


function attachScrollCallback(canvas, vision::Vision)
	WGPU.setScrollCallback(
		canvas,
		(_, xoff, yoff) -> begin
			@info "MouseScroll" xoff, yoff
			vision.scale = vision.scale .+ yoff.*maximum(mouseState.speed)
		end
	)
end


function attachCursorPosCallback(canvas, vision::Vision)
	WGPU.setCursorPosCallback(
		canvas, 
		(_, x, y) -> begin
			@info "Mouse Position" x, y
			if all(((x, y) .- canvas.size) .< 0)
				if mouseState.leftClick
					delta = (mouseState.prevPosition .- (x, y)).*mouseState.speed
					@info delta
					rot = RotXY(delta...)
					# mat = MMatrix{4, 4, Float32}(vision.transform)
					# mat[1:3, 1:3] = rot
					vision.eye = rot*vision.eye
					mouseState.prevPosition = (x, y)
				elseif mouseState.rightClick
					delta = (mouseState.prevPosition .- (x, y)).*mouseState.speed
					mat = MMatrix{4, 4, Float32}(I)
					mat[1:3, 3] .= [delta..., 0]
					vision.transform = vision.transform*mat
					mouseState.prevPosition = (x, y)
				elseif mouseState.middleClick
					mat = MMatrix{4, 4, Float32}(I)
					vision.transform = mat
				else
					mouseState.prevPosition = (x, y)
				end
			end
		end
	)
end


function attachEventSystem(scene)

	canvas = scene.canvas
	camera = scene.camera

	attachMouseButtonCallback(canvas, camera)
	attachScrollCallback(canvas, camera)
	attachCursorPosCallback(canvas, camera)

end

end
