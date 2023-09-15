
abstract type ArraySystem <: Renderable end


using MacroTools
using MacroTools: @forward

include("camerasystem.jl")
include("lightsystem.jl")
