using WGPUNative
using WGPUCore
using Rotations
using CoordinateTransformations
using LinearAlgebra
using StaticArrays
using GeometryBasics: Mat4

export Scene, composeShader, defaultCamera, Camera, defaultCube,
	defaultPlane, Plane, Cube, Triangle3D, defaultTriangle3D,
	defaultCircle, Circle, setup, runApp, defaultLighting, Lighting,
	defaultWGPUMesh, addObject!

mutable struct Scene
	gpuDevice
	canvas
	cameraSystem::CameraSystem
	cameraId::Int					# TODO cameras
	light						# TODO lights
	objects 					# ::Union{WorldObject, ObjectGroup}
	presentContext
	depthTexture				# Not sure if this should be part of scene
	depthView					# same here
	renderTextureFormat

	function Scene()
		canvas = WGPUCore.defaultCanvas(WGPUCore.WGPUCanvas)
		gpuDevice = WGPUCore.getDefaultDevice();
		camera = defaultCamera()
		light = defaultLighting()
		cameraSystem = CameraSystem([])
		addCamera!(cameraSystem, camera)
		return new(gpuDevice, canvas, cameraSystem, 1, light, [], repeat([nothing,], 4)...)
	end
end

function Base.getproperty(scene::Scene, x::Symbol)
	if x == :camera
		return scene.cameraSystem[scene.cameraId]
	end
	getfield(scene, x)
end

# TODO viewport dependent addObject
function addObject!(scene, obj)
	push!(scene.objects, obj)
	# for camera in scene.cameraSystem
		# push!(scene.objects[Symbol(:camera, camera.id)], copy(obj)) # TODO just id is enough
	# end
	setup(scene)
end

addCamera!(scene, camera::Camera) = addCamera!(scene.cameraSystem, camera)
# addLight!(scene, light::Light) = addLight!(scene.lightSystem, light)

function getDefaultSrc(scene::Scene, isLight::Bool, isTexture::Bool)
	src = quote end

	push!(src.args, getShaderCode(scene.camera; binding=0))
	isLight && push!(src.args, getShaderCode(scene.light; binding= 1))
	
	return src
end

function compileShaders!(gpuDevice, scene::Scene, object::Renderable; binding=3)
	isLight = isNormalDefined(object) && scene.light != nothing 
	
	isTexture =  isTextureDefined(object) && object.textureData != nothing

	src = getDefaultSrc(scene, isLight, isTexture)
	push!(src.args, getShaderCode(object; binding = binding))
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

function compileShaders!(gpuDevice, scene::Scene, object::WorldObject; binding=3)
	objType = typeof(object)
	for fieldIdx in 1:fieldcount(WorldObject)
		fName = fieldname(objType, fieldIdx)
		fType = fieldtype(objType, fieldIdx)
		if (fType >: Renderable || fType <: Renderable)
			(fName == :wireFrame) &&
				isRenderType(object.rType, WIREFRAME) && object.wireFrame == nothing &&
					setfield!(object, :wireFrame, defaultWireFrame(object.renderObj))
			(fName == :bbox) &&
				isRenderType(object.rType, BBOX) && object.bbox == nothing &&
					setfield!(object, :bbox, defaultBBox(object.renderObj))
			(fName == :axis) &&
				isRenderType(object.rType, AXIS) && object.axis == nothing &&
					setfield!(object, :axis, defaultAxis(;len=0.1))
			(fName == :select) && 
				isRenderType(object.rType, SELECT) && object.select == nothing &&
					setfield!(object, :select, defaultBBox(object.renderObj))

			obj = getfield(object, fName)

			if obj == nothing
				continue
			end
			
			isLight = isNormalDefined(obj) && scene.light != nothing 
			isTexture = isTextureDefined(obj) && obj.textureData != nothing

			src = getDefaultSrc(scene, isLight, isTexture)
			push!(src.args, getShaderCode(obj; binding = binding))
			try
				cshader = createShaderObj(gpuDevice, src; savefile=false)
				setfield!(obj, :cshader, cshader)
				@info  cshader.src "WorldObject"
			catch(e)
				@info "Caught Exception in WorldObject :compileShaders!" e
				rethrow(e)
			end
		# else
			# Currently this ignore RenderType field within WorldObject 
			# @error objType fName fType
		end
	end
	return nothing
