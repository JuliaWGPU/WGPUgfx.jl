module PrimitivesMod

using LinearAlgebra
export getVertexBufferLayout, getUniformBuffer, getVertexBuffer, getIndexBuffer, 
		defaultUniformData, getUniformData, defaultCube, defaultShader

flatten(x) = reshape(x, (:,))

using WGPU_jll
using WGPU

include("primitiveCube.jl")


end
