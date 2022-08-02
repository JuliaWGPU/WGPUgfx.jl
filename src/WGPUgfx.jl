module WGPUgfx

using LinearAlgebra
using WGPU

include("structutils.jl")

using .StructUtilsMod

export @builtin, @location, wgslType

end
