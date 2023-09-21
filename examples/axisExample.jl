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

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Off)

axis = defaultAxis()

scene = Scene()

mutable struct Renderer
	scene
	presentContext
	currentTextureView
	cmdEncoder
	depthTexture
	depthView
	renderPass
	renderPassOptions
	renderTextureFormat
end

function getRenderPassOptions(currentTextureView, depthView)
	renderPassOptions = [
		WGPUCore.GPUColorAttachments => [
			:attachments => [
				WGPUCore.GPUColorAttachment => [
					:view => currentTextureView,
					:resolveTarget => C_NULL,
					:clearValue => (0.2, 0.2, 0.2, 1.0),
					:loadOp => WGPULoadOp_Clear,
					:storeOp => WGPUStoreOp_Store,
				],
			]
		],
		WGPUCore.GPUDepthStencilAttachments => [
			:attachments => [
				WGPUCore.GPUDepthStencilAttachment => [
					:view => depthView,
					:depthClearValue => 1.0f0,
					:depthLoadOp => WGPULoadOp_Clear,
					:depthStoreOp => WGPUStoreOp_Store,
					:stencilLoadOp => WGPULoadOp_Clear,
					:stencilStoreOp => WGPUStoreOp_Store,
				]
			]
		]
	]
	return renderPassOptions
end

function getRenderer(scene)
	renderTextureFormat = WGPUCore.getPreferredFormat(scene.canvas)
	presentContext = WGPUCore.getContext(scene.canvas)
	WGPUCore.determineSize(presentContext)
	WGPUCore.config(presentContext, device=scene.gpuDevice, format = renderTextureFormat)
	
	currentTextureView = WGPUCore.getCurrentTexture(presentContext);

	# depthTexture = WGPUCore.createTexture(
	# 	scene.gpuDevice,
	# 	"DEPTH TEXTURE",
	# 	(scene.canvas.size..., 1),
	# 	1,
	# 	1,
	# 	WGPUTextureDimension_2D,
	# 	WGPUTextureFormat_Depth24Plus,
	# 	WGPUCore.getEnum(WGPUCore.WGPUTextureUsage, "RenderAttachment")
	# )
	# depthView = WGPUCore.createView(depthTexture)

	# renderPassOptions = getRenderPassOptions(currentTextureView, depthView)
	# TODO we need multiple render passes

	Renderer(
		scene,
		presentContext,
		nothing, #currentTextureView,
		nothing,
		nothing, #depthTexture,
		nothing, # depthView,
		nothing,
		nothing, #renderPassOptions,
		renderTextureFormat
	)
end

renderer = getRenderer(scene)

axis1 = defaultAxis()
axis2 = defaultAxis()

camera1 = defaultCamera()
camera2 = defaultCamera()
setfield!(camera1, :id, 1)
setfield!(camera2, :id, 2)

scene.cameraSystem = CameraSystem([camera1, camera2])

function WGPUgfx.addObject!(scene, object, camera)
	push!(scene.objects, object)
	setup(renderer, object, camera)
end

function setup(renderer, object, camera)
	binding = 2 # Binding slot for objects starts from this index.
	scene = renderer.scene
	gpuDevice = scene.gpuDevice
	scene.cameraId = camera.id
	preparedLight=false
	compileShaders!(gpuDevice, scene, object; binding=binding)
	if camera.uniformBuffer === nothing
		prepareObject(gpuDevice, camera)
		camera.up = [0, 1, 0] .|> Float32
		camera.eye = ([0.0, 0.0, 4.0] .|> Float32)
	end
	if !preparedLight
		if (typeof(object) <: WorldObject && isRenderType(object.rType, SURFACE)) || isNormalDefined(object)
			prepareObject(gpuDevice, scene.light)
			preparedLight = true
		end
	end
	prepareObject(gpuDevice, object)
	preparePipeline(gpuDevice, renderer, object, camera; binding=binding)
end

