import bevy_pbr::render::{
    forward_io::{VertexOutput,FragmentOutput},
    pbr_fragment::pbr_input_from_standard_material,
    pbr_functions::{apply_pbr_lighting,main_pass_post_lighting_processing},
};
import super::palette::{grass_colour,LEAF_TIP};
import super::grass_uniform::meadow;
import super::cel_lighting::banded_light;
fn hash(p: vec2<f32>) -> f32 {return fract(sin(dot(p,vec2<f32>(127.1,311.7)))*43758.5453);}
fn noise(p: vec2<f32>) -> f32 {
    let c=floor(p);let f=fract(p);let u=f*f*(3.0-2.0*f);
    return mix(mix(hash(c),hash(c+vec2<f32>(1.0,0.0)),u.x),mix(hash(c+vec2<f32>(0.0,1.0)),hash(c+vec2<f32>(1.0,1.0)),u.x),u.y);
}
@fragment
fn fragment(in: VertexOutput,@builtin(front_facing) front: bool) -> FragmentOutput {
    var pbr=pbr_input_from_standard_material(in,front);
    let painted = meadow.time.w > 0.5;
    let tone=select(noise(in.uv*0.012),step(0.5,noise(in.uv*0.012)),painted);
    let upper=smoothstep(0.2,0.95,in.color.r);
    var albedo=grass_colour(tone);
    albedo=mix(albedo,LEAF_TIP,upper*0.12);
    albedo*=1.0-in.color.g*0.08;
    pbr.material.base_color=vec4<f32>(pow(albedo,vec3<f32>(2.2)),1.0);
    pbr.N=normalize(in.world_normal);
    // Curved normals and a restrained shoulder sheen reveal travelling gusts.
    pbr.material.perceptual_roughness=0.85-upper*in.color.b*0.12;
    var out: FragmentOutput;
    if painted {
        pbr.material.base_color=vec4<f32>(1.0);
        pbr.material.reflectance=vec3<f32>(0.0);
        pbr.material.perceptual_roughness=1.0;
        pbr.material.diffuse_transmission=0.0;
        out.color=vec4<f32>(pow(grass_colour(tone),vec3<f32>(2.2))*banded_light(apply_pbr_lighting(pbr).rgb),1.0);
    } else {
        out.color=apply_pbr_lighting(pbr);
    }
    out.color=main_pass_post_lighting_processing(pbr,out.color);
    return out;
}
