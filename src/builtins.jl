module BuiltInsMod

using GeometryBasics
using GeometryBasics: Vec2, Vec3, Vec4, Mat2, Mat3, Mat4

export BuiltinValue, getEnumBuiltinValue, BuiltIn, @builtin

@enum BuiltinValue begin
	vertex_index
	instance_index
	position
	front_facing
	frag_depth
	local_invocation_id
	local_invocation_index
	global_invocation_id
	workgroup_id
	num_workgroups
	sample_index
	sample_mask
end

function getEnumBuiltinValue(s::Symbol)
	ins = instances(BuiltinValue)
	for i in ins
		if string(s) == string(i)
			return i
		end
	end
	@error "$s is not in builtin types"
end

struct BuiltIn{B, S, D} end

function BuiltIn(btype::Symbol, pair::Pair{Symbol, DataType})
	bVal = getEnumBuiltinValue(btype) |> Val
	sVal = pair.first |> Val
	dVal = pair.second |> Val
	return BuiltIn{bVal, sVal, dVal}
end


macro builtin(exp)
	@assert typeof(exp) == Expr """\n
	Expecting expression, found typeof(exp) instead
		builtin can be defined as
		@builtin (builtinValue) => sym::DataType
	"""
	@assert exp.head == :call "Expecting (builtinValue) => sym::DataType"
	@assert typeof(exp.args) == Vector{Any} "E $(typeof(exp.args))"
	@assert exp.args[1] == :(=>) "Should check"
	@assert exp.args[2] in Symbol.(instances(BuiltinValue)) "$(exp.args[2]) is not in BuiltinValue Enum"
	b = exp.args[2]
	@assert typeof(exp.args[3]) == Expr """
		This expression should be of format sym::Float32
	"""
	exp2 = exp.args[3]
	@assert exp2.head == :(::) "Expecting a seperator :: "
	s = exp2.args[1] 
	d = exp2.args[2] 
	return BuiltIn(b, s=>eval(d))
end


end
