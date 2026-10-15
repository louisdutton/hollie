use super::models::model_ready;
use super::*;

pub(super) fn paint(
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
    game: Game_View,
    mut state: Local<Option<u64>>,
    mut camera: ResMut<Camera_State>,
    mut stats: ResMut<Scene_Stats>,
    visuals: Query<Entity, With<Room_Visual>>,
    assets: Room_Assets,
) {
    let Room_Assets {
        mut meshes,
        mut materials,
        mut meadows,
        server,
    } = assets;
    if *state == Some(game.generation) {
        return;
    }
    for entity in &visuals {
        commands.entity(entity).despawn();
    }
    *state = Some(game.generation);
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
                Actor_Visual(actor.entity),
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
                    Actor_Visual(actor.entity),
                    Room_Visual,
                ))
                .observe(model_ready);
        }
    }
    camera.camera_target = player_center(&game);
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
pub(super) fn clip_surface(triangle: [(Vec2, f32); 3], wet: bool) -> Vec<(Vec2, f32)> {
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

pub(super) struct Room_Plugin;
impl Plugin for Room_Plugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Scene_Stats>().add_systems(
            Update,
            rebuild_room
                .in_set(crate::app::Game_Systems::Room)
                .run_if(not(in_state(Mode::Title))),
        );
    }
}

#[derive(bevy::ecs::system::SystemParam)]
struct Room_Assets<'w> {
    meshes: ResMut<'w, Assets<Mesh>>,
    materials: ResMut<'w, Assets<Painted_Material>>,
    meadows: ResMut<'w, Assets<Meadow_Material>>,
    server: Res<'w, AssetServer>,
}
