module VariableDeclMod

export StorageVar, UniformVar, PrivateVar

using Lazy:@forward

struct ImplicitPadding
	decl::Pair{Symbol, DataType}
end

struct StructEndPadding
	decl::Pair{Symbol, DataType}
end

include("typeutils.jl")

export wgslType

abstract type Atomic end

abstract type Zeroable end

abstract type StorableType end

abstract type Constructible end

abstract type Variable{T} end

struct VarAttribute
	group::Int
	binding::Int
end

wgslType(attr::VarAttribute) = begin
	return "@group($(attr.group)) @binding($(attr.binding)) "
end

@enum VariableType begin
	Generic
	Storage
	Private
	Uniform
	WorkGroup
	StorageRead
	StorageReadWrite
end


function getEnumVariableType(s::Symbol)
	ins = instances(VariableType)
	for i in ins
		if string(s) == string(i)
			return i
		end
	end
	@error "Var type $s is not not known. You might have to define it"
end

wgslType(a::Val{getEnumVariableType(:Generic)}) = string()
wgslType(a::Val{getEnumVariableType(:Storage)}) = "<storage>"
wgslType(a::Val{getEnumVariableType(:Private)}) = "<private>"
wgslType(a::Val{getEnumVariableType(:Uniform)}) = "<uniform>"
wgslType(a::Val{getEnumVariableType(:WorkGroup)}) = "<workgroup>"
wgslType(a::Val{getEnumVariableType(:StorageRead)}) = "<storage, read>"
wgslType(a::Val{getEnumVariableType(:StorageReadWrite)}) = "<storage, read_write>"

struct VarDataType{T} <: Variable{T}
	attribute::Union{Nothing, VarAttribute}
	valTypePair::Pair{Symbol, eltype(T)}
	value::Union{Nothing, eltype(T)}
	varType::VariableType
end

attribute(var::VarDataType{T}) where T = begin
	return var.attribute
end

valueType(var::VarDataType{T}) where T = begin
	return var.valueType
end

value(var::VarDataType{T}) where T = begin
	return var.value
end

varType(var::VarDataType{T}) where T = begin
	return var.varType
end

wgslType(var::VarDataType{T}) where T = begin
	attrStr = let t = var.attribute; t == nothing ? "" : wgslType(t) end
	varStr = "var$(wgslType(Val(var.varType))) $(wgslType(var.valTypePair))"
	valStr = let t = var.value; t == nothing ? "" : "= $(wgslType(t))" end
	return "$(attrStr)$(varStr) $(valStr);"	
end

struct GenericVar{T} <: Variable{T}
	var::VarDataType{T}
end

function GenericVar(
	pair::Pair{Symbol, T}, 
	group::Union{Nothing, Int}, 
	binding::Union{Nothing, Int},
	value::eltype(T)
) where T
	attrType = Union{map(typeof, [group, binding])...}
	@assert attrType in [Nothing, Int] "Both group and binding should be defined or left to nothing"
	VarDataType{T}(
		(attrType == Nothing) ? nothing : VarAttribute(group, binding),
		pair,
		value,
		getEnumVariableType(:Generic)
	)
end

@forward GenericVar.var attribute, valueType, value, Base.getproperty, Base.setproperty!

struct UniformVar{T} <: Variable{T} 
	var::VarDataType{T}	
end

function UniformVar(
	pair::Pair{Symbol, T}, 
	group::Union{Nothing, Int}, 
	binding::Union{Nothing, Int},
	value::eltype(T)
) where T
	attrType = Union{map(typeof, [group, binding])...}
	@assert attrType in [Nothing, Int] "Both group and binding should be defined or left to nothing"
	VarDataType{T}(
		attrType == Nothing ? nothing : VarAttribute(group, binding),
		pair,
		value,
		getEnumVariableType(:Uniform)
	)
end

@forward UniformVar.var attribute, valueType, value, Base.getproperty, Base.setproperty!

struct StorageVar{T} <: Variable{T}
	var::VarDataType{T}	
end

function StorageVar(
	pair::Pair{Symbol, T}, 
	group::Union{Nothing, Int}, 
	binding::Union{Nothing, Int},
	value::eltype(T)
) where T
	attrType = Union{map(typeof, [group, binding])...}
	@assert attrType in [Nothing, Int] "Both group and binding should be defined or left to nothing"
	VarDataType{T}(
		attrType == Nothing ? nothing : VarAttribute(group, binding),
		pair,
		value,
		getEnumVariableType(:Storage)
	)
end

@forward StorageVar.var attribute, valueType, value, Base.getproperty, Base.setproperty!


struct PrivateVar{T} <: Variable{T}
	var::VarDataType{T}
end

function PrivateVar(
	pair::Pair{Symbol, T}, 
	group::Union{Nothing, Int}, 
	binding::Union{Nothing, Int},
	value::eltype(T)
) where T
	attrType = Union{map(typeof, [group, binding])...}
	@assert attrType in [Nothing, Int] "Both group and binding should be defined or left to nothing"
	VarDataType{T}(
		attrType == Nothing ? nothing : VarAttribute(group, binding),
		pair,
		value,
		getEnumVariableType(:Private)
	)
end


@forward PrivateVar.var attribute, valueType, value, Base.getproperty, Base.setproperty!


end
