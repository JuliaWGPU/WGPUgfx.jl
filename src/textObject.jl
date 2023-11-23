using CEnum

export TextObject, render, TextRenderType

@cenum TextRenderType begin
	BOUNDS = 1
	TEXT = 2
end

isTextRenderType(rtype::TextRenderType, vtype::TextRenderType) = (rtype & vtype) == vtype

mutable struct TextObject{T<:RenderableUI} <: RenderableUI
	renderObj::T
	rType::TextRenderType
	text::Union{Nothing, RenderableUI}
	bounds::Union{Nothing, RenderableUI}
end

isTextureDefined(wo::TextObject{T}) where T<:RenderableUI = isTextureDefined(T)
isTextureDefined(::Type{TextObject{T}}) where T<:RenderableUI = isTextureDefined(T)
isNormalDefined(wo::TextObject{T}) where T<:RenderableUI = isNormalDefined(T)
isNormalDefined(::Type{TextObject{T}}) where T<:RenderableUI = isNormalDefined(T)

function renderableCount(mesh::TextObject{T}) where T<:RenderableUI
	meshType = typeof(mesh)
	fieldTypes = fieldtypes(meshType)
	count((x)-> x>:RenderableUI, fieldTypes)
end

Base.setproperty!(wo::TextObject{T}, f::Symbol, v) where T<:RenderableUI = begin
	(f in fieldnames(wo |> typeof)) ?
		setfield!(wo, f, v) :
		setfield!(wo.renderObj, f, v)
	if isTextRenderType(wo.rType, BOUNDS) && wo.renderObj !== nothing
		setfield!(wo.renderObj, :uniformData, f==:uniformData ? v : computeUniformData(wo.renderObj))
		updateUniformBuffer(wo.renderObj)
	end
	if isTextRenderType(wo.rType, TEXT) && wo.wireFrame !== nothing
		setfield!(wo.wireFrame, :uniformData, f==:uniformData ? v : computeUniformData(wo.wireFrame))
		updateUniformBuffer(wo.wireFrame)
	end
end

Base.getproperty(wo::TextObject{T}, f::Symbol) where T<:RenderableUI = begin
	(f in fieldnames(TextObject)) ?
		getfield(wo, f) :
		getfield(getfield(wo, :renderObj), f)
end

function prepareObject(gpuDevice, mesh::TextObject{T}) where T<:RenderableUI
	isTextRenderType(mesh.rType, BOUNDS) && mesh.renderObj !== nothing &&
		prepareObject(gpuDevice, mesh.renderObj)
	isTextRenderType(mesh.rType, TEXT) && mesh.wireFrame !== nothing &&
		prepareObject(gpuDevice, mesh.wireFrame)
end

function preparePipeline(gpuDevice, scene, mesh::TextObject{T}; binding=0) where T<:RenderableUI
	isTextRenderType(mesh.rType, BOUNDS) && mesh.renderObj !== nothing && 
		preparePipeline(gpuDevice, scene, mesh.renderObj; binding = binding)
	isTextRenderType(mesh.rType, TEXT) && mesh.wireFrame !== nothing &&
		preparePipeline(gpuDevice, scene, mesh.wireFrame; binding = binding)
end

function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, wo::TextObject, camId::Int)
	if isTextRenderType(wo.rType, VISIBLE)
		isTextRenderType(wo.rType, BOUNDS) && wo.renderObj !== nothing &&
			render(renderPass, renderPassOptions, wo.renderObj, camId)
		isTextRenderType(wo.rType, TEXT) && wo.wireFrame !== nothing &&
			render(renderPass, renderPassOptions, wo.wireFrame, camId)
	end
end

