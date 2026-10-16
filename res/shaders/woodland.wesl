import bevy_pbr::render::{
    forward_io::{VertexOutput,FragmentOutput},
    pbr_fragment::pbr_input_from_standard_material,
    pbr_functions::{alpha_discard,apply_pbr_lighting,main_pass_post_lighting_processing},
};
import super::palette::{grass_colour,moss_colour,foliage_colour,WOOD_LIGHT,CANOPY_LIGHT};
struct Woodland { parameters: vec4<f32> }
@group(constants::MATERIAL_BIND_GROUP) @binding(100) var<uniform> woodland: Woodland;
fn hash(p: vec2<f32>) -> f32 { return fract(sin(dot(p,vec2<f32>(127.1,311.7)))*43758.5453); }
fn noise(p: vec2<f32>) -> f32 {
    let c=floor(p); let f=fract(p); let u=f*f*(3.0-2.0*f);
    return mix(mix(hash(c),hash(c+vec2<f32>(1.0,0.0)),u.x),mix(hash(c+vec2<f32>(0.0,1.0)),hash(c+vec2<f32>(1.0,1.0)),u.x),u.y);
}
fn pigment(p: vec2<f32>) -> f32 {
    return noise(p)*0.65+noise(p*2.1+vec2<f32>(13.7,6.1))*0.25+noise(p*4.3)*0.10;
}
fn linear(c: vec3<f32>) -> vec3<f32> { return pow(c,vec3<f32>(2.2)); }
@fragment
fn fragment(in: VertexOutput,@builtin(front_facing) front: bool) -> FragmentOutput {
    var pbr=pbr_input_from_standard_material(in,front);
    pbr.material.base_color=alpha_discard(pbr.material.flags,pbr.material.alpha_cutoff,pbr.material.base_color);
    let p=in.world_position.xyz;
    let kind=woodland.parameters.x;
    var albedo=pbr.material.base_color.rgb;
    if ((kind>1.5 && kind<2.5) || kind>3.5) && length(woodland.parameters.yzw)>0.5 {
        // A hue-shifting paint ramp, rather than smooth PBR shading. The
        // low-frequency breakup makes irregular paint boundaries, not veins.
        // A broad front fill keeps painted clumps readable beneath the
        // backlit canopy, without changing the sun that casts the glade rays.
        let light=normalize(normalize(woodland.parameters.yzw)+vec3<f32>(-0.55,0.0,1.05));
        var brush=(noise(p.xz*0.16+vec2<f32>(p.y*0.11))+noise(p.zy*0.23))*0.5;
        var brightness=dot(normalize(in.world_normal),light)+0.12+(brush-0.5)*0.65+(in.uv.x-0.5)*0.30;
        if kind>3.5 {
            // Each small leaf is one paint mark. Noise painted across a smooth
            // shell made camouflage contours instead of layered leaf shapes.
            brush=in.uv.x;
            brightness=dot(normalize(in.world_normal),light)*0.85+(brush-0.5)*0.38;
        }
        let paint=foliage_colour(brightness,brush);
        var out: FragmentOutput;
        let illumination=select(2.2,CANOPY_LIGHT,kind>3.5);
        out.color=vec4<f32>(linear(paint)*albedo*illumination,1.0);
        out.color=main_pass_post_lighting_processing(pbr,out.color);
        return out;
    }
    let mottling=pigment(p.xz*0.045+vec2<f32>(p.y*0.027,p.y*0.019));
    if kind<0.5 {
        let uv=in.uv;
        let warp=noise(vec2<f32>(uv.x*0.12,uv.y*0.027))*2.1;
        let grain=0.5+0.5*sin(uv.x*1.1+warp+sin(uv.y*0.055)*0.35);
        let grooves=smoothstep(0.75,0.97,grain);
        albedo*=0.94+mottling*0.32-grooves*0.17;
        albedo=mix(albedo,linear(WOOD_LIGHT),mottling*0.20);
        let moss=smoothstep(-0.25,0.65,pbr.N.y)*smoothstep(0.48,0.78,pigment(p.xz*0.065+vec2<f32>(p.y*0.05)));
        albedo=mix(albedo,linear(moss_colour(0.4)),moss*0.75);
    } else if kind<1.5 {
        albedo*=0.88+mottling*0.35;
        let moss=smoothstep(0.22,0.78,pbr.N.y+(pigment(p.xz*0.08)-0.5)*0.9);
        let green=moss_colour(mottling);
        albedo=mix(albedo,linear(green),moss*0.88);
    } else if kind<2.5 {
        // Broad pigment variation keeps the shared canopy normals readable.
        let wash=noise(p.xz*0.018+vec2<f32>(p.y*0.012));
        albedo*=0.96+wash*0.08;
        pbr.material.perceptual_roughness=1.0;
    } else {
        albedo*=0.90+mottling*0.28;
        let moss=smoothstep(0.55,0.78,pigment(p.xz*0.032));
        albedo=mix(albedo,linear(moss_colour(0.5)),moss*0.6);
        let grass=grass_colour(noise(p.xz*0.012));
        albedo=mix(albedo,linear(grass)*0.80,smoothstep(0.0,0.5,in.uv.x));
    }
    pbr.material.base_color=vec4<f32>(albedo,1.0);
    var out: FragmentOutput;
    out.color=apply_pbr_lighting(pbr);
    out.color=main_pass_post_lighting_processing(pbr,out.color);
    return out;
}
