struct Triangle
	vertex
	fragment
end

function InitGeometry(::Type{Triangle}, color)

	Triangle(
		vertex,
		fragment
	)
end

