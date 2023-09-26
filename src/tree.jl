
mutable struct TreeNode <: Renderable
	parent::Union{Nothing, Renderable}
	object::Union{Nothing, Renderable}
	childObjs::Union{Nothing, Vector{Renderable}}
end


function addChild!(tNode::TreeNode, obj::Renderable)
	if (tNode.childObjs == nothing)
		tNode.childObjs = []
	end
	push!(tNode.childObjs, obj)
end

function removeChild!(tNode::TreeNode, obj::Renderable)
	for (idx, node) in enumerate(tNode.childObjs)
		if obj == node
			popat!(tNode.childObjs, idx)
		end
	end
end

function setTransform!(tNode::TreeNode, t)
	tNode.object.uniformData = t
	if tNode.childObjs == nothing
		return
	end
	for node in tNode.childObjs
		node.uniformData = t
	end
end

tree = TreeNode(nothing, nothing, Renderable[])
