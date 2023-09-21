struct Viewport
    # camera::Camera
    renderPasses::Array{GPURenderPassEncoder}
    x::Number
    y::Number
    width::Number
    height::Number
    minDepth::Number
    maxDepth::Number
end

function render(cmdEncoder, viewport::Viewport, scene::Scene)
    WGPUCore.setViewport(
            renderPass, 
            viewport.x,
            viewport.y,
            viewport.width,
            viewport.height,
            viewport.minDepth,
            viewport.maxDepth
        )
    for pass in viewport.renderPasses
        render(cmdEncoder, pass, scene)
    end
end

function render(cmdEncoder, renderPass:RenderPass, scene)
    renderPassOptions = getRenderPassOptions(renderPass)
    renderPass = WGPUCore.beginRenderPass(cmdEncoder, renderPassOptions |> Ref; label= renderPass.name)

	for object in scene.objects
		render(renderPass, renderPassOptions, object)
	end

	WGPUCore.endEncoder(renderPass)
end



