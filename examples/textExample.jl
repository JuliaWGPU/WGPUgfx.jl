
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
using ImageView

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)

scene = Scene();
renderer = getRenderer(scene);
camera = defaultCamera();
addCamera!(scene, camera)

using FreeTypeAbstraction

# load a font
face = FTFont("$(ENV["HOMEPATH"])/JuliaMono-Light.ttf")

# render a character
img, metric = renderface(face, 'C', 50)

imageF = ones(RGBA{N0f8}, size(img) |> reverse)

imageF[:, :, :, 1] = imrotate(RGB{N0f8}.(img./255f0), -pi/2)

textureData = begin
	img = imrotate((imageF), pi/2)
	imgview = channelview(img) |> collect 
end

quad = defaultQuad(; imgData = Ref(textureData));

addObject!(renderer, quad, camera);

# attachEventSystem(renderer)

function runApp(renderer)
	init(renderer)
    render(renderer)
	# render(renderer, renderer.scene.objects[1], camera; dims=(50, 50, 300, 300))
	deinit(renderer)
end

# runApp(renderer)

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

