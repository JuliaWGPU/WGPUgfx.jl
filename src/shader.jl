module ShaderMod

using WGPU_jll
using WGPU

include("macros.jl")

using .MacroMod
using .MacroMod: wgslCode


struct ShaderObj
	src
	internal
	descriptor
end


function defaultShader(gpuDevice)
	shaderSource = quote
		struct Locals
			transform::Mat4{Float32}
		end

		@var Uniform 0 0 rLocals::@user Locals
		
		struct VertexInput
			@location 0 pos::Vec4{Float32}
			@location 1 texcoord::Vec2{Float32}
		end
		
		struct VertexOutput
			@location 0 texcoord::Vec2{Float32}
			@builtin position pos::Vec4{Float32}
		end
		
		@vertex function vs_main(in::@user VertexInput)::@user VertexOutput
			@let ndc::Vec4{Float32} = rLocals.transform*in.pos
			@var out::@user VertexOutput
			out.pos = Vec4{Float32}(ndc.x, ndc.y, 0.0, 1.0)
			out.texcoord = in.texcoord
			return out
		end
		
		@var Generic 0 1 rTex::Texture2D{Float32}
		@var Generic 0 2 rSampler::Sampler
		
		@fragment function fs_main(in::@user VertexOutput)::@location 0 Vec4{Float32}
			@let value = textureSample(rTex, rSampler, in.texcoord).r;
			return Vec4{Float32}(value, value, value, 1.0)
		end
	end |> wgslCode |> Vector{UInt8}

	# TODO this needs to be changed
	# loadWGSL is awkward name. Shoulde be called descriptor
	descriptor = WGPU.loadWGSL(shaderSource) |> first; 
	
	ShaderObj(
		shaderSource, 
		WGPU.createShaderModule(
			gpuDevice, 
			"shadercode", 
			descriptor, 
			nothing, 
			nothing
		) |> Ref,
		descriptor
	)
end

function createShaderObj(gpuDevice, shaderSource)
	descriptor = WGPU.loadWGSL(shaderSource) |> first

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


function default2DShader(gpuDevice)
	shaderSource = quote
		struct Locals
			transform::Mat4{Float32}
		end

		@var Uniform 0 0 rLocals::@user Locals
		
		struct VertexInput
			@location 0 pos::Vec4{Float32}
			@location 1 texcoord::Vec2{Float32}
		end
		
		struct VertexOutput
			@location 0 texcoord::Vec2{Float32}
			@builtin position pos::Vec4{Float32}
		end
		
		@vertex function vs_main(in::@user VertexInput)::@user VertexOutput
			@let ndc::Vec4{Float32} = rLocals.transform*in.pos
			@var out::@user VertexOutput
			out.pos = Vec4{Float32}(ndc.x, ndc.y, 0.0, 1.0)
			out.texcoord = in.texcoord
			return out
		end
		
		@var Generic 0 1 rTex::Texture2D{Float32}
		@var Generic 0 2 rSampler::Sampler
		
		@fragment function fs_main(in::@user VertexOutput)::@location 0 Vec4{Float32}
			@let value = textureSample(rTex, rSampler, in.texcoord).r;
			return Vec4{Float32}(value, value, value, 1.0)
		end
	end |> wgslCode |> Vector{UInt8}

	# TODO this needs to be changed
	# loadWGSL is awkward name. Shoulde be called descriptor
	descriptor = WGPU.loadWGSL(shaderSource) |> first; 
	
	ShaderObj(
		shaderSource, 
		WGPU.createShaderModule(
			gpuDevice, 
			"shadercode", 
			descriptor, 
			nothing, 
			nothing
		),
		descriptor
	)
end

end
