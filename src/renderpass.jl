abstract type AbstractRenderPass end

struct FullScreenRenderPass
    name::String
    texView
    depthView
end

struct DepthRenderPass end

struct ShadowRenderPass end

struct StereoRenderPass end

function getRenderPassOptions(renderPass::abstractRenderPass)
    currentTextureView = WGPUCore.getCurrentTexture(renderer.presentContext);
    depthTexture = WGPUCore.createTexture(
		gpuDevice,
		"DEPTH TEXTURE",
		(scene.canvas.size..., 1),
		1,
		1,
		WGPUTextureDimension_2D,
		WGPUTextureFormat_Depth24Plus,
		WGPUCore.getEnum(WGPUCore.WGPUTextureUsage, "RenderAttachment")
	)

    depthView = WGPUCore.createView(scene.depthTexture)

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