end

setup(scene) = setup(scene.gpuDevice, scene)

function setup(gpuDevice, scene)
	scene.renderTextureFormat = WGPUCore.getPreferredFormat(scene.canvas)
	presentContext = WGPUCore.getContext(scene.canvas)
	WGPUCore.determineSize(presentContext)
	WGPUCore.config(presentContext, device=gpuDevice, format = scene.renderTextureFormat)
	scene.presentContext = presentContext
	
	preparedCamera = false
	preparedLight = false

	binding = 2

	for (idx, object) in enumerate(scene.objects)
		compileShaders!(gpuDevice, scene, object; binding=binding)
		if !preparedCamera
			prepareObject(gpuDevice, scene.camera)
			scene.camera.up = [0, 1, 0] .|> Float32
			scene.camera.eye = ([0.0, 0, 4.0] .|> Float32)
			preparedCamera = true
		end
		if !preparedLight
			if (typeof(object) <: WorldObject && isRenderType(object.rType, SURFACE)) || isNormalDefined(object)
				prepareObject(gpuDevice, scene.light)
				preparedLight = true
			end
		end
		prepareObject(gpuDevice, object)
		preparePipeline(gpuDevice, scene, object; binding=binding)
	end
end

runApp(scene) = runApp(scene.gpuDevice, scene)

function runApp(gpuDevice, scene)
	currentTextureView = WGPUCore.getCurrentTexture(scene.presentContext);
	cmdEncoder = WGPUCore.createCommandEncoder(gpuDevice, "CMD ENCODER")

	scene.depthTexture = WGPUCore.createTexture(
		gpuDevice,
		"DEPTH TEXTURE",
		(scene.canvas.size..., 1),
		1,
		1,
		WGPUTextureDimension_2D,
		WGPUTextureFormat_Depth24Plus,
		WGPUCore.getEnum(WGPUCore.WGPUTextureUsage, "RenderAttachment")
	)
	
	scene.depthView = WGPUCore.createView(scene.depthTexture)

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
					:view => scene.depthView,
					:depthClearValue => 1.0f0,
					:depthLoadOp => WGPULoadOp_Clear,
					:depthStoreOp => WGPUStoreOp_Store,
					:stencilLoadOp => WGPULoadOp_Clear,
					:stencilStoreOp => WGPUStoreOp_Store,
				]
			]
		]
	]

	renderPass = WGPUCore.beginRenderPass(cmdEncoder, renderPassOptions |> Ref; label= "BEGIN RENDER PASS")

	# TODO idea default viewport 0
	for object in scene.objects
		render(renderPass, renderPassOptions, object)
	end


	# TODO and support multiple viewports
	# WGPUCore.setViewport(renderPass, 150, 150, 300, 300, 0, 1)
	# for object in scene.objects
		# render(renderPass, renderPassOptions, object)
	# end

	WGPUCore.endEncoder(renderPass)


	WGPUCore.submit(gpuDevice.queue, [WGPUCore.finish(cmdEncoder),])
	WGPUCore.present(scene.presentContext)

	# for object in scene.objects
		# # WGPUCore.destroy(object.renderPipeline)
		# # for prop in propertynames(object)
			# # @info typeof(object) prop
			# # if prop in [:uniformBuffer, :vertexBuffer, :indexBuffer, :renderPipeline]
				# # continue
			# # elseif WGPUCore.isDestroyable(getfield(object, prop))
				# # @warn typeof(object) prop "Destroying"
				# # WGPUCore.destroy(getfield(object, prop))
			# # end
		# # end
	# end

	WGPUCore.destroy(scene.depthView)
	WGPUCore.destroy(scene.depthView.texture[])

end

