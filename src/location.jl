module LocationMod

export Location, @location, LocationDataType
using GeometryBasics
using GeometryBasics: Vec2, Vec3, Vec4, Mat2, Mat3, Mat4


struct Location{B, S, D} end


function Location(btype::Int, pair::Pair{Symbol, DataType})
	bVal = (btype) |> Val
	sVal = pair.first |> Val
	dVal = pair.second |> Val
	return Location{bVal, sVal, dVal}
end


macro location(exp)
	dump(exp)
	@assert typeof(exp) == Expr """\n
	Expecting expression, found typeof(exp) instead
		location can be defined as
		@location (Int) => sym::DataType
	"""
	@assert exp.head == :call "Expecting (0) => sym::DataType"
	@assert typeof(exp.args) == Vector{Any} "E $(typeof(exp.args))"
	@assert exp.args[1] == :(=>) "Should check"
	@assert exp.args[2] |> typeof == Int "$(exp.args[2]) should be an Int"
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


struct LocationDataType{B, D} end


function LocationDataType(btype::Int, dType::DataType)
	bVal = (btype) |> Val
	dVal = dType |> Val
	return LocationDataType{bVal, dVal}
end


macro location(btype, dtype)
	@assert typeof(btype) == Int """\n
	------------------------------------------------
	Expecting expression, found typeof(exp) instead
		location can be defined as
		@location Int DataType
	------------------------------------------------
	"""
	@assert typeof(eval(dtype)) == DataType "Expecting Valid Data Type"
	return LocationDataType(btype, eval(dtype))
end


function Location(sVal::Int, ::Type{Location{B, D}}) where {B, D}
	return Location{B, sVal, D}
end


end
