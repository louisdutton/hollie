use crate::{app::Mode, content::*, simulation::*};
use bevy::{
    app::AnimationSystems, camera::primitives::MeshAabb, gltf::GltfMesh,
    transform::TransformSystems,
};
use bevy::{
    asset::RenderAssetUsages,
    mesh::{
        Indices, VertexAttributeValues,
        skinning::{SkinnedMesh, SkinnedMeshInverseBindposes},
    },
    pbr::{ExtendedMaterial, MaterialExtension},
    prelude::*,
    render::render_resource::{AsBindGroup, PrimitiveTopology, ShaderType},
    shader::ShaderRef,
    world_serialization::WorldInstanceReady,
};
use std::collections::HashMap;

mod audio;
mod camera;
mod environment;
mod materials;
mod models;
mod room;
mod title;
pub(crate) use audio::Audio_Layer;
#[cfg(test)]
use audio::{TITLE_AMBIENCE, TITLE_MUSIC};
use camera::{Camera_State, player_center};
#[cfg(test)]
use camera::{bounded_camera_target, game_camera_projection};
pub use materials::{Meadow_Material, Meadow_Surface, Painted_Material, Painted_Surface};
use materials::{Meadow_Uniform, Water_Uniform};
#[cfg(test)]
use models::transformed_bounds;
#[cfg(test)]
use room::clip_surface;
use room::paint;
pub(crate) use title::Title_Scene;

