module StructUtilsMod

using WGPU
using WGPU: getEnum
using WGPU_jll
using Lazy: @forward

export wgslType, 
	BuiltIn, @builtin, getEnumBuiltinValue,
	makePaddedStruct, makePaddedWGSLStruct, 
	Location, @location

using StaticArrays
using GeometryBasics

include("variableDecl.jl")
using .VariableDeclMod


visibiltyRender = getEnum(WGPUShaderStage, ["Vertex", "Fragment"])

visibilityAll = getEnum(WGPUShaderStage, ["Vertex", "Fragment", "Compute"])


function alignof(::Type{T}) where T
	sz = sizeof(T)
	c = 0
	while sz != 0
		sz >>= 1
		c+=1
	end
	return 2^(count_ones(sizeof(T)) == 1 ? c-1 : c)
end

alignof(::Type{Mat2{T}}) where T = alignof(Vec2{T})
alignof(::Type{Mat3{T}}) where T = alignof(Vec3{T})
alignof(::Type{Mat4{T}}) where T = alignof(Vec4{T})

alignof(::Type{SMatrix{N, M, T, L}}) where {N, M, T, L} = alignof(Vec{M, T})


function makeStruct(name::String, fields::Array{String}; mutableType=false, abstractType="")
	line = [(mutableType ? "mutable " : "")*"struct $name"*abstractType]
	for field in fields
		push!(line, (" "^4)*field)
	end
	push!(line, "end\n")
	lineJoined = join(line, "\n")
	return Meta.parse(lineJoined) |> eval
end

function makeStruct(name::String, fields::Dict{String, String}; mutableType=false, abstractType="")
	a = [(mutableType ? "mutable " : "")*"struct $name"*abstractType]
	for (name, type) in fields
		push!(a, (" "^4)*name*"::"*type)
	end
	push!(a, "end\n")
	aJoined = join(a, "\n")
	return Meta.parse(aJoined) |> eval
end

padType = Dict(
	1 => "bool",
	2 => "vec2<bool>",
	4 => "vec4<bool>",
	8 => "vec2<u32>",
	16 => "vec4<u32>",
	32 => "mat4<f16>",
	64 => "mat4<f32>"
)


function makePaddedStruct(name::Symbol, abstractType::Union{Nothing, DataType}, fields...)
	offsets = [0,]
	prevfieldSize = 0
	fieldVector = [key=>val for (key, val) in fields...]
	padCount = 0
	for (idx, (var, field)) in enumerate(fields...)
		if idx == 1
			prevfieldSize = sizeof(field)
			continue
		end
		fieldSize = sizeof(field)
		potentialOffset = prevfieldSize + offsets[end]
		padSize = (div(potentialOffset, fieldSize, RoundUp)*fieldSize - potentialOffset) |> UInt8
		@assert padSize >= 0 "pad size should be ≥ 0"
		if padSize != 0
			# @info padSize, (potentialOffset, potentialOffset+padSize)
			sz = 0x80 # MSB
			for i in 1:(sizeof(padSize)*8)
				sz = bitrotate(sz, 1)
				if (sz & padSize) == sz
					padCount += 1
					insert!(fieldVector, idx + padCount - 1, gensym()=>padType[sz])
					# println("\t_pad_$padCount:$(padType[sz]) # implicit struct padding")
				end
			end
		end
		push!(offsets, potentialOffset + padSize)
		prevfieldSize = fieldSize
	end
	unfields = [:($key::$val) for (key, val) in fieldVector]
	absType = abstractType != nothing ? :($abstractType) : :(Any)
	quote 
		struct $name <: $absType 
			$(unfields...)
		end
	end |> eval
end

function makeStruct(name::Symbol, abstractType::Union{Nothing, DataType}, fields...)
	unfields = [:($key::$val) for (key, val) in fields...]
	absType = abstractType != nothing ? :($abstractType) : :(Any)
	quote 
		struct $name <: $absType 
			$(unfields...)
		end
	end |> eval
end


function makePaddedWGSLStruct(name::Symbol, fields)
	@assert issorted(fields |> keys) "Fields are expected to be sorted for consistency"
	offsets = [0,]
	prevfieldSize = 0
	fieldVector = [String(key)=>wgslType(val) for (key, val) in fields]
	padCount = 0
	for (idx, (var, field)) in enumerate(fields)
		if idx == 1
			prevfieldSize = sizeof(field)
			continue
		end

		fieldSize = sizeof(field)
		potentialOffset = prevfieldSize + offsets[end]
		padSize = (div(potentialOffset, fieldSize, RoundUp)*fieldSize - potentialOffset) |> UInt8
		@assert padSize >= 0 "pad size should be ≥ 0"
		if padSize != 0
			sz = 0x80 # MSB
			for i in 1:(sizeof(padSize)*8)
				sz = bitrotate(sz, 1)
				if (sz & padSize) == sz
					padCount += 1
					insert!(fieldVector, idx + padCount - 1, String(gensym())=>padType[sz])
				end
			end
		end
		push!(offsets, potentialOffset + padSize)
		prevfieldSize = fieldSize
	end
	len = length(fieldVector)
	# @assert issorted(fieldVector) "Fields should remain sorted"
	line = ["struct $name {"]
	for (idx, (name, type)) in enumerate(fieldVector)
		name = replace(name, "##" => "_pad")
		push!(line, " "^4*"$(name): $(type)"*(idx==len ? "" : ","))
	end
	push!(line, "};")
	lineJoined = join(line, "\n")
	return lineJoined
end


function getStructDefs(::Type{T}) where T
	fields = fieldnames(T)
	fieldTypes = fieldtypes(T)
	Dict(zip(fields, fieldTypes))
end

function getStructDefs(a::Array{Pair{Symbol, Any}})
	fields = a
	fieldTypes = map(typeof, a)
	Dict(zip(fields, fieldTypes))
end

getVal(a::Val{T}) where T = T

# struct Declaration
	# type::
	# decl::Pair
# end


end
