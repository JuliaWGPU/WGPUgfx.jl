using Debugger
using WGPUgfx
using WGPUCore
using WGPUNative
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays
using CoordinateTransformations

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)
canvas = WGPUCore.defaultCanvas(WGPUCore.WGPUCanvas; size=(500, 500));
gpuDevice = WGPUCore.getDefaultDevice();

camera = defaultCamera()
light = defaultLighting()

scene = Scene(
	gpuDevice,
	canvas, 
	camera, 
	light, 
	[], 
	repeat([nothing], 4)...,
)

mesh1 = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "plane.obj"); image="/Users/arhik/Pictures/OIP.jpeg")
addObject!(scene, mesh1)

attachEventSystem(scene)

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			runApp(gpuDevice, scene)
			PollEvents()
		end
	finally
		for object in scene.objects
			for prop in propertynames(object)
				if WGPUCore.isDestroyable(getfield(object, prop))
					@warn "Destroying" typeof(object) prop 
					WGPUCore.destroy(getfield(object, prop))
				end
			end
		end
		# WGPUCore.destroy(gpuDevice.adapter)
		WGPUCore.destroy(gpuDevice)
		WGPUCore.destroyWindow(canvas)
	end
end

# using Profile
# Profile.Allocs.clear()
# @time Profile.Allocs.@profile sample_rate=1 runApp(gpuDevice, scene)
# 
# using PProf
# PProf.Allocs.pprof(from_c = true)

if abspath(PROGRAM_FILE)==@__FILE__
	main()
else
	main()
end
