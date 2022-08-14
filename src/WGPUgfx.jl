
module WGPUgfx

using LinearAlgebra
using WGPU

include("structutils.jl")
include("macros.jl")
include("scene.jl")

using .MacroMod
using .SceneMod

using GeometryBasics
using GeometryBasics: Vec2, Vec3, Vec4, Mat2, Mat3, Mat4, SMatrix, SVector

using .StructUtilsMod
using .StructUtilsMod: UniformVar, StorageVar, PrivateVar, 
		BuiltIn, BuiltinValue, BuiltInDataType, 
		makePaddedStruct, makePaddedWGSLStruct, makeStruct

export @builtin, @location, wgslType, @var, @letvar,
	makePaddedWGSLStruct, makePaddedStruct, makeStruct,
	StorageVar, UniformVar, PrivateVar, BuiltIn, BuiltInDataType, BuiltinValue,
	Location, LocationDataType, Vec2, Vec3, Vec4, Mat2, Mat3, Mat4, SMatrix, SVector,
	getVertexBuffer, getUniformBuffer, getTextureView, getIndexBuffer, writeTexture,
	getUniformData, defaultUniformData, defaultCube, getVertexBufferLayout,
	composeShader, Scene, getShaderCode, defaultCamera, defaultCube, Camera, Cube,
	setup, runApp, getBindingLayouts, getBindings
	
end
