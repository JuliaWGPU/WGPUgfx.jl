module WGPUgfx

using LinearAlgebra
using WGPUCore

using Reexport

@reexport using WGSLTypes

include("shaders.jl")
include("primitives.jl")
include("scene.jl")
include("events.jl")

using GeometryBasics
using GeometryBasics: Vec2, Vec3, Vec4, Mat2, Mat3, Mat4, SMatrix, SVector

export @builtin, @location, wgslType, @var, @letvar,
	makePaddedWGSLStruct, makePaddedStruct, makeStruct,
	StorageVar, UniformVar, PrivateVar, BuiltIn, BuiltInDataType, BuiltinValue,
	Location, LocationDataType, Vec2, Vec3, Vec4, Mat2, Mat3, Mat4, SMatrix, SVector,
	getVertexBuffer, getUniformBuffer, getTextureView, getIndexBuffer, writeTexture,
	getUniformData, defaultUniformData, defaultCube, getVertexBufferLayout,
	composeShader, Scene, getShaderCode, defaultCamera, Camera, defaultVision, Vision, defaultCube, Cube,
	setup, runApp, getBindingLayouts, getBindings, defaultPlane, Plane, defaultTriangle3D,
	Triangle3D, defaultCircle, Circle, defaultLighting, Lighting, defaultWGPUMesh,
	addObject!, attachEventSystem

end
