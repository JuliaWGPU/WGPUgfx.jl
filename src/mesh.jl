module WGPUMeshMod

using WGPU_jll

mutable struct Mesh
	primitiveTopology::WGPUPrimitiveTopology
	attributes::Dict{Symbol, Any}
	indices
end

end

