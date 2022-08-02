module WGPUgfx

using LinearAlgebra
using WGPU

include("structutils.jl")

using GeometryBasics
using GeometryBasics: Vec2, Vec3, Vec4, Mat2, Mat3, Mat4, SMatrix, SVector

using .StructUtilsMod

export @builtin, @location, wgslType,
	makePaddedWGSLStruct, makePaddedStruct
	
end
