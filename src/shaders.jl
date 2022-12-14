using WGPUCore
using Reexport

export createShaderObj

struct ShaderObj
	src
	internal
	descriptor
end


function createShaderObj(gpuDevice, shaderSource; savefile=false, debug = false)
	shaderSource = shaderSource |> wgslCode 
	shaderBytes  = shaderSource |> Vector{UInt8}

	descriptor = WGPUCore.loadWGSL(shaderBytes) |> first

	if savefile
		shaderSource = replace(shaderSource, "@stage(fragment)"=>"@fragment")
		shaderSource = replace(shaderSource, "@stage(vertex)"=>"@vertex")
		file = open("scratch.wgsl", "w")
		write(file, shaderSource)
		close(file)
	end
	
	shaderObj = ShaderObj(
		shaderSource,
		WGPUCore.createShaderModule(
			gpuDevice,
			"shaderCode",
			descriptor,
			nothing,
			nothing
		) |> Ref,
		descriptor
	)

	if debug
		if shaderObj.internal[].internal[] == Ptr{Nothing}()
			@error "Shader Obj creation failed"
			@info "Dumping shader to scratch.wgsl"
			shaderSource = replace(shaderSource, "@stage(fragment)"=>"@fragment")
			shaderSource = replace(shaderSource, "@stage(vertex)"=>"@vertex")
			file = open("scratch.wgsl", "w")
			write(file, shaderSource)
			close(file)
			@warn "replaced @stage location with new format"
			# TODO move scratch to scratch area with definite
			# path = joinpath(pkgdir(WGPUgfx), "scratch.wgsl")
			try
				run(`naga scratch.wgsl`)
			catch(e)
				@info shaderSource
				rethrow(e)
			end
		end
	end

	return shaderObj
end

