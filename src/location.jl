module LocationMod

export Location, @location
using GeometryBasics
using GeometryBasics: Vec2, Vec3, Vec4, Mat2, Mat3, Mat4

struct Location{B, S, D} end

function Location(btype::Int, pair::Pair{Symbol, DataType})
	bVal = (btype) |> Val
	sVal = pair.first |> Val
	dVal = pair.second |> Val
	return Location{bVal, sVal, dVal}
end

# TODO use macrotools
# cover when symbol is missing in sym::DataType for pure declarations
macro location(exp)
	@assert typeof(exp) == Expr """\n
	Expecting expression, found typeof(exp) instead
		builtin can be defined as
		@builtin (builtinValue) => sym::DataType
	"""
	@assert exp.head == :call "Expecting (builtinValue) => sym::DataType"
	@assert typeof(exp.args) == Vector{Any} "E $(typeof(exp.args))"
	@assert exp.args[1] == :(=>) "Should check"
	@assert typeof(exp.args[2]) == Int "Expecting Int argument"
	b = exp.args[2]
	@assert typeof(exp.args[3]) == Expr """
		This expression should be of format sym::Float32
	"""
	exp2 = exp.args[3]
	@assert exp2.head == :(::) "Expecting a seperator :: "
	s = exp2.args[1] 
	d = exp2.args[2]
	return Location(b, s=>eval(d))
end

end
