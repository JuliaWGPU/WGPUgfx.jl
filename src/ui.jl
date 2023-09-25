using WGPUNative
using WGPUCore

include("renderable.jl")

for (root, dirs, files) in walkdir(joinpath(@__DIR__,"ui"))
	for file in files
		include(joinpath(root, file))
	end
end

