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
using Images

# using FreeTypeAbstraction

# # load a font
# face = FTFont("$(ENV["HOMEPATH"])/JuliaMono-Light.ttf")

# # render a character
# img, metric = renderface(face, 'C', 10)

# # render a string into an existing matrix
# myarray = zeros(N0f8, 100, 100)
# pixelsize = 10
# x0, y0 = 90, 10

# helloString = (renderstring!(myarray, "hello", face, pixelsize, x0, y0, halign=:hright))

# imageF = ones(RGBA, size(helloString))

# imageF[:, :, :, 1] = RGB.(helloString)

# resize(imageF, (256, 256))

# textureData = begin
# 	img = RGBA.(imageF) |> adjoint
# 	imgview = channelview(img) |> collect 
# end

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)

# axis = defaultAxis()

scene = Scene()
renderer = getRenderer(scene)

axis1 = defaultAxis()
axis2 = defaultAxis()

camera1 = defaultCamera()
camera2 = defaultCamera()
setfield!(camera1, :id, 1)
setfield!(camera2, :id, 2)

scene.cameraSystem = CameraSystem([camera1, camera2])

addObject!(renderer, axis1)
addObject!(renderer, axis2)

quad = defaultQuad()
# setfield!(quad, :textureData, textureData)

addObject!(renderer, quad, camera1)

attachEventSystem(renderer)

function runApp(renderer)
	init(renderer)
	render(renderer)
	# render(renderer, renderer.scene.objects; dims=(50, 50, 300, 300))
	# render(renderer, renderer.scene.objects[2]; dims=(150, 150, 400, 400))
	deinit(renderer)
end

main = () -> begin
	try
		count = 0
		camera1 = scene.cameraSystem[1]
		while !WindowShouldClose(scene.canvas.windowRef[])
			rot = RotXY(0.01, 0.02)
			mat = MMatrix{4, 4, Float32}(I)
			mat[1:3, 1:3] = rot
			camera1.transform = camera1.transform*mat
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
