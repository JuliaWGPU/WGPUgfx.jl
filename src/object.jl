@cenum RenderType begin
	VISIBLE = 1
	SURFACE = 2
	WIREFRAME = 4
	BBOX = 8
	SELECT = 16
end

isRenderType(rtype::RenderType, vtype::RenderType) = (rtype & vtype) == vtype

struct WorldObject{T<:Renderable}
	renderable::T
	rType::RenderType
	wireFrame::Renderable
	bbox::Renderable
	select::Renderable
end


function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, wo::WorldObject)
	if isRenderType(wo.rType, VISIBLE)
		if isRenderType(wo.rType, SURFACE)
			render(renderPass, renderPassOptions, wo.renderable)
		elseif isRenderType(wo.rType, WIREFRAME)
			if wo.wireFrame == nothing
				wo.wireFrame = defaultWireFrame(wo.renderable)
			end
			render(renderPass, renderPassOptions, wo.wireFrame)
		elseif isRenderType(wo.rType, BBOX)
			if wo.bbox == nothing
				wo.bbox = defaultBBox(wo.renderable)
			end
			render(renderPass, renderPassOptions, wo.bbox)
		elseif isRenderType(wo.rType, SELECT)
			if wo.select == nothing
				wo.select = defaultBBox(wo.renderable) # TODO temporarity BBOX
			end
			render(renderPass, renderPassOptions, wo.select)
		end
	end
end
