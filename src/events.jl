using WGPUCanvas
using WGPUCore
using GLFW
using CoordinateTransformations
using Rotations
using StaticArrays
using LinearAlgebra

export attachEventSystem, detachEventSystem

mutable struct MouseState
	leftClick
	rightClick
	middleClick
	prevPosition
	speed
end

mouseState = MouseState(false, false, false, (0, 0), (0.02, 0.02))


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
	# mat = Matrix{Float32}(I, (4, 4))
	# a = camera.uniformData
	# a[1:3, 1:3] = mat[1:3, 1:3]
	# camera.uniformData = a
end


function attachMouseButtonCallback(scene, camera)
	WGPUCanvas.setMouseButtonCallback(
		scene.canvas, 
		(_, button, action, a) -> begin
			# @info GLFW.MouseButton button action a mouseState
			setMouseState(mouseState, Val(button), action)
		end
	)
end

function attachScrollCallback(scene, camera::Camera)
	WGPUCanvas.setScrollCallback(
		scene.canvas,
		#(_, xoff, yoff) -> begin
		#	# @info "MouseScroll" xoff, yoff
		#	camera.scale = camera.scale .+ yoff.*maximum(mouseState.speed)
		#end
		(_, xoff, yoff) -> begin
			camera.eye += (camera.eye - camera.lookAt)*yoff.*maximum(mouseState.speed)
			camera.lookAt += (camera.eye - camera.lookAt)*yoff.*maximum(mouseState.speed)
		end
	)
end

function attachCursorPosCallback(scene, camera::Camera)
	WGPUCanvas.setCursorPosCallback(
		scene.canvas, 
		(_, x, y) -> begin
			# @info "Mouse Position" x, y
			if all(((x, y) .- scene.canvas.size) .< 0)
				if mouseState.leftClick
					delta = -1.0.*(mouseState.prevPosition .- (y, x)).*mouseState.speed
					rot = RotXY(delta...)
					camera.eye = rot*camera.eye
					#mat = MMatrix{4, 4, Float32}(I)
					#mat[1:3, 1:3] = rot
					#updateViewTransform!(camera, camera.uniformData.viewMatrix*mat)
					mouseState.prevPosition = (y, x)
				elseif mouseState.rightClick
					delta = -1.0.*(mouseState.prevPosition .- (y, x)).*mouseState.speed
					#camera.lookAt += [delta..., 0]
					#camera.eye += [delta..., 0]
					#mat = MMatrix{4, 4, Float32}(I)
					#mat[1:3, 3] .= [delta..., 0]
					#updateViewTransform!(camera, camera.uniformData.viewMatrix*mat)
					mouseState.prevPosition = (y, x)
				elseif mouseState.middleClick
					#mat = MMatrix{4, 4, Float32}(I)
					#updateViewTransform!(camera, mat)
					mouseState.prevPosition = (y, x)
				else
					mouseState.prevPosition = (y, x)
				end
			end
		end
	)
end


function attachKeyCallback(scene, camera::Camera)
	WGPUCanvas.setKeyCallback(
		scene.canvas,
        (_, key, scancode, action, mods) -> begin
                name = GLFW.GetKeyName(key, scancode)
               	if name == "a" && action == GLFW.PRESS
					attachMouseButtonCallback(scene, camera)
					attachScrollCallback(scene, camera)
					attachCursorPosCallback(scene, camera)	
                elseif name == "d" && action == GLFW.PRESS
					detachMouseButtonCallback(scene, camera)
					detachScrollCallback(scene, camera)
					detachCursorPosCallback(scene, camera)                	
                end                     	
		end
	)
end

function detachMouseButtonCallback(scene, camera)
	WGPUCanvas.setMouseButtonCallback(scene.canvas, nothing)
end

function detachScrollCallback(scene, camera)
	WGPUCanvas.setScrollCallback(scene.canvas, nothing)
end

function detachCursorPosCallback(scene, camera)
	WGPUCanvas.setCursorPosCallback(scene.canvas, nothing)
end

function attachEventSystem(renderer)
	scene = renderer.scene
	camera = scene.camera
	attachMouseButtonCallback(scene, camera)
	attachScrollCallback(scene, camera)
	attachCursorPosCallback(scene, camera)
	attachKeyCallback(scene, camera)
end

function detachEventSystem(renderer)
	scene = renderer.scene
	camera = scene.camera
	detachMouseButtonCallback(scene, camera)
	detachScrollCallback(scene, camera)
	detachCursorPosCallback(scene, camera)
end
