
module MacroMod

using WGPUgfx
using MacroTools

export @code_wgsl

"""
Can take following format declarations

1. Builtin as datatype
expr = quote
	struct VertexInput
		a::@builtin position Int32
		b::@builtin vertex_index UInt32
	end
end

2. Builtin as attribute like in WGSL
expr = quote
	struct VertexInput
		@builtin position a::Vec4{Float32}
		@builtin vertex_index b::UInt32
		d::Float32
	end
end

3. Location


"""


"""
	struct VertexInput {
	    @builtin(vertex_index) vertex_index : u32,
	};

	struct VertexOutput {
	    @location(0) color : vec4<f32>,
	    @location(1) pos: vec4<f32>,
	};

	@stage(vertex)
	fn vs_main(in: VertexInput) -> VertexOutput {
	    var positions = array<vec2<f32>, 3>(
	    	vec2<f32>(0.0, -1.0),
	    	vec2<f32>(1.0, 1.0), 
	    	vec2<f32>(-1.0, 1.0)
	   	);
	    let index = i32(in.vertex_index);
	    let p: vec2<f32> = positions[index];

	    var out: VertexOutput;
	    out.pos = vec4<f32>(sin(p), 0.5, 1.0);
	    out.color = vec4<f32>(p, 0.5, 1.0);
	    return out;
	}

	@stage(fragment)
	fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
	    return in.color;
	}
"""

statements = false

expr = quote
	struct VertexInput
		@builtin vertex_index vi::UInt32
	end
	
	struct VertexOutput
		@location 0 color::Vec4{Float32}
		@location 1 pos::Vec4{Float32}
	end

	if $statements == true
		a = Int(0)
	end
	
	@vertex function vs_main(a::Int32)::Int32
	    index::UInt8 = 1
	    a::Int32 = 2
	    b::UInt32 = 3
	end

	@fragment function fs_main(b::Int32)::Vec4{Float32}
		b::Int32 = 200
	end

	function test(a::Int32, b::Float32)::Vec2{Float32}
		a::Int32 = 0
		b::Float32 = 3.0f0
		# c = 0
		test2()
	end

	function test2()
	end
end


expr = MacroTools.striplines(expr)

dump(expr)

function evalStructField(field)
	if @capture(field, if cond_ ifblock_ end)
		if eval(cond) == true
			return evalStructField(ifblock)
		else
			return nothing
		end
	elseif @capture(field, name_::dtype_)
		return name=>eval(dtype)
	elseif @capture(field, @builtin btype_ name_::dtype_)
		return name=>eval(:(@builtin $btype $dtype))
	elseif @capture(field, @location btype_ name_::dtype_)
		return name=>eval(:(@location $btype $dtype))
	else
		@error "Unknown struct field! $expr"
	end
end

function wgslStruct(expr)
	expr = MacroTools.striplines(expr)
	expr = MacroTools.flatten(expr)
	@capture(expr, struct T_ fields__ end) || error("verify struct format of $T with fields $fields")
	fieldDict = Dict{Symbol, DataType}()
	for field in fields
		evalfield = evalStructField(field)
		if evalfield != nothing 
			fieldDict[evalfield.first] = evalfield.second
		end
	end
	makePaddedStruct(T, :UserStruct, fieldDict)
	makePaddedWGSLStruct(T, fieldDict)
end

function wgslAssignment(expr)
	io = IOBuffer()
	@capture(expr, a_ = b_) || error("Unexpected assignment!")
	@capture(a, arg_::type_) || error("Missing type information!")
	atype = wgslType(eval(type))
	write(io, "let $arg:$atype = $b\n")
	seek(io, 0)
	stmt = read(io, String)
	close(io)
	return stmt
end

