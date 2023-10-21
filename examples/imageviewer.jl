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
scene = Scene()
canvas = scene.canvas
gpuDevice = scene.gpuDevice

renderer = getRenderer(scene)

plane = defaultWGPUMesh(
	joinpath(pkgdir(WGPUgfx), "assets", "plane.obj");
	image = joinpath(pkgdir(WGPUgfx), "assets", "R.png")
)

addObject!(renderer, plane)

attachEventSystem(renderer)

function runApp(renderer)
	init(renderer)
	render(renderer)
	deinit(renderer)
end	


main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			runApp(renderer)
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
