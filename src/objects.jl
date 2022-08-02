struct Triangle
	vertex
	fragment
end

function InitGeometry(::Type{Triangle}, color)

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
	
	Triangle(
		vertex,
		fragment
	)
end


