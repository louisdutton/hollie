struct Meadow {
    time: vec4<f32>,
    contacts: array<vec4<f32>,32>,
    motion: array<vec4<f32>,32>,
    trails: array<vec4<f32>,64>,
    trail_motion: array<vec4<f32>,64>,
}
@group(constants::MATERIAL_BIND_GROUP) @binding(100) var<uniform> meadow: Meadow;
