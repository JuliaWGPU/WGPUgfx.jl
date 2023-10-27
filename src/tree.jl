using WGPUgfx
using WGPUCore
using AbstractTrees
using DataStructures

export WorldNode, preparePipeline, prepareObject

mutable struct WorldNode{T<:Renderable} <: Renderable
	parent::Union{Nothing, T}
	object::Union{Nothing, T}
	childObjs::Union{Nothing, Vector{T}}
end

isTextureDefined(wo::WorldNode{T}) where T<:Renderable = isTextureDefined(wo.object)
isTextureDefined(::Type{WorldNode{T}}) where T<:Renderable = isTextureDefined(T)
isNormalDefined(wo::WorldNode{T}) where T<:Renderable = isNormalDefined(wo.object)
isNormalDefined(::Type{WorldNode{T}}) where T<:Renderable = isNormalDefined(T)

Base.setproperty!(wn::WorldNode{T}, f::Symbol, v) where T<:Renderable = begin
	(f in fieldnames(wn |> typeof)) ?
		setfield!(wn, f, v) :
		setfield!(wn.object, f, v)
end

Base.getproperty(wn::WorldNode{T}, f::Symbol) where T<:Renderable = begin
	(f in fieldnames(wn |> typeof)) ?
		getfield(wn, f) :
		getfield(wn.object, f)
end

AbstractTrees.children(t::WorldNode) = t.childObjs

function Base.show(io::IO, mime::MIME{Symbol("text/plain")}, node::WorldNode)
	summary(io, node)
	print(io, "\n")
	renderObj = (node.object != nothing) ? (node.object.renderObj |> typeof) : nothing
	println(io, " rObj : $(renderObj)")
end


AbstractTrees.printnode(io::IO, node::WorldNode) = Base.show(io, MIME{Symbol("text/plain")}(), node)

function setObject!(tNode::WorldNode, obj::Renderable)
	setfield!(tNode, :object, obj)
end

function addChild!(tNode::WorldNode, obj::Union{WorldNode, Renderable})
	if (tNode.childObjs == nothing)
		tNode.childObjs = []
	end
	if obj in tNode.childObjs
		return
	end
	if typeof(obj) <: WorldNode
		push!(tNode.childObjs, obj)
	elseif typeof(obj) <: Renderable
		push!(tNode.childObjs, WorldNode(tNode, obj, Renderable[]))
	end
end

function removeChild!(tNode::WorldNode, obj::Renderable)
	for (idx, node) in enumerate(tNode.childObjs)
		if obj == node
			popat!(tNode.childObjs, idx)
		end
	end
end

function compileShaders!(gpuDevice, scene::Scene, wn::WorldNode; binding=3)
	compileShaders!(gpuDevice, scene, wn.object; binding=binding)
	for node in wn.childObjs
		compileShaders!(gpuDevice, scene, node; binding=binding)
	end
end

function prepareObject(gpuDevice, wn::WorldNode)
	prepareObject(gpuDevice, wn.object)
	for node in wn.childObjs
		prepareObject(gpuDevice, node)
	end
end

function preparePipeline(gpuDevice, scene, wn::WorldNode; binding=2)
	preparePipeline(gpuDevice, scene, wn.object; binding=binding)
	for node in wn.childObjs
		preparePipeline(gpuDevice, scene, node; binding=binding)
	end
end

function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, wn::WorldNode)
	render(renderPass, renderPassOptions, wn.object)
	for node in wn.childObjs
		render(renderPass, renderPassOptions, node)
	end
end
