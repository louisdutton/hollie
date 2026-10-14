import bevy_pbr::render::{
    forward_io::{VertexOutput, FragmentOutput},
    pbr_fragment::pbr_input_from_standard_material,
    pbr_functions::{alpha_discard, apply_pbr_lighting, main_pass_post_lighting_processing},
};
struct Paint { parameters: vec4<f32> }
@group(constants::MATERIAL_BIND_GROUP) @binding(100) var<uniform> paint: Paint;
fn brush(p: vec2<f32>) -> f32 {
    return sin(p.x * 0.39 + sin(p.y * 0.27)) * sin(p.y * 0.33 + sin(p.x * 0.19));
}
@fragment
fn fragment(in: VertexOutput, @builtin(front_facing) front: bool) -> FragmentOutput {
    var pbr = pbr_input_from_standard_material(in, front);
    let world = in.world_position.xyz;
    let pigment = brush(world.xz);
    pbr.material.base_color = vec4<f32>(pbr.material.base_color.rgb * (1.0 + pigment * paint.parameters.y), pbr.material.base_color.a);
    if paint.parameters.x > 0.5 {
        let waves = sin(world.x * 0.09 + paint.parameters.w * 1.3) * sin(world.z * 0.07 - paint.parameters.w * 0.8);
        let streaks = pow(max(0.0, sin(world.x * 0.16 + world.z * 0.05 + waves * 2.0)), 24.0);
        var foam = 0.0;
        @if(VERTEX_UVS_A) {
            foam = (1.0 - smoothstep(0.0, 0.20, in.uv.x)) * (0.4 + 0.3 * sin(world.x * 0.3 + world.z * 0.2 + paint.parameters.w));
        }
        pbr.material.base_color = vec4<f32>(pbr.material.base_color.rgb + vec3<f32>(0.08, 0.14, 0.13) * streaks + vec3<f32>(0.28, 0.30, 0.26) * foam, pbr.material.base_color.a);
    }
    pbr.material.base_color = alpha_discard(pbr.material.flags, pbr.material.alpha_cutoff, pbr.material.base_color);
    var out: FragmentOutput;
    out.color = apply_pbr_lighting(pbr);
    let luminance = max(dot(out.color.rgb, vec3<f32>(0.2126, 0.7152, 0.0722)), 0.001);
    let bands = floor(luminance * 7.0 + 0.5) / 7.0;
    let softened = mix(luminance, bands, 0.18);
    out.color = vec4<f32>(out.color.rgb * softened / luminance, out.color.a);
    out.color = main_pass_post_lighting_processing(pbr, out.color);
    return out;
}
