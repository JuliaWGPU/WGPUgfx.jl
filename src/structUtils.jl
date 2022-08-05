module StructUtilsMod
using WGPUgfx
using WGPU
using WGPU: getEnum
using WGPU_jll
using Lazy: @forward

export wgslType, @var,
	BuiltIn, @builtin, getEnumBuiltinValue, 
	makePaddedStruct, makePaddedWGSLStruct, makeStruct,
	Location, @location, BuiltInDataType, BuiltinValue, LocationDataType

using StaticArrays
using GeometryBasics

include("variableDecl.jl")
using .VariableDeclMod

@info UserStruct

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

juliaPadType = Dict(
	1 => Bool,
	2 => Vec2{Bool},
	4 => Vec4{Bool},
	8 => Vec2{UInt32},
	16 => Vec2{UInt32},
	32 => Mat4{Float16},
	64 => Mat4{Float32}
)

adaptType(p::Pair{S, D}) where {S<:Symbol, D<:DataType} = adaptType(p.first, p.second)
adaptType(::Val{T}) where T = typeof(T) == BuiltinValue ? adaptType(T) : T
adaptType(::Type{Val{T}}) where T = T
adaptType(::Type{T}) where T = T
adaptType(a::BuiltinValue) = string(a) |> Symbol
adaptType(::Type{BuiltInDataType{B, D}}) where {B, D} = BuiltIn(adaptType(B), gensym()=>adaptType(D))
adaptType(::Type{LocationDataType{B, D}}) where {B, D} = Location(adaptType(B), gensym()=>adaptType(D))
adaptType(a::Symbol, ::Type{BuiltInDataType{B, D}}) where {B, D} = BuiltIn(adaptType(B), a=>adaptType(D))
adaptType(a::Symbol, ::Type{LocationDataType{B, D}}) where {B, D} = Location(adaptType(B), a=>adaptType(D))
adaptType(a::Symbol, ::Type{DataType}) = a=>adaptType(D)
adaptType(a::Symbol, ::Type{T}) where T = a=>T
adaptType(::Type{S}) where S<:Symbol = Symbol
adaptType(a::Symbol) = a

byteSize(::Type{T}) where T = sizeof(T)
byteSize(::Type{Val{T}}) where T = sizeof(T)
byteSize(::Val{T}) where T = sizeof(T)
byteSize(::Type{BuiltInDataType{B, D}}) where {B, D} = byteSize(D)
byteSize(::Type{BuiltIn{B, S, D}}) where {B, S, D} = byteSize(D)
byteSize(::Type{LocationDataType{B, D}}) where {B, D} = byteSize(D)
byteSize(::Type{Location{B, S, D}}) where {B, S, D} = byteSize(D)


function makePaddedStruct(name::Symbol, abstractType::Union{Nothing, DataType}, fields...)
	offsets = [0,]
	prevfieldSize = 0
	fieldVector = [key=>val for (key, val) in fields...]
	padCount = 0
	for (idx, (var, field)) in enumerate(fields...)
		if idx == 1
			prevfieldSize = byteSize(field)
			continue
		end
		fieldSize = byteSize(field)
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
	Expr(:struct, false, :($name <: $absType), quote $(unfields...) end) |> eval
	setproperty!(Main, name, eval(name))
	setproperty!(getproperty(Main, :MacroMod), name, eval(name))
end

makePaddedStruct(name::Symbol, abstractType::Symbol, fields...) = makePaddedStruct(
	name,
	eval(abstractType),
	fields...
)

function makeStruct(name::Symbol, abstractType::Union{Nothing, DataType}, fields...)
	name = name
	unfields = [:($key::$val) for (key, val) in fields...]
	@info quote
		$(unfields...)
	end
	@info unfields
	absType = abstractType != nothing ? :($abstractType) : :(Any)
	@info name=>typeof(name) 
	@info absType=>typeof(absType)
	Expr(:struct, false, :($name <: $absType), quote $(unfields...) end) |> eval
	setproperty!(Main, name, eval(name))
	setproperty!(getproperty(Main, :MacroMod), name, eval(name))
end

makeStruct(name::Symbol, abstractType::Symbol, fields...) = makeStruct(
	name,
	eval(abstractType),
	fields...
)

function makePaddedWGSLStruct(name::Symbol, fields...)
	@assert issorted(fields |> keys) "Fields are expected to be sorted for consistency"
	offsets = [0,]
	prevfieldSize = 0
	fieldVector = [adaptType(field) for field in fields...]
	padCount = 0
	for (idx, (var, field)) in enumerate(fields...)
		if idx == 1
			prevfieldSize = byteSize(field)
			continue
		end
		fieldSize = byteSize(field)
		potentialOffset = prevfieldSize + offsets[end]
		padSize = (div(potentialOffset, fieldSize, RoundUp)*fieldSize - potentialOffset) |> UInt8
		@assert padSize >= 0 "pad size should be ≥ 0"
		if padSize != 0
			sz = 0x80 # MSB
			for i in 1:(sizeof(padSize)*8)
				sz = bitrotate(sz, 1)
				if (sz & padSize) == sz
					padCount += 1
					insert!(
						fieldVector, 
						idx + padCount - 1, 
						Symbol(replace(String(gensym()), "##" => "_pad"))=>juliaPadType[sz]
					)
				end
			end
		end
		push!(offsets, potentialOffset + padSize)
		prevfieldSize = fieldSize
	end
	len = length(fieldVector)
	# @assert issorted(fieldVector) "Fields should remain sorted"
	line = ["\nstruct $name {"]
	for (idx, field) in enumerate(fieldVector)
		push!(line, " "^4*"$(wgslType(field))"*(idx==len ? "" : ","))
	end
	push!(line, "};\n\n")
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

end