function getDefaultSrc(scene::Scene, isLight::Bool, isTexture::Bool)
	src = quote end

	push!(src.args, getShaderCode(scene.cameraSystem; binding=scene.cameraId-1))
	isLight && push!(src.args, getShaderCode(scene.light; binding= 1))
	
	return src
end

function compileShaders!(gpuDevice, scene::Scene, object::Renderable; binding=3)
	isLight = isNormalDefined(object) && scene.light != nothing 
	
	isTexture =  isTextureDefined(object) && object.textureData != nothing

	src = getDefaultSrc(scene, isLight, isTexture)
	push!(src.args, getShaderCode(object, scene.cameraId; binding = binding))
	try
		cshader = createShaderObj(gpuDevice, src; savefile=false)
		setfield!(object, :cshader, cshader)
		@info  cshader.src "Renderable"
	catch(e)
		@info "Caught exception in Renderable :compileShaders!" e
		rethrow(e)
	end
	return nothing
end

addObject!(scene, axis1, camera1)
addObject!(scene, axis2, camera2)

function init(renderer)
	scene = renderer.scene
	renderSize = scene.canvas.size
	renderer.currentTextureView = WGPUCore.getCurrentTexture(renderer.presentContext) |> Ref;

	renderer.depthTexture = WGPUCore.createTexture(
		scene.gpuDevice,
		"DEPTH TEXTURE",
		(renderSize..., 1),
		1,
		1,
		WGPUTextureDimension_2D,
		WGPUTextureFormat_Depth24Plus,
		WGPUCore.getEnum(WGPUCore.WGPUTextureUsage, "RenderAttachment")
	) |> Ref
	
	renderer.depthView = WGPUCore.createView(renderer.depthTexture[]) |> Ref

	renderer.renderPassOptions = getRenderPassOptions(renderer.currentTextureView[], renderer.depthView[])

	renderer.cmdEncoder = WGPUCore.createCommandEncoder(scene.gpuDevice, "CMD ENCODER") |> Ref
	renderer.renderPass = WGPUCore.beginRenderPass(
		renderer.cmdEncoder[], 
		renderer.renderPassOptions |> Ref; 
		label= "BEGIN RENDER PASS"
	) |> Ref
end

function deinit(renderer)
	WGPUCore.endEncoder(renderer.renderPass[])
	WGPUCore.submit(scene.gpuDevice.queue, [WGPUCore.finish(renderer.cmdEncoder[]),])
	WGPUCore.present(renderer.presentContext)
	WGPUCore.destroy(renderer.depthView[])
	WGPUCore.destroy(renderer.depthView[].texture[])
	# WGPUCore.destroy(renderer.depthTexture[])
end

function render(renderer::Renderer; dims=nothing)
	if dims !== nothing
		WGPUCore.setViewport(renderer.renderPass[], dims..., 0, 1)
	end
	for object in scene.objects
		WGPUgfx.render(renderer.renderPass[], renderer.renderPassOptions, object)
	end
end

function render(renderer::Renderer, object; dims=nothing)
	if dims!==nothing
		WGPUCore.setViewport(renderer.renderPass[], dims..., 0, 1)
	end
	WGPUgfx.render(renderer.renderPass[], renderer.renderPassOptions, object)
end


function runApp(renderer)
	# TODO idea default viewport 0
	# TODO and support multiple viewports
	# render(renderer, )
	init(renderer)
	# render(renderer)
	render(renderer, scene.objects[1]; dims=(50, 50, 300, 300))
	render(renderer, scene.objects[2]; dims=(150, 150, 400, 400))
	deinit(renderer)
end


attachEventSystem(renderer)

main = () -> begin
	try
		count = 0
		camera1 = scene.cameraSystem[1]
		while !WindowShouldClose(scene.canvas.windowRef[])
			# count  += 1
			# if count > 1000
			# 	count = 0
			# 	scene.cameraId = scene.cameraId % length(scene.cameraSystem)
			# end
			rot = RotXY(0.01, 0.01)
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
