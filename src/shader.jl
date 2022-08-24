module ShaderMod

using WGPU_jll
using WGPU
using Reexport

include("macros.jl")
include("primitives.jl")


using .MacroMod
using .MacroMod: wgslCode

@reexport using .PrimitivesMod

export createShaderObj

struct ShaderObj
	src
	internal
	descriptor
end


function createShaderObj(gpuDevice, shaderSource)
	shaderSource = shaderSource |> wgslCode 
	shaderBytes  = shaderSource |> Vector{UInt8}

	descriptor = WGPU.loadWGSL(shaderBytes) |> first

	ShaderObj(
		shaderSource,
		WGPU.createShaderModule(
			gpuDevice,
			"shaderCode",
			descriptor,
			nothing,
			nothing
		) |> Ref,
		descriptor
	)

end

end