#[derive(Component)]
pub struct Room_Visual;
#[derive(Component)]
#[relationship(relationship_target = Actor_Visuals)]
pub struct Actor_Visual(pub Entity);
#[derive(Component, Default)]
#[relationship_target(relationship = Actor_Visual, linked_spawn)]
pub struct Actor_Visuals(Vec<Entity>);
#[derive(Component)]
pub(crate) struct Main_Camera;
#[derive(Component)]
struct Sun;
#[derive(Component)]
struct Effect {
    born: f32,
    origin: Vec3,
    velocity: Vec3,
}
#[derive(Component)]
pub(crate) struct Model {
    pub(crate) gltf: Handle<Gltf>,
}
#[derive(Component)]
struct Actor_Animation {
    actor: Entity,
    clips: HashMap<String, AnimationNodeIndex>,
    current: String,
    durations: HashMap<String, f32>,
    changed_at: f32,
    previous: Vec<(AnimationNodeIndex, f32, f32)>,
}
#[derive(Component)]
struct Bone_Overlay {
    actor: Entity,
    turn: bool,
    ram: bool,
    pivot: Option<Entity>,
}
#[derive(Component)]
struct Actor_Material {
    actor: Entity,
    base: Color,
}
#[derive(Component)]
pub(crate) struct Model_Foot(f32);
#[derive(Clone, Copy)]
struct Bone_Anchor {
    bone: Entity,
    point: Vec3,
}
#[derive(Clone, Copy)]
struct Bone_Bounds {
    bone: Entity,
    bounds: Aabb,
}
#[derive(Resource, Default)]
pub(crate) struct Scene_Stats {
    pub grass_vertices: usize,
}
#[derive(Component)]
struct Skeleton {
    actor: Entity,
    root: Entity,
    seat: Option<Bone_Anchor>,
    arms: [Option<Bone_Bounds>; 2],
    head: Option<Bone_Bounds>,
}
#[derive(Resource)]
pub(crate) struct Offscreen_Target(pub Handle<Image>);
pub struct Rendering_Plugin;
impl Plugin for Rendering_Plugin {
    fn build(&self, app: &mut App) {
        app.add_plugins((
            MaterialPlugin::<Painted_Material>::default(),
            MaterialPlugin::<Meadow_Material>::default(),
            room::Room_Plugin,
            models::Model_Plugin,
            camera::Camera_Plugin,
            environment::Environment_Plugin,
            audio::Audio_Plugin,
            title::Title_Plugin,
        ));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn soundtrack_mp3_assets_decode_with_the_enabled_audio_features() {
        use bevy::audio::Decodable;
        for path in [
            TITLE_MUSIC,
            TITLE_AMBIENCE,
            "audio/A-Legend-Ian-Aisling-stream-preview.mp3",
            "audio/Wind-Ambience-Distant-City-stream-preview.mp3",
        ] {
            let source = AudioSource {
                bytes: std::fs::read(std::path::Path::new("res").join(path))
                    .unwrap()
                    .into(),
            };
            let samples: Vec<_> = source.decoder().take(960_000).collect();
            assert!(!samples.is_empty(), "empty audio: {path}");
            assert!(
                samples.iter().all(|v| v.is_finite()),
                "invalid audio: {path}"
            );
            assert!(
                samples.iter().any(|v| v.abs() > 0.0001),
                "silent audio: {path}"
            );
        }
    }
    #[test]
    fn upper_ground_in_the_view_is_inside_the_depth_range() {
        let mut projection = game_camera_projection();
        projection.update(1280., 720.);
        let target = Vec3::new(480., 0., 440.);
        let camera =
            Transform::from_translation(target + Vec3::splat(500.)).looking_at(target, Vec3::Y);
        let point = target - Vec3::new(140., 0., 140.);
        let clip =
            projection.get_clip_from_view() * camera.to_matrix().inverse() * point.extend(1.);
        let ndc = clip.truncate() / clip.w;
        assert!(ndc.x.abs() < 1. && ndc.y.abs() < 1.);
        assert!(
            ndc.z > 0. && ndc.z < 1.,
            "visible upper ground was clipped: {ndc:?}"
        );
    }
    #[test]
    fn camera_stays_inside_authored_bounds_even_in_small_rooms() {
        let registry = Room_Registry::load(std::path::Path::new("res")).unwrap();
        for content in registry.rooms.values() {
            let room = &content.room;
            let target = bounded_camera_target(
                Vec3::new(-1000., 0., 10000.),
                room,
                Vec2::new(1280., 720.),
                0.55,
            );
            assert!(room.camera_bounds.contains(Vec2::new(target.x, target.z)));
        }
    }
    #[test]
    fn camera_keeps_world_coverage_when_pixel_resolution_doubles() {
        let mut projection = game_camera_projection();
        projection.update(1280., 720.);
        let before = projection.get_clip_from_view();
        projection.update(2560., 1440.);
        assert_eq!(before, projection.get_clip_from_view());
        let Projection::Orthographic(projection) = projection else {
            unreachable!()
        };
        assert!((projection.area.height() - 250.).abs() < 0.001);
    }
    #[test]
    fn raised_arm_uses_the_top_after_rotation() {
        let bounds = Aabb {
            min: Vec3::new(-0.1, -0.4, -0.1),
            max: Vec3::new(0.1, 0.1, 0.1),
        };
        let matrix = Mat4::from_rotation_translation(
            Quat::from_rotation_z(std::f32::consts::PI),
            Vec3::Y * 0.4,
        );
        let posed = transformed_bounds(matrix, bounds);
        assert!((posed.max.y - 0.8).abs() < 0.001);
        let old_anchor = matrix.transform_point3(Vec3::Y * bounds.max.y);
        assert!(posed.max.y > old_anchor.y + 0.4);
    }
    #[test]
    fn shoreline_partitions_triangle_without_gaps() {
        let triangle = [(Vec2::ZERO, -1.), (Vec2::X, 1.), (Vec2::Y, -1.)];
        let area = |points: Vec<(Vec2, f32)>| {
            (1..points.len().saturating_sub(1))
                .map(|i| {
                    ((points[i].0 - points[0].0).perp_dot(points[i + 1].0 - points[0].0)).abs()
                        * 0.5
                })
                .sum::<f32>()
        };
        assert!(
            (area(clip_surface(triangle, true)) + area(clip_surface(triangle, false)) - 0.5).abs()
                < 0.0001
        );
    }
}
