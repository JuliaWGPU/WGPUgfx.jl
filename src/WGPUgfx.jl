module WGPUgfx

using WGPUCanvas
using LinearAlgebra
using WGPUCore
using MacroTools

using Reexport

@reexport using WGSLTypes

include("types.jl")
# Type registration is handled in shader generation

include("utils.jl")
include("shaders.jl")
include("primitives.jl")
include("primitivesUI.jl")

include("system.jl")
include("scene.jl")

include("worldObject.jl")
include("textObject.jl")
include("text.jl")
include("tree.jl")
include("renderer.jl")
include("events.jl")

using GeometryBasics
using GeometryBasics: Vec2, Vec3, Vec4, Mat2, Mat3, Mat4, SMatrix, SVector

export @builtin, @location, wgslType, @var, @letvar,
	makePaddedWGSLStruct, makePaddedStruct, makeStruct,
	StorageVar, UniformVar, PrivateVar, BuiltIn, BuiltInDataType, BuiltinValue,
	Location, LocationDataType, Vec2, Vec3, Vec4, Mat2, Mat3, Mat4, SMatrix, SVector,
	getVertexBuffer, getUniformBuffer, getTextureView, getIndexBuffer, writeTexture,
	getUniformData, defaultUniformData, defaultCube, getVertexBufferLayout,
	composeShader, Scene, getShaderCode, defaultCamera, Camera, defaultCube, Cube,
	setup, runApp, getBindingLayouts, getBindings, defaultPlane, Plane, defaultTriangle3D,
	Triangle3D, defaultCircle, Circle, defaultLighting, Lighting, defaultWGPUMesh,
	addObject!, addObjects!, attachEventSystem, RenderType, SURFACE, AXIS, VISIBLE, WIREFRAME, BBOX, SELECT, WorldObject, Renderable,
	CameraUniform, LightingUniform, convertToMatrix, ensureSMatrix, isValidMatrix, convertMatrixToSMatrix
end
