import bevy_pbr::render::{
    forward_io::{VertexOutput,FragmentOutput},
    pbr_fragment::pbr_input_from_standard_material,
    pbr_functions::{alpha_discard,apply_pbr_lighting,main_pass_post_lighting_processing},
};
import super::palette::{grass_colour,WATER_DEEP,WATER_LIGHT,WATER_SHALLOW,FOAM};
struct Paint {parameters:vec4<f32>}
struct Water {contacts:array<vec4<f32>,16>,headings:array<vec4<f32>,16>,starts:array<vec4<f32>,64>,ends:array<vec4<f32>,64>}
@group(constants::MATERIAL_BIND_GROUP) @binding(100) var<uniform> paint:Paint;
@group(constants::MATERIAL_BIND_GROUP) @binding(101) var<uniform> water:Water;
fn hash(p: vec2<f32>) -> f32
{
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

fn noise(p: vec2<f32>) -> f32
{
    var cell = floor(p);
    var f = fract(p);
    var u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(cell), hash(cell + vec2<f32>(1, 0)), u.x),
               mix(hash(cell + vec2<f32>(0, 1)), hash(cell + vec2<f32>(1, 1)), u.x), u.y);
}

fn cutout(value: f32, threshold: f32) -> f32
{
    var aa = max(fwidth(value), 0.015);
    return smoothstep(threshold - aa, threshold + aa, value);
}

// Warped cellular borders give foam scallops, curved branches and open holes.
// The same continuous world-space pattern breaks up shores, bodies and wakes.
fn foam_cells(input: vec2<f32>, time: f32) -> f32
{
    var p = input;
    p += vec2<f32>(sin(p.y * 1.7 + time * 0.24),
              cos(p.x * 1.3 - time * 0.19)) * 0.32;
    var base = floor(p);
    var local = fract(p);
    var nearest = 10.0;
    var second = 10.0;
    for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
            var cell = vec2<f32>(f32(x), f32(y));
            var jitter = vec2<f32>(hash(base + cell), hash(base + cell + vec2<f32>(37.2, 19.8)));
            var delta = cell + 0.2 + jitter * 0.6 - local;
            var d = length(delta);
            if (d < nearest) {
                second = nearest;
                nearest = d;
            } else {
                second = min(second, d);
            }
        }
    }
    return 1.0 - smoothstep(0.055, 0.17, second - nearest);
}