function wgslVertex(expr)
	io = IOBuffer()
	endstring = ""
	@capture(expr, @vertex function fnbody__ end) || error("Expecting regular function!")
	if @capture(fnbody[1], fnname_(fnargs__)::fnout_)
		write(io, "fn $fnname(")
		len = length(fnargs)
		endstring = len > 0 ? "}\n" : ""
		for (idx, arg) in enumerate(fnargs)
			if @capture(arg, aarg_::aatype_)
				intype = wgslType(eval(aatype))
				write(io, "$aarg:$(intype)"*(len==idx ? "" : ", "))
			end
			@capture(fnargs, aarg_) || error("Expecting type for function argument in WGSL!")
		end
		outtype = wgslType(eval(fnout))
		write(io, ") -> $outtype { \n")
		@capture(fnbody[2], stmnts__) || error("Expecting quote statements")
		for stmnt in stmnts
			write(io, " "^4*"$stmnt\n")
		end
	end
	write(io, endstring)
	seek(io, 0)
	code = read(io, String)
	close(io)
	return code
end

function wgslFragment(expr)
	io = IOBuffer()
	endstring = ""
	@capture(expr, @fragment function fnbody__ end) || error("Expecting regular function!")
	if @capture(fnbody[1], fnname_(fnargs__)::fnout_)
		write(io, "fn $fnname(")
		len = length(fnargs)
		endstring = len > 0 ? "}\n" : ""
		for (idx, arg) in enumerate(fnargs)
			if @capture(arg, aarg_::aatype_)
				intype = wgslType(eval(aatype))
				write(io, "$aarg:$(intype)"*(len==idx ? "" : ", "))
			end
			@capture(fnargs, aarg_) || error("Expecting type for function argument in WGSL!")
		end
		outtype = wgslType(eval(fnout))
		write(io, ") -> $outtype { \n")
		@capture(fnbody[2], stmnts__) || error("Expecting quote statements")
		for stmnt in stmnts
			write(io, " "^4*"$stmnt\n")
		end
	end
	write(io, endstring)
	seek(io, 0)
	code = read(io, String)
	close(io)
	return code
end

function wgslFunction(expr)
	io = IOBuffer()
	endstring = ""
	@capture(expr, function fnbody__ end) || error("Expecting regular function!")
	if @capture(fnbody[1], fnname_(fnargs__)::fnout_)
		write(io, "fn $fnname(")
		len = length(fnargs)
		endstring = len > 0 ? "}\n" : ""
		for (idx, arg) in enumerate(fnargs)
			if @capture(arg, aarg_::aatype_)
				intype = wgslType(eval(aatype))
				write(io, "$aarg:$(intype)"*(len==idx ? "" : ", "))
			end
			@capture(fnargs, aarg_) || error("Expecting type for function argument in WGSL!")
		end
		outtype = wgslType(eval(fnout))
		write(io, ") -> $outtype { \n")
		@capture(fnbody[2], stmnts__) || error("Expecting quote statements")
		for stmnt in stmnts
			write(io, " "^4*"$stmnt\n")
		end
	end
	write(io, endstring)
	seek(io, 0)
	code = read(io, String)
	close(io)
	return code
end

# IOContext TODO
function wgslCode(expr)
	io = IOBuffer()
	expr = MacroTools.striplines(expr)
	expr = MacroTools.flatten(expr)
	@capture(expr, blocks__) || error("Current expression is not a quote or block")
	for block in blocks
		if @capture(block, struct T_ fields__ end)
			write(io, wgslStruct(block))
		elseif @capture(block, a_ = b_)
			write(io, wgslAssignment(block))
		elseif @capture(block, @vertex function a__ end)
			write(io, wgslVertex(block))
			write(io, "\n")
		elseif @capture(block, @fragment function a__ end)
			write(io, wgslFragment(block))
			write(io, "\n")
		elseif @capture(block, function a__ end)
			write(io, wgslFunction(block))
			write(io, "\n")
		elseif @capture(block, if cond_ ifblock_ end)
			if eval(cond) == true
				write(io, wgslCode(ifblock))
				write(io, "\n")
			end
		end
	end
	seek(io, 0)
	code = read(io, String)
	close(io)
	return code
end

macro code_wgsl(expr)
	@eval expr
	a = wgslCode(eval(expr)) |> println
	return a
end

end
