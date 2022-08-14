module PrimitivesMod

using LinearAlgebra
export getVertexBufferLayout, getUniformBuffer, getVertexBuffer, getIndexBuffer, 
		defaultUniformData, getUniformData, getBindingLayouts, getBindings,
		getShaderCode

flatten(x) = reshape(x, (:,))

using WGPU_jll
using WGPU

for (root, dirs, files) in walkdir(joinpath(@__DIR__,"primitives"))
	for file in files
		include(joinpath(root, file))
	end
end

end
