use super::*;

use bevy::ecs::{query::QueryData, system::SystemParam};

#[derive(SystemParam)]
pub(super) struct Rig_Assets<'w> {
    gltfs: Res<'w, Assets<Gltf>>,
    gltf_meshes: Res<'w, Assets<GltfMesh>>,
    meshes: Res<'w, Assets<Mesh>>,
    inverse_bindposes: Res<'w, Assets<SkinnedMeshInverseBindposes>>,
    graphs: ResMut<'w, Assets<AnimationGraph>>,
    animations: Res<'w, Assets<AnimationClip>>,
    standard: Res<'w, Assets<StandardMaterial>>,
    painted: ResMut<'w, Assets<Painted_Material>>,
}
#[derive(SystemParam)]
pub(super) struct Rig_Scene<'w, 's> {
    models: Query<'w, 's, (&'static Model, &'static Actor_Visual)>,
    bones: Query<'w, 's, (&'static Name, &'static Transform, Option<&'static ChildOf>)>,
    skins: Query<'w, 's, (&'static Mesh3d, &'static SkinnedMesh)>,
    children: Query<'w, 's, &'static Children>,
    players: Query<'w, 's, (), With<AnimationPlayer>>,
    mesh_materials: Query<'w, 's, &'static MeshMaterial3d<StandardMaterial>>,
}
pub(super) fn model_ready(
    event: On<WorldInstanceReady>,
    mut commands: Commands,
    game: Game_View,
    assets: Rig_Assets,
    scene: Rig_Scene,
) {
    let Rig_Assets {
        gltfs,
        gltf_meshes,
        meshes,
        inverse_bindposes,
        mut graphs,
        animations,
        standard,
        mut painted,
    } = assets;
    let Rig_Scene {
        models,
        bones,
        skins,
        children,
        players,
        mesh_materials,
    } = scene;
    let Ok((model, actor)) = models.get(event.entity) else {
        return;
    };
    let tint = game
        .actors
        .get(actor.0)
        .ok()
        .map_or(Color::WHITE, |a| {
            if a.is_player() {
                Color::srgb(92. / 255., 156. / 255., 214. / 255.)
            } else if matches!(a.properties, Entity_Properties::Npc(_)) {
                Color::srgb(220. / 255., 190. / 255., 96. / 255.)
            } else if a.kind().is_some() && crate::visuals::animal_axis(a.kind()) == 0. {
                Color::srgb(196. / 255., 92. / 255., 88. / 255.)
            } else {
                Color::WHITE
            }
        })
        .to_linear()
        .to_f32_array();
    let Some(gltf) = gltfs.get(&model.gltf) else {
        return;
    };
    let foot = gltf
        .meshes
        .iter()
        .filter_map(|h| gltf_meshes.get(h))
        .flat_map(|m| m.primitives.iter())
        .filter_map(|p| meshes.get(&p.mesh))
        .filter_map(|m| m.get_aabb())
        .map(|b| b.min().y)
        .fold(f32::INFINITY, f32::min);
    let foot = if foot.is_finite() { foot } else { 0. };
    commands.entity(event.entity).insert(Model_Foot(foot));
    let named: HashMap<_, _> = children
        .iter_descendants(event.entity)
        .filter_map(|e| {
            bones
                .get(e)
                .ok()
                .map(|(n, t, _)| (n.as_str().to_string(), (e, *t)))
        })
        .collect();
    let neck = named.get("neck").copied();
    let head = named.get("head").copied();
    for name in ["neck", "head", "jaw"] {
        if let Some((entity, _)) = named.get(name) {
            let parent = bones
                .get(*entity)
                .ok()
                .and_then(|(_, _, p)| p.map(|p| p.parent()));
            let inherited = parent
                .is_some_and(|p| neck.is_some_and(|n| n.0 == p) || head.is_some_and(|h| h.0 == p));
            commands.entity(*entity).insert(Bone_Overlay {
                actor: actor.0,
                turn: !inherited,
                ram: name == "head" || name == "jaw" && !inherited,
                pivot: neck.map(|n| n.0),
            });
        }
    }
    let bone_bounds = |name: &str| -> Option<Bone_Bounds> {
        let bone = named.get(name)?.0;
        let mut minimum = Vec3::splat(f32::INFINITY);
        let mut maximum = Vec3::splat(f32::NEG_INFINITY);
        for descendant in children.iter_descendants(event.entity) {
            let Ok((mesh, skin)) = skins.get(descendant) else {
                continue;
            };
            let Some(joint) = skin.joints.iter().position(|entity| *entity == bone) else {
                continue;
            };
            let Some(bind) = inverse_bindposes
                .get(&skin.inverse_bindposes)
                .and_then(|poses| poses.get(joint))
            else {
                continue;
            };
            let Some(mesh) = meshes.get(&mesh.0) else {
                continue;
            };
            let (
                Some(VertexAttributeValues::Float32x3(positions)),
                Some(VertexAttributeValues::Uint16x4(joints)),
                Some(VertexAttributeValues::Float32x4(weights)),
            ) = (
                mesh.attribute(Mesh::ATTRIBUTE_POSITION),
                mesh.attribute(Mesh::ATTRIBUTE_JOINT_INDEX),
                mesh.attribute(Mesh::ATTRIBUTE_JOINT_WEIGHT),
            )
            else {
                continue;
            };
            for ((position, joints), weights) in positions.iter().zip(joints).zip(weights) {
                if (0..4).any(|i| joints[i] as usize == joint && weights[i] > 0.5) {
                    let point = bind.transform_point3(Vec3::from_array(*position));
                    minimum = minimum.min(point);
                    maximum = maximum.max(point);
                }
            }
        }
        if !minimum.is_finite() {
            return None;
        }
        Some(Bone_Bounds {
            bone,
            bounds: Aabb {
                min: minimum,
                max: maximum,
            },
        })
    };
    let animal = named.contains_key("neck") || named.contains_key("leg-front-left");
    let seat = bone_bounds("torso").map(|b| {
        let mut point = (b.bounds.min + b.bounds.max) * 0.5;
        point.y = if animal {
            b.bounds.max.y
        } else {
            b.bounds.min.y
        };
        Bone_Anchor {
            bone: b.bone,
            point,
        }
    });
    commands.entity(event.entity).insert(Skeleton {
        actor: actor.0,
        root: event.entity,
        seat,
        arms: [bone_bounds("arm-left"), bone_bounds("arm-right")],
        head: bone_bounds("head"),
    });
    let mut clips = HashMap::new();
    let mut durations = HashMap::new();
    let mut graph = AnimationGraph::new();
    for (name, clip) in &gltf.named_animations {
        let index = graph.add_clip(clip.clone(), 1., graph.root);
        clips.insert(name.to_string(), index);
        if let Some(clip) = animations.get(clip) {
            durations.insert(name.to_string(), clip.duration());
        }
    }
    let handle = graphs.add(graph);
    for descendant in children.iter_descendants(event.entity) {
        if let Ok(material) = mesh_materials.get(descendant) {
            if let Some(base) = standard.get(&material.0) {
                let mut base = base.clone();
                let color = base.base_color.to_linear().to_f32_array();
                base.base_color = Color::linear_rgba(
                    color[0] * tint[0],
                    color[1] * tint[1],
                    color[2] * tint[2],
                    color[3],
                );
                let handle = painted.add(Painted_Material {
                    base: base.clone(),
                    extension: default(),
                });
                commands
                    .entity(descendant)
                    .remove::<MeshMaterial3d<StandardMaterial>>()
                    .insert((
                        MeshMaterial3d(handle),
                        Actor_Material {
                            actor: actor.0,
                            base: base.base_color,
                        },
                    ));
            }
        }
        if players.contains(descendant) {
            commands.entity(descendant).insert((
                AnimationGraphHandle(handle.clone()),
                Actor_Animation {
                    actor: actor.0,
                    clips: clips.clone(),
                    current: String::new(),
                    durations: durations.clone(),
                    changed_at: 0.,
                    previous: Vec::new(),
                },
            ));
        }
    }
}
#[derive(QueryData)]
#[query_data(mutable)]
struct Actor_Display {
    entity: Entity,
    reference: &'static Actor_Visual,
    transform: &'static mut Transform,
    visibility: &'static mut Visibility,
    model: Option<&'static Model>,
    foot: Option<&'static Model_Foot>,
}
fn sync_actors(
    game: Game_View,
    mode: Res<State<Mode>>,
    mut actors: Query<Actor_Display>,
    mut commands: Commands,
) {
    for Actor_DisplayItem {
        entity,
        reference,
        mut transform,
        mut visibility,
        model,
        foot,
    } in &mut actors
    {
        let Some(actor) = game.actors.get(reference.0).ok() else {
            commands.entity(entity).despawn();
            continue;
        };
        *visibility =
            if actor.puzzle.open || *mode.get() == Mode::Editor || *mode.get() == Mode::Title {
                Visibility::Hidden
            } else {
                Visibility::Inherited
            };
        let b = actor.body.bounds();
        if model.is_some() {
            let scale = if matches!(actor.properties, Entity_Properties::Holdable(_)) {
                24.
            } else {
                32.
            };
            transform.translation = Vec3::new(
                actor.body.position.x,
                actor.body.height - foot.map_or(0., |f| f.0) * scale,
                actor.body.position.y,
            );
            transform.scale = Vec3::splat(scale);
            let yaw = Quat::from_rotation_y(
                actor.locomotion.facing.x.atan2(actor.locomotion.facing.y)
                    + crate::visuals::animal_axis(actor.kind()),
            );
            let forward = Vec3::new(actor.locomotion.facing.x, 0., actor.locomotion.facing.y);
            let animal = crate::visuals::animal_axis(actor.kind()) != 0.;
            let axis = if animal {
                forward
            } else {
                Vec3::new(actor.locomotion.facing.y, 0., -actor.locomotion.facing.x)
            };
            let mut bank = actor.pose.lean;
            if actor.kind() == Some(Character_Kind::Bison) {
                transform.translation.y += actor.pose.bison_bob(actor.body.velocity.length());
                bank += (actor.pose.phase * std::f32::consts::TAU).sin()
                    * 3_f32.to_radians()
                    * (actor.body.velocity.length() / 140.).clamp(0., 1.);
            }
            if actor.is_player() && actor.mounted().is_some() {
                bank = 0.;
            }
            let rotation = Quat::from_axis_angle(axis, bank);
            let pivot = Vec3::new(
                actor.body.position.x,
                actor.body.height,
                actor.body.position.y,
            );
            transform.translation = pivot + rotation * (transform.translation - pivot);
            transform.rotation = rotation * yaw;
        } else {
            transform.translation = (b.min + b.max) / 2.;
            transform.scale = actor.body.size;
        }
    }
}
pub(super) fn animate_models(
    game: Game_View,
    mut players: Query<(&mut AnimationPlayer, &mut Actor_Animation)>,
) {
    for (mut player, mut animation) in &mut players {
        let Some(actor) = game.actors.get(animation.actor).ok() else {
            continue;
        };
        let animal = crate::visuals::animal_axis(actor.kind()) != 0.;
        let airborne = !actor.body.grounded && !actor.body.swimming;
        let speed = actor.body.velocity.length();
        let phase = actor.pose.phase;
        let name = if matches!(actor.properties, Entity_Properties::Pressure_Plate(_)) {
            if actor.puzzle.active {
                "toggle-on"
            } else {
                "toggle-off"
            }
        } else if actor.vitality.health <= 0 {
            "die"
        } else if actor.mounted().is_some() && actor.is_player() {
            "ride"
        } else if actor.carrying().is_some() {
            "walk-holding-both"
        } else if airborne {
            if animal { "jump" } else { "static" }
        } else {
            "gait"
        };
        if animation.current != name {
            animation.previous = player
                .playing_animations()
                .map(|(index, active)| (*index, active.weight(), active.seek_time()))
                .collect();
            animation.current = name.into();
            animation.changed_at = game.elapsed;
        }
        let mut desired = Vec::new();
        let clip = |name: &str,
                    weight: f32,
                    fraction: f32,
                    desired: &mut Vec<(AnimationNodeIndex, f32, f32)>| {
            if let Some(index) = animation.clips.get(name) {
                let duration = animation
                    .durations
                    .get(name)
                    .copied()
                    .unwrap_or(1.)
                    .max(0.001);
                desired.push((*index, weight, fraction.clamp(0., 1.) * duration));
            }
        };
        if name == "gait" {
            if animal {
                let blend = ((speed - 50.) / 110.).clamp(0., 1.);
                if speed <= 50. {
                    let weight = (speed / 50.).clamp(0., 1.);
                    clip("down", 1. - weight, 0., &mut desired);
                    clip("walk", weight, phase, &mut desired);
                } else {
                    clip("walk", 1. - blend, phase, &mut desired);
                    clip("run", blend, phase, &mut desired);
                }
            } else {
                let weight = (speed / 40.).clamp(0., 1.);
                clip("idle", 1. - weight, 0., &mut desired);
                clip("walk", weight, phase, &mut desired);
            }
        } else {
            let duration = animation
                .durations
                .get(name)
                .copied()
                .unwrap_or(1.)
                .max(0.001);
            let fraction = match name {
                "ride" => actor
                    .mounted()
                    .and_then(|id| game.actors.get(id).ok())
                    .map_or(0., |a| {
                        ((a.body.velocity.length() - 50.) / 110.).clamp(0., 1.)
                    }),
                "toggle-on" | "toggle-off" => (game.elapsed - animation.changed_at) / duration,
                "die" => actor.vitality.death_timer / duration,
                "jump" | "static" => 0.,
                "walk-holding-both" => phase,
                _ => (game.elapsed - animation.changed_at).rem_euclid(duration) / duration,
            };
            clip(name, 1., fraction, &mut desired);
        }
        if desired.is_empty() {
            clip(if animal { "down" } else { "idle" }, 1., 0., &mut desired);
        }
        let blend = ((game.elapsed - animation.changed_at) / 0.14).clamp(0., 1.);
        let mut weights: HashMap<AnimationNodeIndex, (f32, f32)> = HashMap::new();
        if blend < 1. {
            for (index, weight, seek) in &animation.previous {
                weights.insert(*index, (weight * (1. - blend), *seek));
            }
        }
        for (index, weight, seek) in desired {
            let entry = weights.entry(index).or_insert((0., seek));
            entry.0 += weight * blend;
            entry.1 = seek;
        }
        // Iterate in clip order, not randomized HashMap order: blend reduction is floating point.
        let mut indices: Vec<_> = weights.keys().copied().collect();
        indices.sort_by_key(|i| i.index());
        player.stop_all();
        for index in indices {
            let (weight, seek) = weights[&index];
            if weight > 0.0001 {
                let active = player.play(index);
                active.set_weight(weight);
                active.seek_to(seek);
                active.pause();
            }
        }
    }
}
pub(super) fn overlay_bones(
    game: Game_View,
    mut bones: Query<(Entity, &Bone_Overlay, &mut Transform)>,
) {
    let pivots: HashMap<_, _> = bones
        .iter()
        .map(|(entity, _, transform)| (entity, transform.translation))
        .collect();
    for (_, overlay, mut transform) in &mut bones {
        let Some(actor) = game.actors.get(overlay.actor).ok() else {
            continue;
        };
        let mount = actor
            .mounted()
            .filter(|_| actor.is_player())
            .and_then(|id| game.actors.get(id).ok());
        let turn = mount.map_or(actor.pose.head_turn, |a| a.pose.head_turn * 0.5);
        let yaw = if overlay.turn {
            Quat::from_rotation_y(turn)
        } else {
            Quat::IDENTITY
        };
        let ram = if overlay.ram {
            Quat::from_rotation_z(25_f32.to_radians() * actor.pose.ram)
        } else {
            Quat::IDENTITY
        };
        let pivot = overlay
            .pivot
            .and_then(|id| pivots.get(&id))
            .copied()
            .unwrap_or(transform.translation);
        transform.translation = pivot + yaw * (transform.translation - pivot);
        transform.rotation = yaw * ram * transform.rotation;
    }
}
fn bone_in_root(
    entity: Entity,
    root: Entity,
    transforms: &Query<(&Transform, Option<&ChildOf>), Without<Actor_Visual>>,
) -> Option<Mat4> {
    let mut current = entity;
    let mut result = Mat4::IDENTITY;
    for _ in 0..32 {
        if current == root {
            return Some(result);
        }
        let (transform, parent) = transforms.get(current).ok()?;
        result = transform.to_matrix() * result;
        current = parent?.parent();
    }
    None
}
pub(super) fn transformed_bounds(matrix: Mat4, bounds: Aabb) -> Aabb {
    let mut result = Aabb {
        min: Vec3::splat(f32::INFINITY),
        max: Vec3::splat(f32::NEG_INFINITY),
    };
    for x in [bounds.min.x, bounds.max.x] {
        for y in [bounds.min.y, bounds.max.y] {
            for z in [bounds.min.z, bounds.max.z] {
                let point = matrix.transform_point3(Vec3::new(x, y, z));
                result.min = result.min.min(point);
                result.max = result.max.max(point);
            }
        }
    }
    result
}
pub(super) fn attach_carried_and_riders(
    mut game: ParamSet<(Game_View, Query<&mut Attachment_Pose>)>,
    skeletons: Query<&Skeleton>,
    bones: Query<(&Transform, Option<&ChildOf>), Without<Actor_Visual>>,
    mut actors: Query<(&Actor_Visual, &mut Transform, Option<&Model_Foot>)>,
) {
    let view = game.p0();
    let mut riding_points = Vec::new();
    let mut held_points = Vec::new();
    let roots: HashMap<_, _> = actors.iter().map(|(v, t, _)| (v.0, *t)).collect();
    let rigs: HashMap<_, _> = skeletons.iter().map(|s| (s.actor, s)).collect();
    let point = |rig: &Skeleton, anchor: Bone_Anchor| {
        bone_in_root(anchor.bone, rig.root, &bones).map(|m| m.transform_point3(anchor.point))
    };
    for (reference, mut transform, foot) in &mut actors {
        let Some(actor) = view.actors.get(reference.0).ok() else {
            continue;
        };
        if let Some(mount) = actor
            .mounted()
            .filter(|_| actor.is_player())
            .and_then(|id| view.actors.get(id).ok())
        {
            if let (Some(mount_rig), Some(rider_rig), Some(mount_root)) = (
                rigs.get(&mount.entity),
                rigs.get(&actor.entity),
                roots.get(&mount.entity),
            ) {
                if let (Some(saddle), Some(seat)) = (
                    mount_rig.seat.and_then(|a| point(mount_rig, a)),
                    rider_rig.seat.and_then(|a| point(rider_rig, a)),
                ) {
                    let progress = ((actor.attachment.mount_time / 0.4 - 0.7) / 0.3).clamp(0., 1.);
                    let bank = mount_root.rotation
                        * Quat::from_rotation_y(
                            -(mount.locomotion.facing.x.atan2(mount.locomotion.facing.y)
                                + crate::visuals::animal_axis(mount.kind())),
                        );
                    let rotation = bank
                        * Quat::from_rotation_y(
                            actor.locomotion.facing.x.atan2(actor.locomotion.facing.y),
                        );
                    let target = mount_root.transform_point(saddle) - rotation * (seat * 32.);
                    transform.translation = transform.translation.lerp(target, progress);
                    transform.rotation = transform.rotation.slerp(rotation, progress);
                    let anchor = transform.transform_point(Vec3::Y * foot.map_or(0., |f| f.0));
                    riding_points.push((
                        actor.entity,
                        anchor,
                        Vec3::new(
                            mount.body.position.x,
                            mount.body.height,
                            mount.body.position.y,
                        ),
                    ));
                }
            }
        }
        if let Some(carrier) = actor.held_by().and_then(|id| view.actors.get(id).ok()) {
            if let (Some(rig), Some(root)) = (rigs.get(&carrier.entity), roots.get(&carrier.entity))
            {
                let posed_bounds = |b: Bone_Bounds| {
                    bone_in_root(b.bone, rig.root, &bones)
                        .map(|matrix| transformed_bounds(matrix, b.bounds))
                };
                let hands: Vec<_> = rig
                    .arms
                    .iter()
                    .filter_map(|bounds| bounds.and_then(posed_bounds))
                    .collect();
                if hands.len() == 2 {
                    let mut anchor =
                        (hands[0].min + hands[0].max + hands[1].min + hands[1].max) * 0.25;
                    anchor.y = hands[0].max.y.max(hands[1].max.y);
                    let mut position = root.transform_point(anchor);
                    if let Some(head) = rig.head.and_then(posed_bounds) {
                        let head = transformed_bounds(root.to_matrix(), head);
                        let tilt =
                            (root.rotation * Vec3::X).y.abs() + (root.rotation * Vec3::Z).y.abs();
                        position.y = position.y.max(head.max.y + 6. * tilt + 0.5);
                    }
                    transform.translation = position;
                    transform.rotation = root.rotation;
                    held_points.push((
                        actor.entity,
                        position,
                        Vec3::new(
                            carrier.body.position.x,
                            carrier.body.height,
                            carrier.body.position.y,
                        ),
                    ));
                }
            }
        }
    }
    drop(view);
    let mut attachments = game.p1();
    for (id, point, origin) in riding_points {
        if let Ok(mut actor) = attachments.get_mut(id) {
            actor.riding_anchor = Some(point);
            actor.riding_origin = Some(origin);
        }
    }
    for (id, point, origin) in held_points {
        if let Ok(mut actor) = attachments.get_mut(id) {
            actor.held_anchor = Some(point);
            actor.held_origin = Some(origin);
        }
    }
}

pub(super) struct Model_Plugin;
impl Plugin for Model_Plugin {
    fn build(&self, app: &mut App) {
        app.add_systems(
            Update,
            (sync_actors, animate_models).in_set(crate::app::Game_Systems::Actors),
        )
        .add_systems(
            PostUpdate,
            (overlay_bones, attach_carried_and_riders)
                .chain()
                .after(AnimationSystems)
                .before(TransformSystems::Propagate),
        );
    }
}
