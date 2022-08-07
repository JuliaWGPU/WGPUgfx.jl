module VariableDeclMod

export StorageVar, UniformVar, PrivateVar, @var, @letvar

using MacroTools
using Lazy:@forward

struct ImplicitPadding
	decl::Pair{Symbol, DataType}
end

struct StructEndPadding
	decl::Pair{Symbol, DataType}
end

include("typeutils.jl")

export UserStruct

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
	@error "Var type $s is not known. You might have to define it"
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

struct LetDataType{T} <: Variable{T}
	valTypePair::Pair{Symbol, eltype(T)}
	value::Union{Nothing, eltype(T)}
end

# TODO compose VarDataType and LetDataType sometime later

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
	return "$(attrStr)$(varStr) $(valStr);\n"	
end

wgslType(letvar::LetDataType{T}) where T = begin
	letStr = "let $(wgslType(letvar.valTypePair))"
	valStr = let t = letvar.value; t == nothing ? "" : "= $(wgslType(t))" end
	return "$(letStr) $(valStr);\n"
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


function defineVar(
	varType::Symbol,
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
		getEnumVariableType(varType)
	)
end


function defineLet(
	pair::Pair{Symbol, T}, 
	value::eltype(T)
) where T
	LetDataType{T}(
		pair,
		value,
	)
end

macro user(expr)
	getproperty(parentmodule(@__MODULE__), expr)
end

macro var(dtype::Expr)
	@capture(dtype, a_::dt_) && return begin
		@info dt
		eval(dt)
		defineVar(:Generic, a=>eval(dt), nothing, nothing, nothing)
	end
	@capture(dtype, a_::dt_ = v_) && return defineVar(:Generic, a=>eval(dt), nothing, nothing, v)
	@capture(dtype, a_ = v_) && return defineVar(:Generic, a=>:Any, nothing, nothing, v)
	@error "Unexpected Var expression !!!"
end

macro var(vtype, dtype::Expr)
	@capture(dtype, a_::dt_) || @error "Expecting sym::dtype!"
	defineVar(vtype, a=>eval(dt), nothing, nothing, nothing)
end

macro var(vtype::Symbol, group::Int, binding::Int, dtype::Expr)
	@capture(dtype, a_::dt_) || @error "Expecting sym::dtype!"
	defineVar(vtype, a=>eval(dt), group, binding, nothing)
end

macro var(vtype::Symbol, group::Int, binding::Int, dtype::Expr, value)
	@capture(dtype, a_::dt_) || @error "Expecting sym::dtype!"
	defineVar(vtype, a=>eval(dt), group, binding, value)
end

macro var(vtype::Symbol, dtype::Expr, value)
	@capture(dtype, a_::dt_) || @error "Expecting sym::dtype!"
	defineVar(vtype, a=>eval(dt), nothing, nothing, value)
end

macro letvar(dtype::Expr) # TODO type must be checked most likely
	@capture(dtype, a_::dt_ = v_) &&  return defineLet(a=>eval(dt), v)
	@capture(dtype, a_::dt_) && return defineLet(a=>eval(dt), nothing)
	@capture(dtype, a_=v_) && return defineLet(a=>:Any, v)
	@error "Expecting @let sym::dtype value!"
end

macro letvar(dtype::Expr, value::Any) # TODO type must be checked most likely
	@capture(dtype, a_::dt_) && return defineLet(a=>eval(dt), value)
	@error "Expecting @let sym::dtype value!"
end


macro letvar(dtype::Symbol, value::Any) # TODO type must be checked most likely
	# @capture(dtype, a_) &&  return defineLet(a=>eval(dt), value)
	@error "Not sure if this is allowed!!! Expecting @let sym value!"
end


end
