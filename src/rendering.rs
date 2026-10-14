use crate::{app::Mode, content::*, simulation::*};
use bevy::{
    app::AnimationSystems, camera::primitives::MeshAabb, gltf::GltfMesh,
    transform::TransformSystems,
};
use bevy::{
    asset::RenderAssetUsages,
    image::{CompressedImageFormats, ImageSampler, ImageType},
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

#[derive(Asset, AsBindGroup, Reflect, Debug, Clone)]
pub struct Painted_Surface {
    #[uniform(100)]
    pub parameters: Vec4,
    #[uniform(101)]
    pub water: Water_Uniform,
}
impl Default for Painted_Surface {
    fn default() -> Self {
        Self {
            parameters: Vec4::new(0., 0.04, 0.04, 0.),
            water: default(),
        }
    }
}
#[derive(ShaderType, Reflect, Debug, Clone)]
pub struct Water_Uniform {
    pub contacts: [Vec4; 16],
    pub headings: [Vec4; 16],
    pub starts: [Vec4; 64],
    pub ends: [Vec4; 64],
}
impl Default for Water_Uniform {
    fn default() -> Self {
        Self {
            contacts: [Vec4::ZERO; 16],
            headings: [Vec4::ZERO; 16],
            starts: [Vec4::ZERO; 64],
            ends: [Vec4::ZERO; 64],
        }
    }
}
#[derive(ShaderType, Reflect, Debug, Clone)]
pub struct Meadow_Uniform {
    pub time: Vec4,
    pub contacts: [Vec4; 32],
    pub motion: [Vec4; 32],
    pub trails: [Vec4; 64],
    pub trail_motion: [Vec4; 64],
}
impl Default for Meadow_Uniform {
    fn default() -> Self {
        Self {
            time: Vec4::ZERO,
            contacts: [Vec4::ZERO; 32],
            motion: [Vec4::ZERO; 32],
            trails: [Vec4::ZERO; 64],
            trail_motion: [Vec4::ZERO; 64],
        }
    }
}
#[derive(Asset, AsBindGroup, Reflect, Debug, Clone, Default)]
pub struct Meadow_Surface {
    #[uniform(100)]
    pub meadow: Meadow_Uniform,
}
impl MaterialExtension for Meadow_Surface {
    fn vertex_shader() -> ShaderRef {
        "shaders/grass_vertex.wesl".into()
    }
    fn prepass_vertex_shader() -> ShaderRef {
        "shaders/grass_vertex.wesl".into()
    }
    fn fragment_shader() -> ShaderRef {
        "shaders/grass_fragment.wesl".into()
    }
}
pub type Meadow_Material = ExtendedMaterial<StandardMaterial, Meadow_Surface>;
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
    previous: Vec<(AnimationNodeIndex, f32, f32)>,
}
#[derive(Component)]
struct Bone_Overlay {
    actor: u64,
    turn: bool,
    ram: bool,
    pivot: Option<Entity>,
}
#[derive(Component)]
struct Actor_Material {
    actor: u64,
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
    actor: u64,
    root: Entity,
    seat: Option<Bone_Anchor>,
    arms: [Option<Bone_Bounds>; 2],
    head: Option<Bone_Bounds>,
}
#[derive(Resource, Default)]
struct Render_State {
    generation: u64,
    camera_target: Vec3,
    zoom: f32,
    music: String,
    last_effect: (u64, u32),
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
            .add_plugins(MaterialPlugin::<Meadow_Material>::default())
            .init_resource::<Render_State>()
            .init_resource::<Scene_Stats>()
            .add_systems(Startup, setup)
            .add_systems(
                PostUpdate,
                (overlay_bones, attach_carried_and_riders)
                    .chain()
                    .after(AnimationSystems)
                    .before(TransformSystems::Propagate),
            )
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
fn game_camera_projection() -> Projection {
    Projection::Orthographic(OrthographicProjection {
        scale: 1. / 1.8,
        scaling_mode: bevy::camera::ScalingMode::FixedVertical {
            viewport_height: 450.,
        },
        near: 0.1,
        far: 10000.,
        ..OrthographicProjection::default_3d()
    })
}
fn setup(mut commands: Commands, mut images: ResMut<Assets<Image>>) {
    let image = Image::from_buffer(
        include_bytes!("../assets/hollie-background.png"),
        ImageType::Extension("png"),
        CompressedImageFormats::NONE,
        true,
        ImageSampler::linear(),
        RenderAssetUsages::default(),
    )
    .expect("reference background PNG");
    commands.insert_resource(Title_Background(images.add(image)));
    commands.insert_resource(ClearColor(Color::srgb(0.47, 0.72, 0.77)));
    commands.insert_resource(GlobalAmbientLight {
        color: Color::srgb(0.72, 0.82, 0.94),
        brightness: 650.,
        ..default()
    });
    let camera = commands
        .spawn((
            Camera3d::default(),
            IsDefaultUiCamera,
            bevy::render::view::DebandDither::Disabled,
            Msaa::Sample4,
            game_camera_projection(),
            Transform::from_xyz(800., 600., 900.).looking_at(Vec3::new(480., 0., 384.), Vec3::Y),
            DistanceFog {
                color: Color::srgb(0.62, 0.77, 0.78),
                falloff: FogFalloff::Linear {
                    start: 2400.,
                    end: 5000.,
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
            color: Color::srgb(1., 0.94, 0.85),
            illuminance: 6500.,
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
            parameters: Vec4::new(if water { 1. } else { 0. }, 0.04, 0.04, 0.),
            water: default(),
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
fn spawn_static_model(
    commands: &mut Commands,
    server: &AssetServer,
    file: &str,
    transform: Transform,
) {
    let file = format!("world/props/{file}");
    commands.spawn((
        WorldAssetRoot(server.load(GltfAssetLabel::Scene(0).from_asset(file.clone()))),
        Model {
            gltf: server.load(file),
        },
        transform,
        Room_Visual,
    ));
}
fn rebuild_room(
    mut commands: Commands,
    game: Res<Game_World>,
    mode: Res<State<Mode>>,
    mut state: ResMut<Render_State>,
    mut stats: ResMut<Scene_Stats>,
    visuals: Query<Entity, With<Room_Visual>>,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<Painted_Material>>,
    mut meadows: ResMut<Assets<Meadow_Material>>,
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
    materials.get_mut(&ground).unwrap().extension.parameters.x =
        if game.room.interior { 0. } else { 2. };
    let water = paint(&mut materials, Color::srgb(0.12, 0.61, 0.68), true);
    materials.get_mut(&water).unwrap().extension.parameters.z = game.room.grid.tile_size as f32;
    let stone = paint(&mut materials, Color::srgb(0.48, 0.48, 0.40), false);
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
    let roof = paint(
        &mut materials,
        Color::srgb(120. / 255., 150. / 255., 105. / 255.),
        false,
    );
    for house in &game.room.structures {
        let x = house.position.x as f32;
        let z = house.position.y as f32;
        let w = house.size.width as f32;
        let d = house.size.height as f32;
        for (file, position, yaw, scale) in [
            (
                "wall-doorway-wide.glb",
                Vec3::new(x + w / 2., 0., z + d),
                std::f32::consts::FRAC_PI_2,
                Vec3::new(8., 44., w / 1.5),
            ),
            (
                "wall.glb",
                Vec3::new(x + w / 2., 0., z),
                std::f32::consts::FRAC_PI_2,
                Vec3::new(8., 44., w),
            ),
            (
                "wall.glb",
                Vec3::new(x, 0., z + d / 2.),
                0.,
                Vec3::new(8., 44., d),
            ),
            (
                "wall.glb",
                Vec3::new(x + w, 0., z + d / 2.),
                0.,
                Vec3::new(8., 44., d),
            ),
        ] {
            spawn_static_model(
                &mut commands,
                &server,
                file,
                Transform::from_translation(position)
                    .with_rotation(Quat::from_rotation_y(yaw))
                    .with_scale(scale),
            );
        }
        box_mesh(
            &mut commands,
            cube.clone(),
            roof.clone(),
            Aabb {
                min: Vec3::new(x - 4., 44., z - 4.),
                max: Vec3::new(x + w + 4., 51., z + d + 4.),
            },
        );
    }
    if game.room.interior {
        let t = game.room.grid.tile_size as f32;
        for y in 0..game.room.size.height {
            for x in 0..game.room.size.width {
                if game.room.layers.base[y * game.room.size.width + x] == 0 {
                    continue;
                }
                for (dx, dy, yaw) in [
                    (0, -1, std::f32::consts::FRAC_PI_2),
                    (0, 1, std::f32::consts::FRAC_PI_2),
                    (-1, 0, 0.),
                    (1, 0, 0.),
                ] {
                    let nx = x as i32 + dx;
                    let ny = y as i32 + dy;
                    if nx >= 0
                        && ny >= 0
                        && (nx as usize) < game.room.size.width
                        && (ny as usize) < game.room.size.height
                        && game.room.layers.base[ny as usize * game.room.size.width + nx as usize]
                            != 0
                    {
                        continue;
                    }
                    let p = Vec3::new(
                        (x as f32 + 0.5 + dx as f32 * 0.5) * t,
                        0.,
                        (y as f32 + 0.5 + dy as f32 * 0.5) * t,
                    );
                    if game.actors.iter().any(|a| {
                        matches!(a.properties, Entity_Properties::Door(_))
                            && a.body.bounds().horizontal(Aabb {
                                min: p - Vec3::splat(0.1),
                                max: p + Vec3::splat(0.1),
                            })
                    }) {
                        continue;
                    }
                    spawn_static_model(
                        &mut commands,
                        &server,
                        "wall.glb",
                        Transform::from_translation(p)
                            .with_rotation(Quat::from_rotation_y(yaw))
                            .with_scale(Vec3::new(7.5, 12., t)),
                    );
                }
            }
        }
    }
    let grass_mesh = meadow_mesh(&game.room);
    stats.grass_vertices = grass_mesh.count_vertices();
    if stats.grass_vertices > 0 {
        let material = meadows.add(Meadow_Material {
            base: StandardMaterial {
                cull_mode: None,
                double_sided: true,
                perceptual_roughness: 1.,
                reflectance: 0.05,
                ..default()
            },
            extension: default(),
        });
        commands.spawn((
            Mesh3d(meshes.add(grass_mesh)),
            MeshMaterial3d(material),
            Transform::default(),
            Room_Visual,
        ));
    }
    let t = game.room.grid.tile_size as f32;
    for (i, tile) in game.room.layers.decoration.iter().enumerate() {
        if *tile > 0 {
            let x = (i % game.room.size.width) as f32 * t;
            let z = (i / game.room.size.width) as f32 * t;
            box_mesh(
                &mut commands,
                cube.clone(),
                stone.clone(),
                Aabb {
                    min: Vec3::new(x + 6., 0., z + 6.),
                    max: Vec3::new(x + 10., 4., z + 10.),
                },
            );
        }
    }
    for actor in &game.actors {
        if matches!(actor.properties, Entity_Properties::Door(_)) {
            continue;
        }
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
fn meadow_noise(p: Vec2) -> f32 {
    let cell = p.floor();
    let f = p - cell;
    let u = f * f * (Vec2::splat(3.) - f * 2.);
    let random = |x: f32, y: f32| {
        let n = hash(
            (x as i32 as u32)
                .wrapping_mul(137)
                .wrapping_add((y as i32 as u32).wrapping_mul(311)),
        );
        n as f32 / u32::MAX as f32
    };
    let a = random(cell.x, cell.y);
    let b = random(cell.x + 1., cell.y);
    let c = random(cell.x, cell.y + 1.);
    let d = random(cell.x + 1., cell.y + 1.);
    (a + (b - a) * u.x) * (1. - u.y) + (c + (d - c) * u.x) * u.y
}
fn meadow_mesh(room: &Room) -> Mesh {
    let (mut positions, mut roots, mut colors, mut indices) =
        (Vec::new(), Vec::new(), Vec::new(), Vec::new());
    let size = room.grid.tile_size as f32;
    if !room.interior {
        for (i, tile) in room.layers.base.iter().enumerate() {
            if *tile == 0 || *tile == 500 {
                continue;
            }
            let density = room.layers.grass.get(i).copied().unwrap_or(0) as f32 / 255.;
            let x = (i % room.size.width) as f32 * size;
            let z = (i / room.size.width) as f32 * size;
            for blade in 0..36_u32 {
                let seed = (i as u32).wrapping_mul(251) + blade * 7;
                let random = |offset| hash(seed + offset) as f32 / u32::MAX as f32;
                if random(5) > density {
                    continue;
                }
                let root = Vec3::new(
                    x + (blade % 6) as f32 * size / 6. + (0.2 + random(0) * 0.6) * size / 6.,
                    0.04,
                    z + (blade / 6) as f32 * size / 6. + (0.2 + random(1) * 0.6) * size / 6.,
                );
                if room.water_at(Vec2::new(root.x, root.z)) {
                    continue;
                }
                let height =
                    6.4 + meadow_noise(Vec2::new(root.x, root.z) * 0.035) * 2.4 + random(2) * 0.8;
                let angle = -std::f32::consts::FRAC_PI_4 + (random(3) - 0.5) * 1.1;
                let width = Vec3::new(angle.cos(), 0., angle.sin()) * (0.85 + random(4) * 0.3);
                let shoulder = root + Vec3::Y * height * 0.58;
                let tip = root + Vec3::Y * height;
                let base = positions.len() as u32;
                for p in [
                    root - width,
                    root + width,
                    shoulder + width * 0.62,
                    shoulder - width * 0.62,
                    tip,
                ] {
                    positions.push(p.to_array());
                    roots.push([root.x, root.z]);
                    colors.push([1., 1., 1., height / 12.]);
                }
                for index in [0, 1, 2, 0, 2, 3, 3, 2, 4] {
                    indices.push(base + index);
                }
            }
        }
    }
    let count = positions.len();
    Mesh::new(
        PrimitiveTopology::TriangleList,
        RenderAssetUsages::default(),
    )
    .with_inserted_attribute(Mesh::ATTRIBUTE_POSITION, positions)
    .with_inserted_attribute(Mesh::ATTRIBUTE_NORMAL, vec![[0., 1., 0.]; count])
    .with_inserted_attribute(Mesh::ATTRIBUTE_UV_0, roots)
    .with_inserted_attribute(Mesh::ATTRIBUTE_COLOR, colors)
    .with_inserted_indices(Indices::U32(indices))
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
    let mut shores = Vec::new();
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
                Color::srgb(0.49, 0.72, 0.38)
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
                            if wet {
                                let boundary: Vec<_> = polygon
                                    .iter()
                                    .filter(|(_, value)| value.abs() < 0.00001)
                                    .map(|(p, _)| *p)
                                    .collect();
                                if boundary.len() == 2
                                    && boundary[0].distance_squared(boundary[1]) > 0.0001
                                {
                                    shores.push((boundary[0], boundary[1]));
                                }
                            }
                            for vertex in 1..polygon.len().saturating_sub(1) {
                                for (p, value) in [polygon[0], polygon[vertex], polygon[vertex + 1]]
                                {
                                    if wet {
                                        water.push([p.x, -1.5, p.y]);
                                        water_uv.push([value * t * 1.5, 0.]);
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
    for (vertex, uv) in water.iter().zip(&mut water_uv) {
        let p = Vec2::new(vertex[0], vertex[2]);
        uv[0] = shores
            .iter()
            .map(|(a, b)| {
                let line = *b - *a;
                let t = (p - *a).dot(line) / line.length_squared();
                p.distance(*a + line * t.clamp(0., 1.))
            })
            .fold(t * 4., f32::min);
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
    game: Res<Game_World>,
    gltfs: Res<Assets<Gltf>>,
    gltf_meshes: Res<Assets<GltfMesh>>,
    meshes: Res<Assets<Mesh>>,
    bones: Query<(&Name, &Transform, Option<&ChildOf>)>,
    skins: Query<(&Mesh3d, &SkinnedMesh)>,
    inverse_bindposes: Res<Assets<SkinnedMeshInverseBindposes>>,
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
    let tint = game
        .actors
        .iter()
        .find(|a| a.id == actor.0)
        .map_or(Color::WHITE, |a| {
            if let Some(player) = a.player() {
                if player == 0 {
                    Color::srgb(92. / 255., 156. / 255., 214. / 255.)
                } else {
                    Color::srgb(102. / 255., 190. / 255., 132. / 255.)
                }
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
pub(crate) fn sync_actors(
    game: Res<Game_World>,
    mode: Res<State<Mode>>,
    mut actors: Query<(
        Entity,
        &Actor_Visual,
        &mut Transform,
        &mut Visibility,
        Option<&Model>,
        Option<&Model_Foot>,
    )>,
    mut commands: Commands,
) {
    for (entity, reference, mut transform, mut visibility, model, foot) in &mut actors {
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
                actor.body.height - foot.map_or(0., |f| f.0) * scale,
                actor.body.position.y,
            );
            transform.scale = Vec3::splat(scale);
            let yaw = Quat::from_rotation_y(
                actor.facing.x.atan2(actor.facing.y) + crate::visuals::animal_axis(actor.kind()),
            );
            let forward = Vec3::new(actor.facing.x, 0., actor.facing.y);
            let animal = crate::visuals::animal_axis(actor.kind()) != 0.;
            let axis = if animal {
                forward
            } else {
                Vec3::new(actor.facing.y, 0., -actor.facing.x)
            };
            let mut bank = actor.pose.lean;
            if actor.kind() == Some(Character_Kind::Bison) {
                transform.translation.y += actor.pose.bison_bob(actor.body.velocity.length());
                bank += (actor.pose.phase * std::f32::consts::TAU).sin()
                    * 3_f32.to_radians()
                    * (actor.body.velocity.length() / 140.).clamp(0., 1.);
            }
            if actor.player().is_some() && actor.mounted.is_some() {
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
fn animate_models(
    game: Res<Game_World>,
    mut players: Query<(&mut AnimationPlayer, &mut Actor_Animation)>,
) {
    for (mut player, mut animation) in &mut players {
        let Some(actor) = game.actors.iter().find(|a| a.id == animation.actor) else {
            continue;
        };
        let animal = crate::visuals::animal_axis(actor.kind()) != 0.;
        let airborne = !actor.body.grounded && !actor.body.swimming;
        let speed = actor.body.velocity.length();
        let phase = actor.pose.phase;
        let name = if matches!(actor.properties, Entity_Properties::Pressure_Plate(_)) {
            if actor.active {
                "toggle-on"
            } else {
                "toggle-off"
            }
        } else if actor.health <= 0 {
            "die"
        } else if actor.mounted.is_some() && actor.player().is_some() {
            "ride"
        } else if actor.carrying.is_some() {
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
                    .mounted
                    .and_then(|id| game.actors.iter().find(|a| a.id == id))
                    .map_or(0., |a| {
                        ((a.body.velocity.length() - 50.) / 110.).clamp(0., 1.)
                    }),
                "toggle-on" | "toggle-off" => (game.elapsed - animation.changed_at) / duration,
                "die" => actor.death_timer / duration,
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
fn overlay_bones(game: Res<Game_World>, mut bones: Query<(Entity, &Bone_Overlay, &mut Transform)>) {
    let pivots: HashMap<_, _> = bones
        .iter()
        .map(|(entity, _, transform)| (entity, transform.translation))
        .collect();
    for (_, overlay, mut transform) in &mut bones {
        let Some(actor) = game.actors.iter().find(|a| a.id == overlay.actor) else {
            continue;
        };
        let mount = actor
            .mounted
            .filter(|_| actor.player().is_some())
            .and_then(|id| game.actors.iter().find(|a| a.id == id));
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
fn transformed_bounds(matrix: Mat4, bounds: Aabb) -> Aabb {
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
fn attach_carried_and_riders(
    mut game: ResMut<Game_World>,
    skeletons: Query<&Skeleton>,
    bones: Query<(&Transform, Option<&ChildOf>), Without<Actor_Visual>>,
    mut actors: Query<(&Actor_Visual, &mut Transform, Option<&Model_Foot>)>,
) {
    let mut riding_points = Vec::new();
    let mut held_points = Vec::new();
    let roots: HashMap<_, _> = actors.iter().map(|(v, t, _)| (v.0, *t)).collect();
    let rigs: HashMap<_, _> = skeletons.iter().map(|s| (s.actor, s)).collect();
    let point = |rig: &Skeleton, anchor: Bone_Anchor| {
        bone_in_root(anchor.bone, rig.root, &bones).map(|m| m.transform_point3(anchor.point))
    };
    for (reference, mut transform, foot) in &mut actors {
        let Some(actor) = game.actors.iter().find(|a| a.id == reference.0) else {
            continue;
        };
        if let Some(mount) = actor
            .mounted
            .filter(|_| actor.player().is_some())
            .and_then(|id| game.actors.iter().find(|a| a.id == id))
        {
            if let (Some(mount_rig), Some(rider_rig), Some(mount_root)) = (
                rigs.get(&mount.id),
                rigs.get(&actor.id),
                roots.get(&mount.id),
            ) {
                if let (Some(saddle), Some(seat)) = (
                    mount_rig.seat.and_then(|a| point(mount_rig, a)),
                    rider_rig.seat.and_then(|a| point(rider_rig, a)),
                ) {
                    let progress = ((actor.mount_time / 0.4 - 0.7) / 0.3).clamp(0., 1.);
                    let bank = mount_root.rotation
                        * Quat::from_rotation_y(
                            -(mount.facing.x.atan2(mount.facing.y)
                                + crate::visuals::animal_axis(mount.kind())),
                        );
                    let rotation =
                        bank * Quat::from_rotation_y(actor.facing.x.atan2(actor.facing.y));
                    let target = mount_root.transform_point(saddle) - rotation * (seat * 32.);
                    transform.translation = transform.translation.lerp(target, progress);
                    transform.rotation = transform.rotation.slerp(rotation, progress);
                    let anchor = transform.transform_point(Vec3::Y * foot.map_or(0., |f| f.0));
                    riding_points.push((
                        actor.id,
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
        if let Some(carrier) = actor
            .held_by
            .and_then(|id| game.actors.iter().find(|a| a.id == id))
        {
            if let (Some(rig), Some(root)) = (rigs.get(&carrier.id), roots.get(&carrier.id)) {
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
                        actor.id,
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
    for (id, point, origin) in riding_points {
        if let Some(actor) = game.actors.iter_mut().find(|a| a.id == id) {
            actor.riding_anchor = Some(point);
            actor.riding_origin = Some(origin);
        }
    }
    for (id, point, origin) in held_points {
        if let Some(actor) = game.actors.iter_mut().find(|a| a.id == id) {
            actor.held_anchor = Some(point);
            actor.held_origin = Some(origin);
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
fn bounded_camera_target(mut target: Vec3, room: &Room, viewport: Vec2, zoom: f32) -> Vec3 {
    let bounds = &room.camera_bounds;
    let half = Vec2::new(450. * viewport.x / viewport.y, 450.) * zoom * 0.5;
    let clamp_axis = |value: f32, start: f32, size: f32, half: f32| {
        if size > half * 2. {
            value.clamp(start + half, start + size - half)
        } else {
            start + size * 0.5
        }
    };
    target.x = clamp_axis(target.x, bounds.x, bounds.width, half.x);
    target.z = clamp_axis(target.z, bounds.y, bounds.height, half.y);
    target
}
fn follow_camera(
    game: Res<Game_World>,
    mode: Res<State<Mode>>,
    time: Res<Time>,
    mut state: ResMut<Render_State>,
    mut cameras: Query<(&Camera, &mut Transform, &mut Projection), With<Main_Camera>>,
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
    if *mode.get() != Mode::Editor {
        let viewport = cameras
            .iter()
            .next()
            .and_then(|(camera, _, _)| camera.logical_viewport_size())
            .unwrap_or(Vec2::new(1280., 720.));
        target = bounded_camera_target(
            target,
            &game.room,
            viewport,
            if state.zoom > 0. {
                state.zoom
            } else {
                1. / 1.8
            },
        );
    }
    state.camera_target = state.camera_target.lerp(target, 1. - (-6. * dt).exp());
    let zoom = if *mode.get() == Mode::Editor {
        editor.zoom
    } else if game.dialog.is_some() {
        1. / 3.
    } else if game
        .actors
        .iter()
        .any(|a| a.player().is_some() && a.mounted.is_some())
    {
        1. / 1.4
    } else {
        1. / 1.8
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
    for (_, mut transform, mut projection) in &mut cameras {
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
    mut meadows: ResMut<Assets<Meadow_Material>>,
    actor_materials: Query<(&Actor_Material, &MeshMaterial3d<Painted_Material>)>,
    mut sun: Query<&mut DirectionalLight, With<Sun>>,
    mut ambient: ResMut<GlobalAmbientLight>,
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut effects: Query<(Entity, &Effect, &mut Transform), With<Effect>>,
    mut state: ResMut<Render_State>,
    server: Res<AssetServer>,
    preferences: Res<crate::app::Preferences>,
) {
    for (_, m) in materials.iter_mut() {
        m.extension.parameters.w = game.elapsed;
    }
    for (reference, handle) in &actor_materials {
        if let (Some(actor), Some(mut material)) = (
            game.actors.iter().find(|a| a.id == reference.actor),
            materials.get_mut(&handle.0),
        ) {
            let color = reference.base.to_linear().to_f32_array();
            material.base.base_color = Color::linear_rgba(
                color[0],
                color[1] * (1. - 0.70 * actor.pose.ram),
                color[2] * (1. - 0.76 * actor.pose.ram),
                color[3],
            );
        }
    }
    let mut water = Water_Uniform::default();
    for (i, c) in game.surfaces.water.iter().enumerate() {
        water.contacts[i] = Vec4::new(c.position.x, c.position.y, c.radii.x, c.radii.y);
        water.headings[i] = Vec4::new(c.direction.x, c.direction.y, c.speed, 1.);
    }
    for (i, w) in game.surfaces.wakes.iter().enumerate() {
        water.starts[i] = Vec4::new(w.start.x, w.start.y, w.width, w.age / 1.3);
        water.ends[i] = Vec4::new(w.end.x, w.end.y, w.strength, 1.);
    }
    for (_, m) in materials.iter_mut() {
        if m.extension.parameters.x == 1. {
            m.extension.water = water.clone();
        }
    }
    let mut meadow = Meadow_Uniform::default();
    meadow.time = Vec4::new(
        game.elapsed,
        game.surfaces.grass.len() as f32,
        game.surfaces.grass_trails.len() as f32,
        0.,
    );
    for (i, c) in game.surfaces.grass.iter().enumerate() {
        meadow.contacts[i] = Vec4::new(c.position.x, c.position.y, c.radius, c.strength);
        meadow.motion[i] = Vec4::new(c.direction.x, c.direction.y, 0., 0.);
    }
    for (i, c) in game.surfaces.grass_trails.iter().enumerate() {
        let remaining = (1. - c.age / 2.6).clamp(0., 1.);
        meadow.trails[i] = Vec4::new(
            c.position.x,
            c.position.y,
            c.radius,
            c.strength * remaining * remaining * (3. - 2. * remaining),
        );
        meadow.trail_motion[i] = Vec4::new(c.direction.x, c.direction.y, 0., 0.);
    }
    for (_, m) in meadows.iter_mut() {
        m.extension.meadow = meadow.clone();
    }
    for mut light in &mut sun {
        light.color = if game.night {
            Color::srgb(0.55, 0.65, 1.)
        } else {
            Color::srgb(1., 0.94, 0.85)
        };
        light.illuminance = if game.night { 1300. } else { 6500. };
    }
    ambient.brightness = if game.night { 85. } else { 650. };
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
    if state.last_effect == (game.generation, game.elapsed.to_bits()) {
        return;
    }
    state.last_effect = (game.generation, game.elapsed.to_bits());
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