fn water_color(p:vec2<f32>,bank:f32,time:f32,surface_weight:f32,tile_size:f32) -> vec3<f32> {
    var drift = vec2<f32>(time * 0.60, -time * 0.35);
    var wash = noise((p + drift) * 0.020);
    var detail = noise((p - drift) * 0.14);
    var warp = vec2<f32>(noise(p * 0.11 + drift * 0.08),
                     noise(p * 0.11 + vec2<f32>(17.3, 8.2) - drift * 0.06)) - 0.5;
    var shore_fade = smoothstep(0.0, tile_size * 0.4, bank);
    var shallows = 1.0 - smoothstep(0.0, tile_size * 0.9, bank);

    var color = mix(WATER_DEEP, WATER_LIGHT,
                     smoothstep(0.25, 0.75, wash));
    color = mix(color, WATER_SHALLOW, shallows * 0.8);

    var pattern = foam_cells((p + drift) * 0.043,time);
    var dark_pattern = foam_cells((p + drift + vec2<f32>(4.0, -3.0)) * 0.043,time);
    var quiet = smoothstep(0.42, 0.72, wash);
    color = mix(color, color * vec3<f32>(0.77, 0.86, 0.90),
                dark_pattern * quiet * 0.42 * surface_weight);
    var surface_foam = cutout(pattern * quiet, 0.68) * 0.40 * shore_fade;

    // A broad scalloped contact strip with irregular holes and broken bands.
    var shore_contact = 1.0 - smoothstep(0.7, 2.5, bank + warp.x * 1.8);
    var shore_band = sin(bank * 0.95 + detail * 2.0 + time * 0.8);
    var shore_foam = cutout(shore_contact * mix(0.7, 1.0, detail), 0.48);
    shore_foam = max(shore_foam, cutout(shore_band, 0.93) *
                    smoothstep(2.0, 3.0, bank) * (1.0 - smoothstep(4.0, 8.0, bank)) *
                    cutout(detail, 0.44) * 0.7);

    var body_foam = 0.0;
    for (var i = 0u; i < 16u; i++) {
        if (water.headings[i].w == 0.0) { continue; }
        var delta = p - water.contacts[i].xy;
        var radius = water.contacts[i].zw + 1.2;
        var local = (delta + warp * 2.0) / radius;
        var r = length(local);
        var rim = 1.0 - smoothstep(0.08, 0.27, abs(r - 1.06));
        var facing = dot(delta / max(length(delta), 0.001), water.headings[i].xy);
        var bow = 1.0 - smoothstep(0.06, 0.19, abs(r - 1.40 - warp.y * 0.12));
        bow *= smoothstep(0.05, 0.65, facing) * water.headings[i].z;
        var breakup = mix(0.42, 1.0, detail);
        body_foam = max(body_foam, max(rim * breakup, bow * mix(0.70, 1.0, detail)));
    }
    body_foam = cutout(body_foam, 0.50);

    // Union connected footprints before applying the pattern: no visible
    // per-segment outlines, paired rails, or repeating circles.
    var trail_coverage = 0.0;
    for (var i = 0u; i < 64u; i++) {
        if (water.ends[i].w == 0.0) { continue; }
        var a = water.starts[i].xy;
        var segment = water.ends[i].xy - a;
        var age = water.starts[i].w;
        var q = p + warp * (2.0 + age * 3.0);
        var t = clamp(dot(q - a, segment) / max(dot(segment, segment), 0.001), 0.0, 1.0);
        var distance = length(q - (a + segment * t));
        var width = water.starts[i].z * mix(1.1, 0.45, age);
        var coverage = 1.0 - smoothstep(width * 0.2, width, distance);
        coverage *= pow(1.0 - age, 0.65) * mix(0.8, 1.0, water.ends[i].z);
        trail_coverage = max(trail_coverage, coverage);
    }
    var wake_pattern = foam_cells((p - drift * 0.3) * 0.095,time);
    var trail_foam = cutout(trail_coverage * (0.15 + wake_pattern * 0.85) *
                             mix(0.7, 1.0, detail), 0.44);
    var foam = max(max(surface_foam, shore_foam), max(body_foam, trail_foam));
    foam *= surface_weight;


    return mix(color,FOAM,foam*0.95);
}
@fragment
fn fragment(in:VertexOutput,@builtin(front_facing) front:bool) -> FragmentOutput {
    var pbr=pbr_input_from_standard_material(in,front);
    let p=in.world_position.xz;
    var grass_ground=false;
    @if(VERTEX_COLORS)
    grass_ground=in.color.g>in.color.r;
    if paint.parameters.x==1.0 {
        let albedo=water_color(p,in.uv.x,paint.parameters.w,1.0,paint.parameters.z);
        pbr.material.base_color=vec4<f32>(pow(albedo,vec3<f32>(2.2)),1.0);
        let slope=cos(dot(p,vec2<f32>(0.065,0.045))-paint.parameters.w*0.70)*vec2<f32>(0.065,0.045)*0.24+cos(dot(p,vec2<f32>(-0.040,0.100))-paint.parameters.w*0.93)*vec2<f32>(-0.040,0.100)*0.14;
        pbr.N=normalize(vec3<f32>(-slope.x,1.0,-slope.y));
        pbr.material.perceptual_roughness=0.65;
    } else if paint.parameters.x==2.0 && grass_ground {
        let albedo=grass_colour(noise(p*0.012));
        pbr.material.base_color=vec4<f32>(pow(albedo,vec3<f32>(2.2)),1.0);
    } else {
        pbr.material.base_color=vec4<f32>(pbr.material.base_color.rgb*(1.0+(noise(p*0.045)-0.5)*paint.parameters.y),pbr.material.base_color.a);
    }
    pbr.material.base_color=alpha_discard(pbr.material.flags,pbr.material.alpha_cutoff,pbr.material.base_color);
    var out:FragmentOutput;
    out.color=apply_pbr_lighting(pbr);
    out.color=main_pass_post_lighting_processing(pbr,out.color);
    return out;
}
