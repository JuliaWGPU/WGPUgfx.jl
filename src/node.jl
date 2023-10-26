using CEnum

export WorldObject, render

mutable struct WorldObject{T<:Renderable} <: Renderable
	renderObj::T
	rType::RenderType
	wireFrame::Union{Nothing, Renderable}
	bbox::Union{Nothing, Renderable}
	axis::Union{Nothing, Renderable}
	select::Union{Nothing, Renderable}
end

function renderableCount(mesh::WorldObject{T}) where T<:Renderable
	meshType = typeof(mesh)
	fieldTypes = fieldtypes(meshType)
	count((x)-> x>:Renderable, fieldTypes)
end

Base.setproperty!(wo::WorldObject{T}, f::Symbol, v) where T<:Renderable = begin
	(f in fieldnames(wo |> typeof)) ?
		setfield!(wo, f, v) :
		setfield!(wo.renderObj, f, v)
	if isRenderType(wo.rType, SURFACE) && wo.renderObj != nothing
		setfield!(wo.renderObj, :uniformData, f==:uniformData ? v : computeUniformData(wo.renderObj))
		updateUniformBuffer(wo.renderObj)
	end
	if isRenderType(wo.rType, WIREFRAME) && wo.wireFrame != nothing
		setfield!(wo.wireFrame, :uniformData, f==:uniformData ? v : computeUniformData(wo.wireFrame))
		updateUniformBuffer(wo.wireFrame)
	end
	if isRenderType(wo.rType, BBOX) && wo.bbox != nothing
		setfield!(wo.bbox, :uniformData, f==:uniformData ? v : computeUniformData(wo.bbox))
		updateUniformBuffer(wo.bbox)
	end
	if isRenderType(wo.rType, AXIS) && wo.axis != nothing
		setfield!(wo.axis, :uniformData, f==:uniformData ? v : computeUniformData(wo.axis))
		updateUniformBuffer(wo.axis)
	end
	if isRenderType(wo.rType, SELECT) && wo.select != nothing
		setfield!(wo.select, :uniformData, f==:uniformData ? v : computeUniformData(wo.select))
		updateUniformBuffer(wo.select)
	end
end

Base.getproperty(wo::WorldObject{T}, f::Symbol) where T<:Renderable = begin
	(f in fieldnames(WorldObject)) ?
		getfield(wo, f) :
		getfield(getfield(wo, :renderObj), f)
end

function prepareObject(gpuDevice, mesh::WorldObject{T}) where T<:Renderable
	isRenderType(mesh.rType, SURFACE) && mesh.renderObj != nothing &&
		prepareObject(gpuDevice, mesh.renderObj)
	isRenderType(mesh.rType, WIREFRAME) && mesh.wireFrame!=nothing &&
		prepareObject(gpuDevice, mesh.wireFrame)
	isRenderType(mesh.rType, BBOX) && mesh.bbox != nothing &&
		prepareObject(gpuDevice, mesh.bbox)
	isRenderType(mesh.rType, AXIS) && mesh.axis != nothing &&
		prepareObject(gpuDevice, mesh.axis)
	isRenderType(mesh.rType, SELECT) && mesh.select != nothing &&
		prepareObject(gpuDevice, mesh.select)
end

function preparePipeline(gpuDevice, scene, mesh::WorldObject{T}; binding=0) where T<:Renderable
	isRenderType(mesh.rType, SURFACE) && mesh.renderObj != nothing && 
		preparePipeline(gpuDevice, scene, mesh.renderObj; binding = binding)
	isRenderType(mesh.rType, WIREFRAME) && mesh.wireFrame != nothing &&
		preparePipeline(gpuDevice, scene, mesh.wireFrame; binding = binding)
	isRenderType(mesh.rType, BBOX) && mesh.bbox !=nothing &&
		preparePipeline(gpuDevice, scene, mesh.bbox; binding = binding)
	isRenderType(mesh.rType, AXIS) && mesh.axis !=nothing &&
		preparePipeline(gpuDevice, scene, mesh.axis; binding = binding)
	isRenderType(mesh.rType, SELECT) && mesh.select != nothing &&
		preparePipeline(gpuDevice, scene, mesh.select; binding=binding)
end

function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, wo::WorldObject)
	if isRenderType(wo.rType, VISIBLE)
		isRenderType(wo.rType, SURFACE) && wo.renderObj != nothing &&
			render(renderPass, renderPassOptions, wo.renderObj)
		isRenderType(wo.rType, WIREFRAME) && wo.wireFrame != nothing &&
			render(renderPass, renderPassOptions, wo.wireFrame)
		isRenderType(wo.rType, BBOX) && wo.bbox != nothing &&
			render(renderPass, renderPassOptions, wo.bbox)
		isRenderType(wo.rType, AXIS) && wo.axis != nothing &&
			render(renderPass, renderPassOptions, wo.axis)
		isRenderType(wo.rType, SELECT) && wo.select != nothing &&
			render(renderPass, renderPassOptions, wo.select)
	end
end

# TODO 
# function setTransform!(wo::WorldObject, v)
			# setfield!(wo.renderObj, :uniformData, f==:uniformData ? v : computeUniformData(wo.renderObj))
		# updateUniformBuffer(wo.renderObj)
	# # end
	# if isRenderType(wo.rType, WIREFRAME) && wo.wireFrame != nothing
		# setfield!(wo.wireFrame, :uniformData, f==:uniformData ? v : computeUniformData(wo.wireFrame))
		# updateUniformBuffer(wo.wireFrame)
	# end
	# if isRenderType(wo.rType, BBOX) && wo.bbox != nothing
		# setfield!(wo.bbox, :uniformData, f==:uniformData ? v : computeUniformData(wo.bbox))
		# updateUniformBuffer(wo.bbox)
	# end
	# if isRenderType(wo.rType, AXIS) && wo.axis != nothing
		# setfield!(wo.axis, :uniformData, f==:uniformData ? v : computeUniformData(wo.axis))
		# updateUniformBuffer(wo.axis)
	# end
	# if isRenderType(wo.rType, SELECT) && wo.select != nothing
		# setfield!(wo.select, :uniformData, f==:uniformData ? v : computeUniformData(wo.select))
		# updateUniformBuffer(wo.select)
	# end
# 
# end
