using WGPUgfx
using WGPUCore
using AbstractTrees
using DataStructures

export WorldNode, print_tree, preparePipeline, prepareObject

mutable struct WorldNode{T<:Renderable} <: Renderable
	parent::Union{Nothing, T}
	object::Union{Nothing, T}
	childObjs::Union{Nothing, Vector{T}}
end

WGPUgfx.isTextureDefined(wo::WorldNode{T}) where T<:Renderable = isTextureDefined(wo.object)
WGPUgfx.isTextureDefined(::Type{WorldNode{T}}) where T<:Renderable = isTextureDefined(T)
WGPUgfx.isNormalDefined(wo::WorldNode{T}) where T<:Renderable = isNormalDefined(wo.object)
WGPUgfx.isNormalDefined(::Type{WorldNode{T}}) where T<:Renderable = isNormalDefined(T)


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
	rType = node.object.rType
	println(io, " rObj : $(renderObj)")
	println(io, " rType : $(rType)")
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
	WGPUgfx.compileShaders!(gpuDevice, scene, wn.object; binding=binding)
	for node in wn.childObjs
		WGPUgfx.compileShaders!(gpuDevice, scene, node; binding=binding)
	end
end

function WGPUgfx.prepareObject(gpuDevice, wn::WorldNode)
	WGPUgfx.prepareObject(gpuDevice, wn.object)
	for node in wn.childObjs
		WGPUgfx.prepareObject(gpuDevice, node)
	end
end

function WGPUgfx.preparePipeline(gpuDevice, scene, wn::WorldNode; binding=2)
	WGPUgfx.preparePipeline(gpuDevice, scene, wn.object; binding=binding)
	for node in wn.childObjs
		WGPUgfx.preparePipeline(gpuDevice, scene, node; binding=binding)
	end
end

function WGPUgfx.render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, wn::WorldNode)
	WGPUgfx.render(renderPass, renderPassOptions, wn.object)
	for node in wn.childObjs
		WGPUgfx.render(renderPass, renderPassOptions, node)
	end
end

