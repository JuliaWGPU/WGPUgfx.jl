

using WGPUCore
using Reexport

export createShaderObj

struct ShaderObj
	src
	internal
	info
end

function createShaderObj(gpuDevice, shaderSource; savefile=false, debug = false)
	# Make sure we have a valid expression
	if !(shaderSource isa Expr && shaderSource.head == :block)
		shaderSource = quote
			$shaderSource
		end
	end
	
	# Filter out empty expressions
	if shaderSource isa Expr
		filter!(x -> !(x isa LineNumberNode || x == nothing || (x isa Expr && isempty(x.args))), shaderSource.args)
	end
	
	# Convert to WGSL
	try
		shaderSource = (shaderSource |> wgslCode)
		shaderBytes = shaderSource |> Vector{UInt8}
	
		shaderInfo = WGPUCore.loadWGSL(shaderBytes)
	
		shaderObj = ShaderObj(
			shaderSource,
			WGPUCore.createShaderModule(
				gpuDevice,
				"shaderCode",
				shaderInfo.shaderModuleDesc,
				nothing,
				nothing
			) |> Ref,
			shaderInfo
		)
	
		if savefile || debug
			# Clean up any legacy syntax
			shaderSource = replace(shaderSource, "@stage(fragment)"=>"@fragment")
			shaderSource = replace(shaderSource, "@stage(vertex)"=>"@vertex")
			
			file = open("scratch.wgsl", "w")
			write(file, shaderSource)
			close(file)
		end
		
		return shaderObj
	catch e
		@error "Error compiling shader:" e
		
		# Always save the failed shader for debugging
		if shaderSource isa String
			file = open("shader_error.wgsl", "w")
			write(file, shaderSource)
			close(file)
		end
		
		rethrow(e)
	end
end

# Helper function to validate a shader module
function validateShader(shaderObj::ShaderObj, shaderSource::String)
	if shaderObj.internal[].internal[] == Ptr{Nothing}()
		@error "Shader module creation failed"
		@info "You can find the problematic shader in shader_error.wgsl"
		
		file = open("shader_error.wgsl", "w")
		write(file, shaderSource)
		close(file)
		
		# Try to run external naga validator if available
		try
			@info "Attempting to run naga validator..."
			output = read(`naga shader_error.wgsl`, String)
			@info "Naga output:" output
		catch e
			@warn "Failed to run naga validator: $e"
			@info "Complete shader source:"
			@info shaderSource
		end
		
		error("Shader compilation failed. See logs for details.")
	end
	
	return shaderObj
end

