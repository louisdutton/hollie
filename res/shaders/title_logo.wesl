import bevy_ui_render::ui_vertex_output::UiVertexOutput;

@group(1) @binding(0) var<uniform> ink: vec4<f32>;
@group(1) @binding(1) var logo_mask: texture_2d<f32>;
@group(1) @binding(2) var logo_sampler: sampler;

@fragment
fn fragment(in: UiVertexOutput) -> @location(0) vec4<f32> {
    // Crop only the authored mask's safe margins; the black field is opacity,
    // never a panel behind the title. Keep the same artwork at every UI scale.
    let uv = mix(vec2<f32>(0.06, 0.12), vec2<f32>(0.965, 0.88), in.uv);
    let coverage = smoothstep(0.02, 0.95, textureSample(logo_mask, logo_sampler, uv).r);
    return vec4<f32>(ink.rgb, ink.a * coverage);
}
