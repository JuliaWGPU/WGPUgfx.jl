
struct CameraUniform {
    eye:vec3<f32>,
    transform:mat4x4<f32>
};

@group(0) @binding(0) var<uniform> camera:CameraUniform ;

struct LightingUniform {
    ambientIntensity:f32,
    diffuseIntensity:f32,
    position:vec4<f32>,
    specularColor:vec4<f32>,
    specularIntensity:f32,
    specularShininess:f32
};

@group(0) @binding(1) var<uniform> lighting:LightingUniform ;

struct VertexInput {
    @location(0) pos:vec4<f32>,
    @location(1) vColor:vec4<f32>,
    @location(2) vNormal:vec4<f32>
};


struct VertexOutput {
    @builtin(position) pos:vec4<f32>,
    @location(0) vColor:vec4<f32>,
    @location(1) vNormal:vec4<f32>
};


struct WGPUMeshUniform {
    transform:mat4x4<f32>
};

@group(0) @binding(2) var<uniform> mesh2:WGPUMeshUniform ;
@vertex fn vs_main(vertexIn:VertexInput) -> VertexOutput { 
    var out:VertexOutput ;
    out.pos = mesh2.transform*vertexIn.pos;
    out.pos = camera.transform*out.pos;
    out.vColor = vertexIn.vColor;
    out.vNormal = mesh2.transform*vertexIn.vNormal;
    out.vNormal = camera.transform*out.vNormal;
    return out;
}

@fragment fn fs_main(fragmentIn:VertexOutput) -> @location(0) vec4<f32> { 
    var color:vec4<f32> = fragmentIn.vColor;
    let N:vec3<f32> = normalize(fragmentIn.vNormal.xyz);
    let L:vec3<f32> = normalize(lighting.position.xyz - fragmentIn.pos.xyz);
    let V:vec3<f32> = normalize(camera.eye.xyz - fragmentIn.pos.xyz);
    let H:vec3<f32> = normalize(L + V);
    let diffuse:f32 = lighting.diffuseIntensity*max(dot(N, L), 0.0);
    let specular:f32 = lighting.specularIntensity*pow(max(dot(N, H), 0.0), lighting.specularShininess);
    let ambient:f32 = lighting.ambientIntensity;
    return color * (ambient + diffuse)+lighting.specularColor * specular;
}

