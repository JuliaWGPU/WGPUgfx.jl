module WGPUgfx

using LinearAlgebra
using WGPU

include("structutils.jl")

using GeometryBasics
using GeometryBasics: Vec2, Vec3, Vec4, Mat2, Mat3, Mat4, SMatrix, SVector

using .StructUtilsMod
using .StructUtilsMod: UniformVar, StorageVar, PrivateVar, BuiltIn, BuiltinValue, BuiltInDataType

export @builtin, @location, wgslType,
	makePaddedWGSLStruct, makePaddedStruct,
	StorageVar, UniformVar, PrivateVar, BuiltIn, BuiltInDataType, BuiltinValue,
	Location, LocationDataType, Vec2, Vec3, Vec4, Mat2, Mat3, Mat4, SMatrix, SVector
end
