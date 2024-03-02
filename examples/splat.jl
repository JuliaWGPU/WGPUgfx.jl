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

getHomePath() = begin
	if Sys.isunix()
		return ENV["HOME"]
	elseif Sys.iswindows()
		return ENV["HOMEPATH"]
	end
end

# pc = defaultGSplat(joinpath(getHomePath(), "Downloads", "bonsai", "bonsai_30000.ply"))
pc = defaultGSplat(joinpath(getHomePath(), "Downloads", "train", "train_30000.ply"))
# pc = defaultGSplat(joinpath(getHomePath(), "Downloads", "bicycle", "bicycle_30000.ply"))

axis = defaultAxis()

addObject!(renderer, pc)
addObject!(renderer, axis)

attachEventSystem(renderer)

function runApp(renderer)
    init(renderer)
    render(renderer)
    deinit(renderer)
end


mainApp = () -> begin
	try
		global renderer
		if !GLFW.is_initialized()
			scene.canvas = WGPUCore.getCanvas(:GLFW)
			renderer = getRenderer(scene)
		end
		attachEventSystem(renderer)
		splatDataCopy = WGPUCore.readBuffer(scene.gpuDevice, pc.splatBuffer, 0, pc.splatBuffer.size)
		gsplatInCopy = reinterpret(WGSLTypes.GSplatIn, splatDataCopy)
		sortIdxs = sortperm(gsplatInCopy, by=x->x.pos[3])
		gsplatInSorted = gsplatInCopy[sortIdxs]
		storageData = reinterpret(UInt8, gsplatInSorted)
		WGPUCore.writeBuffer(
			scene.gpuDevice.queue,
			pc.splatBuffer,
			storageData[:],
		)
		while !WindowShouldClose(scene.canvas.windowRef[])
			runApp(renderer)
			PollEvents()
		end
	catch e
		@info e
	finally
		detachEventSystem(renderer)
		WGPUCore.destroyWindow(scene.canvas)
		GLFW.Terminate()
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	mainApp()
else
	mainApp()
end



