# using PlyIO

# plyData = PlyIO.load_ply("C:\\Users\\Arhik\\Downloads\\garden_30000.ply");

# vertexElement = plyData["vertex"]

# sh = cat(map((x) -> getindex(vertexElement, x), ["f_dc_0", "f_dc_1", "f_dc_2"])..., dims=2)
# scale = cat(map((x) -> getindex(vertexElement, x), ["scale_0", "scale_1", "scale_2"])..., dims=2)
# normals = cat(map((x) -> getindex(vertexElement, x), ["nx", "ny", "nz"])..., dims=2)
# points = cat(map((x) -> getindex(vertexElement, x), ["x", "y", "z"])..., dims=2)
# quaternions = cat(map((x) -> getindex(vertexElement, x), ["rot_0", "rot_1", "rot_2", "rot_3"])..., dims=2)
# features = cat(map((x) -> getindex(vertexElement, x), ["f_rest_$i" for i in 0:44])..., dims=2)
# opacity = vertexElement["opacity"]
# splatData = cat([points, normals, scale, quaternions, features, opacity]..., dims=2) 
using Revise
using Tracy
using WGPUgfx
using WGPUCore
using WGPUCanvas
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays
using WGPUNative
using Images

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Off)

scene = Scene()
renderer = getRenderer(scene)

pc = defaultGaussianQuad()

# scene.cameraSystem = CameraSystem([camera1, camera2])

addObject!(renderer, pc, scene.cameraSystem[1])

# attachEventSystem(renderer)

function runApp(renderer)
    init(renderer)
    render(renderer)
    deinit(renderer)
end

mainApp = () -> begin
	try
		count = 0
		while !WindowShouldClose(scene.canvas.windowRef[])
			@tracepoint "runAppLoop" runApp(renderer)
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(scene.canvas)
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	mainApp()
else
	mainApp()
end



