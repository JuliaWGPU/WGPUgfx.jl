
struct IOArray {
    data:array<f32>
};


struct IOArrayVector {
    data:array<vec4<f32>>
};


struct IOArrayMatrix {
    data:array<mat4x4<f32>>
};

@group(0) @binding(0) var<storage, read_write> input0:IOArray ;
@group(0) @binding(1) var<storage, read_write> output0:IOArray ;
@compute @workgroup_size(8, 8, 4) 
fn main(@builtin(global_invocation_id) global_id:vec3<u32>) { 
    let gIdx = global_id.x * global_id.y+global_id.z;
    let value = input0.data[gIdx];
    output0.data[gIdx] = max(value, 0.0);
}

