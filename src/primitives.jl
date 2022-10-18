
using LinearAlgebra
export getVertexBufferLayout, getUniformBuffer, getVertexBuffer, getIndexBuffer, 
		defaultUniformData, getUniformData, getBindingLayouts, getBindings,
		getShaderCode, prepareObject, preparePipeline, render

flatten(x) = reshape(x, (:,))

using WGPUNative
using WGPUCore

for (root, dirs, files) in walkdir(joinpath(@__DIR__,"primitives"))
	for file in files
		include(joinpath(root, file))
	end
end

