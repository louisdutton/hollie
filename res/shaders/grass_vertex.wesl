import bevy_pbr::render::{mesh_functions, view_transformations::position_world_to_clip};
@if(PREPASS_PIPELINE)
import bevy_pbr::prepass::io::{Vertex, VertexOutput, decompress_vertex};
@else
import bevy_pbr::render::forward_io::{Vertex, VertexOutput, decompress_vertex};
struct Meadow {
    time: vec4<f32>,
    contacts: array<vec4<f32>,32>,
    motion: array<vec4<f32>,32>,
    trails: array<vec4<f32>,64>,
    trail_motion: array<vec4<f32>,64>,
}
@group(constants::MATERIAL_BIND_GROUP) @binding(100) var<uniform> meadow: Meadow;
fn hash(p: vec2<f32>) -> f32 { return fract(sin(dot(p,vec2<f32>(127.1,311.7)))*43758.5453); }
fn noise(p: vec2<f32>) -> f32 {
    let c=floor(p); let f=fract(p); let u=f*f*(3.0-2.0*f);
    return mix(mix(hash(c),hash(c+vec2<f32>(1.0,0.0)),u.x),mix(hash(c+vec2<f32>(0.0,1.0)),hash(c+vec2<f32>(1.0,1.0)),u.x),u.y);
}
@vertex
fn vertex(input: Vertex) -> VertexOutput {
    var v=decompress_vertex(input,input.instance_index);
    let root=v.uv;
    let height=max(v.color.a*12.0,0.01);
    let fraction=clamp((v.position.y-0.04)/height,0.0,1.0);
    let wind_direction=normalize(vec2<f32>(1.0,0.45));
    let gust=noise(root*0.01-wind_direction*meadow.time.x*0.11);
    let front=0.5+0.5*sin(dot(root,vec2<f32>(0.028,-0.016))-meadow.time.x*1.4+(gust-0.5)*1.6);
    let wind=wind_direction*(0.1+smoothstep(0.2,0.8,front)*0.62+gust*0.1);
    let angle=hash(root*0.173+vec2<f32>(19.1,7.7))*6.2831853;
    let resting=vec2<f32>(cos(angle),sin(angle))*mix(0.12,0.42,hash(root*0.137+vec2<f32>(3.1,29.7)));
    var bend=vec2<f32>(0.0); var contact=0.0;
    for (var i=0u;i<u32(meadow.time.y);i++) {
        let c=meadow.contacts[i];
        let influence=(1.0-smoothstep(0.0,c.z,length(root-c.xy)))*c.w;
        if influence>contact { bend=meadow.motion[i].xy*influence; contact=influence; }
    }
    for (var i=0u;i<u32(meadow.time.z);i++) {
        let c=meadow.trails[i];
        let influence=(1.0-smoothstep(c.z*0.4,c.z,length(root-c.xy)))*c.w;
        if influence>contact { bend=meadow.trail_motion[i].xy*influence; contact=influence; }
    }
    let curvature=resting+wind+bend*1.15;
    let magnitude=length(curvature);
    let arc_angle=clamp(magnitude,0.001,1.35);
    let direction=curvature/max(magnitude,0.001);
    let arc=arc_angle*fraction; let radius=height/arc_angle;
    v.position=vec3<f32>(v.position.x+direction.x*radius*(1.0-cos(arc)),0.04+radius*sin(arc),v.position.z+direction.y*radius*(1.0-cos(arc)));
    @if(VERTEX_NORMALS)
    v.normal=normalize(vec3<f32>(-curvature.x*fraction*0.32,1.0,-curvature.y*fraction*0.32));
    if meadow.time.w > 0.0 {
        let a=root.x*0.009+root.y*0.004;
        let b=root.y*0.010;
        v.position.y+=(sin(a)*12.0+sin(b)*8.0)*meadow.time.w;
        @if(VERTEX_NORMALS) {
            let slope=vec2<f32>(cos(a)*0.108,cos(a)*0.048+cos(b)*0.08);
            v.normal=normalize(v.normal+vec3<f32>(-slope.x,0.0,-slope.y)*meadow.time.w);
        }
    }
    var out: VertexOutput;
    let world_from_local=mesh_functions::get_world_from_local(input.instance_index);
    out.world_position=mesh_functions::mesh_position_local_to_world(world_from_local,vec4<f32>(v.position,1.0));
    out.position=position_world_to_clip(out.world_position.xyz);
    @if(UNCLIPPED_DEPTH_ORTHO_EMULATION) {
        out.unclipped_depth=out.position.z; out.position.z=min(out.position.z,1.0);
    }
    @if(!PREPASS_PIPELINE || NORMAL_PREPASS_OR_DEFERRED_PREPASS)
    out.world_normal=mesh_functions::mesh_normal_local_to_world(v.normal,input.instance_index);
    out.uv=root;
    out.color=vec4<f32>(fraction,contact,smoothstep(0.35,0.68,front)*(1.0-smoothstep(0.78,0.98,front)),1.0);
    @if(PREPASS_PIPELINE || VERTEX_OUTPUT_INSTANCE_INDEX)
    out.instance_index=input.instance_index;
    @if(VISIBILITY_RANGE_DITHER)
    out.visibility_range_dither=mesh_functions::get_visibility_range_dither_level(input.instance_index,world_from_local[3]);
    return out;
}
