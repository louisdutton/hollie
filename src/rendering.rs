use crate::{app::Mode, content::*, simulation::*};
use bevy::{
    asset::RenderAssetUsages,
    image::{CompressedImageFormats, ImageSampler, ImageType},
    mesh::Indices,
    pbr::{ExtendedMaterial, MaterialExtension},
    prelude::*,
    render::render_resource::{AsBindGroup, PrimitiveTopology},
    shader::ShaderRef,
    world_serialization::WorldInstanceReady,
};
use std::collections::HashMap;

#[derive(Asset, AsBindGroup, Reflect, Debug, Clone)]
pub struct Painted_Surface {
    #[uniform(100)]
    pub parameters: Vec4,
}
impl Default for Painted_Surface {
    fn default() -> Self {
        Self {
            parameters: Vec4::new(0., 0.16, 0.04, 0.),
        }
    }
}
impl MaterialExtension for Painted_Surface {
    fn fragment_shader() -> ShaderRef {
        "shaders/painted.wesl".into()
    }
}
pub type Painted_Material = ExtendedMaterial<StandardMaterial, Painted_Surface>;
#[derive(Component)]
pub struct Room_Visual;
#[derive(Component)]
pub struct Actor_Visual(pub u64);
#[derive(Component)]
struct Main_Camera;
#[derive(Component)]
struct Sun;
#[derive(Component)]
struct Grass_Patch {
    phase: f32,
    positions: Vec<[f32; 3]>,
}
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
    actor: u64,
    clips: HashMap<String, AnimationNodeIndex>,
    current: String,
    durations: HashMap<String, f32>,
    changed_at: f32,
}
#[derive(Resource, Default)]
struct Render_State {
    generation: u64,
    camera_target: Vec3,
    zoom: f32,
    music: String,
    last_effect: (u64, u64),
}
#[derive(Component)]
struct Music;
#[derive(Resource)]
pub struct Title_Background(pub Handle<Image>);
#[derive(Resource)]
pub(crate) struct Offscreen_Target(pub Handle<Image>);
pub struct Rendering_Plugin;
impl Plugin for Rendering_Plugin {
    fn build(&self, app: &mut App) {
        app.add_plugins(MaterialPlugin::<Painted_Material>::default())
            .init_resource::<Render_State>()
            .add_systems(Startup, setup)
            .add_systems(
                Update,
                (
                    rebuild_room,
                    sync_actors,
                    animate_models,
                    animate_environment,
                    follow_camera,
                    play_music,
                )
                    .chain(),
            );
    }
}
fn setup(mut commands: Commands, mut images: ResMut<Assets<Image>>) {
    let image = Image::from_buffer(
        include_bytes!("../assets/hollie-background.png"),
        ImageType::Extension("png"),
        CompressedImageFormats::NONE,
        true,
        ImageSampler::default(),
        RenderAssetUsages::default(),
    )
    .expect("reference background PNG");
    commands.insert_resource(Title_Background(images.add(image)));
    commands.insert_resource(ClearColor(Color::srgb(0.47, 0.72, 0.77)));
    commands.insert_resource(GlobalAmbientLight {
        color: Color::srgb(0.72, 0.82, 0.94),
        brightness: 420.,
        ..default()
    });
    let camera = commands
        .spawn((
            Camera3d::default(),
            IsDefaultUiCamera,
            bevy::render::view::DebandDither::Disabled,
            Projection::Orthographic(OrthographicProjection {
                scale: 0.55,
                ..OrthographicProjection::default_3d()
            }),
            Transform::from_xyz(800., 600., 900.).looking_at(Vec3::new(480., 0., 384.), Vec3::Y),
            DistanceFog {
                color: Color::srgb(0.62, 0.77, 0.78),
                falloff: FogFalloff::Linear {
                    start: 600.,
                    end: 1500.,
                },
                ..default()
            },
            Main_Camera,
        ))
        .id();
    if cfg!(debug_assertions) && std::env::var("HOLLIE_OFFSCREEN").is_ok_and(|v| v == "1") {
        let mut target = Image::new_target_texture(
            1280,
            720,
            bevy::render::render_resource::TextureFormat::Rgba8UnormSrgb,
            None,
        );
        target.texture_descriptor.usage |= bevy::render::render_resource::TextureUsages::COPY_SRC;
        let handle = images.add(target);
        commands
            .entity(camera)
            .insert(bevy::camera::RenderTarget::Image(handle.clone().into()));
        commands.insert_resource(Offscreen_Target(handle));
    }
    commands.spawn((
        DirectionalLight {
            color: Color::srgb(1., 0.84, 0.60),
            illuminance: 12000.,
            shadow_maps_enabled: true,
            ..default()
        },
        Transform::from_xyz(-400., 700., 300.).looking_at(Vec3::ZERO, Vec3::Y),
        bevy::light::CascadeShadowConfigBuilder {
            first_cascade_far_bound: 900.,
            maximum_distance: 1800.,
            ..default()
        }
        .build(),
        Sun,
    ));
}
fn paint(
    materials: &mut Assets<Painted_Material>,
    color: Color,
    water: bool,
) -> Handle<Painted_Material> {
    materials.add(Painted_Material {
        base: StandardMaterial {
            base_color: color,
            perceptual_roughness: if water { 0.32 } else { 0.95 },
            reflectance: if water { 0.3 } else { 0.1 },
            ..default()
        },
        extension: Painted_Surface {
            parameters: Vec4::new(if water { 1. } else { 0. }, 0.12, 0.04, 0.),
        },
    })
}
fn box_mesh(
    commands: &mut Commands,
    mesh: Handle<Mesh>,
    material: Handle<Painted_Material>,
    bounds: Aabb,
) {
    commands.spawn((
        Mesh3d(mesh),
        MeshMaterial3d(material),
        Transform::from_translation((bounds.min + bounds.max) / 2.)
            .with_scale(bounds.max - bounds.min),
        Room_Visual,
    ));
}
fn rebuild_room(
    mut commands: Commands,
    game: Res<Game_World>,
    mode: Res<State<Mode>>,
    mut state: ResMut<Render_State>,
    visuals: Query<Entity, With<Room_Visual>>,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<Painted_Material>>,
    server: Res<AssetServer>,
) {
    if *mode.get() == Mode::Title {
        return;
    }
    if state.generation == game.generation {
        return;
    }
    for entity in &visuals {
        commands.entity(entity).despawn();
    }
    state.generation = game.generation;
    let cube = meshes.add(Cuboid::new(1., 1., 1.));
    let ground = paint(&mut materials, Color::WHITE, false);
    let water = paint(&mut materials, Color::srgb(0.12, 0.61, 0.68), true);
    let stone = paint(&mut materials, Color::srgb(0.48, 0.48, 0.40), false);
    let timber = paint(&mut materials, Color::srgb(0.52, 0.40, 0.27), false);
    let (land, pond) = terrain_meshes(&game.room);
    commands.spawn((
        Mesh3d(meshes.add(land)),
        MeshMaterial3d(ground.clone()),
        Transform::default(),
        Room_Visual,
    ));
    commands.spawn((
        Mesh3d(meshes.add(pond)),
        MeshMaterial3d(water),
        Transform::default(),
        Room_Visual,
    ));
    for b in game.static_obstacles() {
        box_mesh(&mut commands, cube.clone(), timber.clone(), b);
    }
    let mut grass_positions = Vec::new();
    let mut grass_normals = Vec::new();
    let mut grass_colors = Vec::new();
    let t = game.room.grid.tile_size as f32;
    for (i, tile) in game.room.layers.base.iter().enumerate() {
        if *tile == 0 || *tile == 500 || game.room.interior {
            continue;
        }
        let density = game.room.layers.grass.get(i).copied().unwrap_or(120) as u32;
        let x = (i % game.room.size.width) as f32 * t;
        let z = (i / game.room.size.width) as f32 * t;
        for blade in 0..density / 24 {
            let hash = hash(i as u32 * 11 + blade);
            let px = x + (hash & 255) as f32 / 255. * t;
            let pz = z + ((hash >> 8) & 255) as f32 / 255. * t;
            let height = 4. + ((hash >> 16) & 255) as f32 / 255. * 8.;
            let color = Color::srgb(0.42 + (hash & 15) as f32 / 100., 0.53, 0.20)
                .to_linear()
                .to_f32_array();
            for p in [
                [px - 0.65, 0.1, pz],
                [px + 0.65, 0.1, pz],
                [px + 1.5, height, pz + 1.0],
            ] {
                grass_positions.push(p);
                grass_normals.push([0., 1., 0.]);
                grass_colors.push(color);
            }
        }
        if game.room.layers.decoration.get(i).copied().unwrap_or(0) > 0 {
            let b = Aabb {
                min: Vec3::new(x + 6., 0., z + 6.),
                max: Vec3::new(x + 10., 4., z + 10.),
            };
            box_mesh(&mut commands, cube.clone(), stone.clone(), b);
        }
    }
    if !grass_positions.is_empty() {
        let grass_mesh = Mesh::new(
            PrimitiveTopology::TriangleList,
            RenderAssetUsages::default(),
        )
        .with_inserted_attribute(Mesh::ATTRIBUTE_POSITION, grass_positions.clone())
        .with_inserted_attribute(Mesh::ATTRIBUTE_NORMAL, grass_normals)
        .with_inserted_attribute(Mesh::ATTRIBUTE_COLOR, grass_colors);
        let grass_material = materials.add(Painted_Material {
            base: StandardMaterial {
                cull_mode: None,
                perceptual_roughness: 1.,
                ..default()
            },
            extension: default(),
        });
        commands.spawn((
            Mesh3d(meshes.add(grass_mesh)),
            MeshMaterial3d(grass_material),
            Transform::default(),
            Grass_Patch {
                phase: 0.,
                positions: grass_positions,
            },
            Room_Visual,
        ));
    }
    for actor in &game.actors {
        let file = match &actor.properties {
            Entity_Properties::Enemy(e) => e.kind.model(),
            Entity_Properties::Player(_) | Entity_Properties::Npc(_) => {
                "world/props/figurine-cube-raylib.glb"
            }
            Entity_Properties::Holdable(_) => "world/props/crate-color.glb",
            Entity_Properties::Pressure_Plate(_) => "world/props/button-floor-square-raylib.glb",
            _ => "",
        };
        if file.is_empty() {
            commands.spawn((
                Mesh3d(cube.clone()),
                MeshMaterial3d(stone.clone()),
                Transform::default(),
                Actor_Visual(actor.id),
                Room_Visual,
            ));
        } else {
            commands
                .spawn((
                    WorldAssetRoot(server.load(GltfAssetLabel::Scene(0).from_asset(file))),
                    Model {
                        gltf: server.load(file),
                    },
                    Transform::default(),
                    Actor_Visual(actor.id),
                    Room_Visual,
                ))
                .observe(model_ready);
        }
    }
    state.camera_target = player_center(&game);
}
fn hash(mut x: u32) -> u32 {
    x ^= x >> 16;
    x = x.wrapping_mul(0x7feb352d);
    x ^= x >> 15;
    x = x.wrapping_mul(0x846ca68b);
    x ^ (x >> 16)
}
fn clip_surface(triangle: [(Vec2, f32); 3], wet: bool) -> Vec<(Vec2, f32)> {
    let mut result = Vec::new();
    for i in 0..3 {
        let previous = triangle[(i + 2) % 3];
        let current = triangle[i];
        let inside = |v: f32| if wet { v > 0. } else { v <= 0. };
        if inside(previous.1) != inside(current.1) {
            let t = previous.1 / (previous.1 - current.1);
            result.push((previous.0.lerp(current.0, t), 0.));
        }
        if inside(current.1) {
            result.push(current);
        }
    }
    result
}
fn terrain_meshes(room: &Room) -> (Mesh, Mesh) {
    let (mut land, mut land_colors, mut water, mut water_uv) =
        (Vec::new(), Vec::new(), Vec::new(), Vec::new());
    let t = room.grid.tile_size as f32;
    for y in 0..room.size.height {
        for x in 0..room.size.width {
            let i = y * room.size.width + x;
            let tile = room.layers.base[i];
            if tile == 0 {
                continue;
            }
            let color = if room.interior {
                Color::srgb(0.55, 0.51, 0.39)
            } else if matches!(tile, 4..=6) {
                Color::srgb(0.77, 0.69, 0.45)
            } else {
                Color::srgb(0.44, 0.53, 0.24)
            }
            .to_linear()
            .to_f32_array();
            for row in 0..2 {
                for column in 0..2 {
                    let p =
                        Vec2::new(x as f32 + column as f32 * 0.5, y as f32 + row as f32 * 0.5) * t;
                    let corners = [
                        p,
                        p + Vec2::Y * t * 0.5,
                        p + Vec2::splat(t * 0.5),
                        p + Vec2::X * t * 0.5,
                    ];
                    for indices in [[0, 1, 2], [0, 2, 3]] {
                        let triangle = indices.map(|j| (corners[j], room.water_value(corners[j])));
                        for wet in [false, true] {
                            let polygon = clip_surface(triangle, wet);
                            for vertex in 1..polygon.len().saturating_sub(1) {
                                for (p, value) in [polygon[0], polygon[vertex], polygon[vertex + 1]]
                                {
                                    if wet {
                                        water.push([p.x, -1.5, p.y]);
                                        water_uv.push([value, 0.]);
                                    } else {
                                        land.push([p.x, -1.5 * (1. + value).clamp(0., 1.), p.y]);
                                        land_colors.push(color);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    let mesh = |positions: Vec<[f32; 3]>, uv: Vec<[f32; 2]>| {
        let n = positions.len();
        Mesh::new(
            PrimitiveTopology::TriangleList,
            RenderAssetUsages::default(),
        )
        .with_inserted_attribute(Mesh::ATTRIBUTE_POSITION, positions)
        .with_inserted_attribute(Mesh::ATTRIBUTE_NORMAL, vec![[0., 1., 0.]; n])
        .with_inserted_attribute(Mesh::ATTRIBUTE_UV_0, uv)
        .with_inserted_indices(Indices::U32((0..n as u32).collect()))
    };
    let land_uv = land.iter().map(|p| [p[0] / 64., p[2] / 64.]).collect();
    let mut land_mesh = mesh(land, land_uv);
    land_mesh.insert_attribute(Mesh::ATTRIBUTE_COLOR, land_colors);
    (land_mesh, mesh(water, water_uv))
}
fn model_ready(
    event: On<WorldInstanceReady>,
    mut commands: Commands,
    models: Query<(&Model, &Actor_Visual)>,
    gltfs: Res<Assets<Gltf>>,
    mut graphs: ResMut<Assets<AnimationGraph>>,
    animations: Res<Assets<AnimationClip>>,
    children: Query<&Children>,
    players: Query<(), With<AnimationPlayer>>,
    mesh_materials: Query<&MeshMaterial3d<StandardMaterial>>,
    standard: Res<Assets<StandardMaterial>>,
    mut painted: ResMut<Assets<Painted_Material>>,
) {
    let Ok((model, actor)) = models.get(event.entity) else {
        return;
    };
    let Some(gltf) = gltfs.get(&model.gltf) else {
        return;
    };
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
                let handle = painted.add(Painted_Material {
                    base: base.clone(),
                    extension: default(),
                });
                commands
                    .entity(descendant)
                    .remove::<MeshMaterial3d<StandardMaterial>>()
                    .insert(MeshMaterial3d(handle));
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
                },
            ));
        }
    }
}
pub(crate) fn sync_actors(
    game: Res<Game_World>,
    mode: Res<State<Mode>>,
    mut actors: Query<(
        Entity,
        &Actor_Visual,
        &mut Transform,
        &mut Visibility,
        Option<&Model>,
    )>,
    mut commands: Commands,
) {
    for (entity, reference, mut transform, mut visibility, model) in &mut actors {
        let Some(actor) = game.actors.iter().find(|a| a.id == reference.0) else {
            commands.entity(entity).despawn();
            continue;
        };
        *visibility = if actor.open || *mode.get() == Mode::Editor || *mode.get() == Mode::Title {
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
                actor.body.height,
                actor.body.position.y,
            );
            transform.scale = Vec3::splat(scale);
            transform.rotation = Quat::from_rotation_y(actor.facing.x.atan2(actor.facing.y));
        } else {
            transform.translation = (b.min + b.max) / 2.;
            transform.scale = actor.body.size;
        }
    }
}
fn animate_models(
    game: Res<Game_World>,
    mut players: Query<(&mut AnimationPlayer, &mut Actor_Animation)>,
) {
    for (mut player, mut animation) in &mut players {
        let Some(actor) = game.actors.iter().find(|a| a.id == animation.actor) else {
            continue;
        };
        let name = if let Entity_Properties::Pressure_Plate(_) = actor.properties {
            if actor.active {
                "toggle-on"
            } else {
                "toggle-off"
            }
        } else if actor.health <= 0 {
            "die"
        } else if actor.player().is_some() && actor.mounted.is_some() {
            "ride"
        } else if actor.carrying.is_some() {
            "walk-holding-both"
        } else if actor.body.velocity.length() > 1. {
            "walk"
        } else {
            "idle"
        };
        let Some(index) = animation
            .clips
            .get(name)
            .copied()
            .or_else(|| animation.clips.get("idle").copied())
        else {
            continue;
        };
        if animation.current != name {
            player.stop_all();
            player.play(index).repeat();
            animation.current = name.into();
            animation.changed_at = game.elapsed;
        }
        let duration = animation
            .durations
            .get(name)
            .or_else(|| animation.durations.get("idle"))
            .copied()
            .unwrap_or(1.)
            .max(0.001);
        if let Some(active) = player.animation_mut(index) {
            let seek = match name {
                "ride" => duration,
                "die" => actor.death_timer.min(duration),
                "toggle-on" | "toggle-off" => (game.elapsed - animation.changed_at).min(duration),
                _ => game.elapsed.rem_euclid(duration),
            };
            active.seek_to(seek);
            active.pause();
        }
    }
}
fn player_center(game: &Game_World) -> Vec3 {
    let players: Vec<_> = game
        .actors
        .iter()
        .filter(|a| a.player().is_some())
        .collect();
    if players.is_empty() {
        return Vec3::new(480., 0., 384.);
    }
    players
        .iter()
        .map(|a| Vec3::new(a.body.position.x, a.body.height.max(0.), a.body.position.y))
        .sum::<Vec3>()
        / players.len() as f32
}
fn follow_camera(
    game: Res<Game_World>,
    mode: Res<State<Mode>>,
    time: Res<Time>,
    mut state: ResMut<Render_State>,
    mut cameras: Query<(&mut Transform, &mut Projection), With<Main_Camera>>,
    editor: Res<crate::editor::Editor_State>,
) {
    if *mode.get() == Mode::Title {
        return;
    }
    let dt = time.delta_secs();
    let mut target = player_center(&game);
    if *mode.get() == Mode::Editor {
        target += Vec3::new(editor.camera_offset.x, 0., editor.camera_offset.y);
    }
    state.camera_target = state.camera_target.lerp(target, 1. - (-6. * dt).exp());
    let zoom = if *mode.get() == Mode::Editor {
        editor.zoom
    } else if game.dialog.is_some() {
        0.33
    } else if game
        .actors
        .iter()
        .any(|a| a.player().is_some() && a.mounted.is_some())
    {
        0.72
    } else {
        0.55
    };
    if state.zoom == 0. {
        state.zoom = zoom;
    }
    state.zoom += (zoom - state.zoom) * (1. - (-2.5 * dt).exp());
    #[cfg(debug_assertions)]
    if std::env::var_os("HOLLIE_CONTROL_DIR").is_some() {
        state.camera_target = target;
        state.zoom = zoom;
    }
    for (mut transform, mut projection) in &mut cameras {
        *transform = Transform::from_translation(state.camera_target + Vec3::splat(500.))
            .looking_at(state.camera_target, Vec3::Y);
        if let Projection::Orthographic(p) = &mut *projection {
            p.scale = state.zoom;
        }
    }
}
fn animate_environment(
    game: Res<Game_World>,
    mut materials: ResMut<Assets<Painted_Material>>,
    grass: Query<(&Grass_Patch, &Mesh3d)>,
    mut sun: Query<&mut DirectionalLight, With<Sun>>,
    mut ambient: ResMut<GlobalAmbientLight>,
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut effects: Query<(Entity, &Effect, &mut Transform), Without<Grass_Patch>>,
    mut state: ResMut<Render_State>,
    server: Res<AssetServer>,
    preferences: Res<crate::app::Preferences>,
) {
    for (_, m) in materials.iter_mut() {
        m.extension.parameters.w = game.elapsed;
    }
    for (patch, reference) in &grass {
        if let Some(mut mesh) = meshes.get_mut(&reference.0) {
            let positions: Vec<_> = patch
                .positions
                .iter()
                .map(|p| {
                    let mut position = *p;
                    if p[1] > 0.2 {
                        position[0] +=
                            (game.elapsed * 1.5 + patch.phase + p[0] * 0.07 + p[2] * 0.03).sin()
                                * p[1]
                                * 0.12;
                    }
                    position
                })
                .collect();
            mesh.insert_attribute(Mesh::ATTRIBUTE_POSITION, positions);
        }
    }
    for mut light in &mut sun {
        light.color = if game.night {
            Color::srgb(0.55, 0.65, 1.)
        } else {
            Color::srgb(1., 0.84, 0.60)
        };
        light.illuminance = if game.night { 1300. } else { 12000. };
    }
    ambient.brightness = if game.night { 85. } else { 420. };
    for (entity, effect, mut transform) in &mut effects {
        let age = game.elapsed - effect.born;
        if age > 0.7 {
            commands.entity(entity).despawn();
        } else {
            transform.translation = effect.origin + effect.velocity * age;
            transform.scale = Vec3::splat((1. - age / 0.7) * 2.);
        }
    }
    // Effects are consumed once per acknowledged simulation frame.
    if state.last_effect == (game.generation, game.frame) {
        return;
    }
    state.last_effect = (game.generation, game.frame);
    for (position, burst) in &game.effects {
        let mesh = meshes.add(Sphere::new(1.));
        let material = paint(&mut materials, Color::srgb(0.80, 0.71, 0.48), false);
        for i in 0..if *burst { 12 } else { 4 } {
            let angle = i as f32 * 2.4;
            commands.spawn((
                Mesh3d(mesh.clone()),
                MeshMaterial3d(material.clone()),
                Transform::from_translation(*position),
                Effect {
                    born: game.elapsed,
                    origin: *position,
                    velocity: Vec3::new(angle.cos() * 20., 8., angle.sin() * 20.),
                },
                Room_Visual,
            ));
        }
        commands.spawn((
            AudioPlayer::new(server.load("audio/fx/impact/hit-short-04.wav")),
            PlaybackSettings {
                mode: bevy::audio::PlaybackMode::Despawn,
                volume: bevy::audio::Volume::Linear(preferences.master * preferences.effects),
                ..default()
            },
        ));
    }
}
fn play_music(
    mut commands: Commands,
    game: Res<Game_World>,
    mode: Res<State<Mode>>,
    mut state: ResMut<Render_State>,
    server: Res<AssetServer>,
    music: Query<Entity, With<Music>>,
    preferences: Res<crate::app::Preferences>,
    mut sinks: Query<&mut AudioSink, With<Music>>,
) {
    let path = if *mode.get() == Mode::Title || game.room.music_path.is_empty() {
        "audio/music/ambient.ogg"
    } else {
        &game.room.music_path
    };
    if state.music != path {
        for entity in &music {
            commands.entity(entity).despawn();
        }
        commands.spawn((
            AudioPlayer::new(server.load(path.to_string())),
            PlaybackSettings::LOOP,
            Music,
        ));
        state.music = path.into();
    }
    for mut sink in &mut sinks {
        sink.set_volume(bevy::audio::Volume::Linear(
            preferences.master * preferences.music,
        ));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
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
