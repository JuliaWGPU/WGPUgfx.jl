# This is an incomplete example or WIP example.
# Basic idea of this example is to showcase how Text can be rendered on Quads.
# This will be a start for WGPU-UI code base once working and will be moved to WGPU-UI.

# TODO this example should be able to get texture from bitmap using FreeType
# And pass texture to Quad for UV coordinate mapping. End result should be a text rendered
# on screen. This will be useful, lets say, for FPS display (frames per sencond).

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
using FreeTypeAbstraction

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)

scene = Scene();
renderer = getRenderer(scene);
camera = defaultCamera();
addCamera!(scene, camera)

function getCharTexture(chr::Char)
	ftface = FTFont(joinpath(pkgdir(WGPUgfx), "assets", "JuliaMono", "JuliaMono-Light.ttf"))
	img, metric = renderface(ftface, chr, 50)
	imageF = ones(RGBA{N0f8}, size(img))
	imageF[:, :, :, 1] = imrotate(RGB{N0f8}.(img./255f0), pi/2, axes(img))
	textureData = begin
		img = imrotate((imageF), pi/2)
		imgview = channelview(img) |> collect 
	end
	return textureData
end
											
imageData=getCharTexture('0');
quad = defaultQuad(;color=[0.2, 0.3, 0.4, 1.0], scale=[0.1, 0.1, 1.0, 1.0] .|> Float32, imgData = imageData);

addObject!(renderer, quad, camera);

attachEventSystem(renderer)

function runApp(renderer)
	init(renderer)
    render(renderer)
	deinit(renderer)
end

main = () -> begin
	try
		while !WindowShouldClose(scene.canvas.windowRef[])
			runApp(renderer)
			quad.uniformData = scaleTransform([abs(sin(time())) + 0.3, abs(sin(time())) + 0.4, 1.0]).linear
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
