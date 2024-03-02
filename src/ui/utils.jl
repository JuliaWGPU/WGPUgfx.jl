
function sigmoid(x)
	if x > 0.0
		return 1 ./(1 .+ exp(-x))
	else
		z = exp(x)
		return z/(1 + z)
	end
end
