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



# This section is still in works and is commented for now
# For this to work Quad structure should hold UV coordinates
# Currently `Quad` doesn't have `uvData` filed like in `WGPUMesh` to map a texture.
# The below code works though (atleast until bitmap generation) 
# -------------------------------------------------------
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

# ---------------------------------------------------


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
