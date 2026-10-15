use super::*;
use bevy::{
    camera::visibility::RenderLayers,
    light::{FogVolume, VolumetricFog, VolumetricLight},
};

mod forest;

pub(super) const SKY: Color = Color::srgb(0.14, 0.28, 0.27);

#[derive(Resource, Default)]
pub(crate) struct Title_Scene {
    pub elapsed: f32,
    pub grass_vertices: usize,
}
#[derive(Component)]
struct Canopy;
#[derive(Component)]
struct Title_Sun;
#[derive(Component)]
struct Mote {
    origin: Vec3,
    phase: f32,
}

fn terrain_height(p: Vec2) -> f32 {
    (p.x * 0.009 + p.y * 0.004).sin() * 12. + (p.y * 0.010).sin() * 8.
}

fn clearing(p: Vec2) -> f32 {
    let path_x = 40. + (p.y * 0.009).sin() * 24.;
    let path = ((p.x - path_x).abs() - 15.) / 38.;
    let glade = (p.distance(Vec2::new(65., -180.)) - 52.) / 70.;
    path.min(glade).clamp(0., 1.)
}

fn ground_mesh() -> Mesh {
    let mut positions = Vec::new();
    let mut normals = Vec::new();
    let mut colors = Vec::new();
    let mut indices = Vec::new();
    for z in 0..=96 {
        for x in 0..=96 {
            let p = Vec2::new(x as f32 * 24. - 1152., z as f32 * 24. - 1752.);
            let a = p.x * 0.009 + p.y * 0.004;
            let b = p.y * 0.010;
            positions.push([p.x, terrain_height(p) - 0.1, p.y]);
            normals.push(
                Vec3::new(-a.cos() * 0.108, 1., -a.cos() * 0.048 - b.cos() * 0.08)
                    .normalize()
                    .to_array(),
            );
            let grass = clearing(p);
            colors.push(
                Color::srgb(
                    0.26 - grass * 0.07,
                    0.27 + grass * 0.07,
                    0.16 + grass * 0.01,
                )
                .to_linear()
                .to_f32_array(),
            );
            if x < 96 && z < 96 {
                let i = z * 97 + x;
                indices.extend([i, i + 97, i + 1, i + 1, i + 97, i + 98]);
            }
        }
    }
    Mesh::new(
        PrimitiveTopology::TriangleList,
        RenderAssetUsages::default(),
    )
    .with_inserted_attribute(Mesh::ATTRIBUTE_POSITION, positions)
    .with_inserted_attribute(Mesh::ATTRIBUTE_NORMAL, normals)
    .with_inserted_attribute(Mesh::ATTRIBUTE_COLOR, colors)
    .with_inserted_indices(Indices::U32(indices))
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut meadows: ResMut<Assets<Meadow_Material>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    mut scene: ResMut<Title_Scene>,
) {
    // Independent title assets and lights never load or mutate a gameplay room.
    let patches = (-28..6).flat_map(|z| {
        (-20..20).map(move |x| {
            let p = Vec2::new(x as f32, z as f32) * 32.;
            let density = clearing(p + Vec2::splat(16.)) * if z < -16 { 0.28 } else { 0.85 };
            (((z + 28) * 40 + x + 20) as u32, p, density)
        })
    });
    let grass = room::grass_mesh(patches, 32., |_| false);
    scene.grass_vertices = grass.count_vertices();
    commands.spawn((
        Mesh3d(meshes.add(grass)),
        MeshMaterial3d(meadows.add(Meadow_Material {
            base: StandardMaterial {
                cull_mode: None,
                double_sided: true,
                reflectance: 0.05,
                ..default()
            },
            extension: default(),
        })),
        Transform::default(),
        RenderLayers::layer(1),
    ));
    let matte = materials.add(StandardMaterial {
        perceptual_roughness: 1.,
        reflectance: 0.08,
        ..default()
    });
    commands.spawn((
        Mesh3d(meshes.add(ground_mesh())),
        MeshMaterial3d(matte.clone()),
        Transform::default(),
        RenderLayers::layer(1),
    ));
    let (wood, leaves, floor) = forest::build();
    for mesh in [wood, floor] {
        commands.spawn((
            Mesh3d(meshes.add(mesh)),
            MeshMaterial3d(matte.clone()),
            Transform::default(),
            RenderLayers::layer(1),
        ));
    }
    commands.spawn((
        Mesh3d(meshes.add(leaves)),
        MeshMaterial3d(materials.add(StandardMaterial {
            cull_mode: None,
            double_sided: true,
            perceptual_roughness: 0.86,
            reflectance: 0.12,
            ..default()
        })),
        Transform::default(),
        RenderLayers::layer(1),
        Canopy,
    ));
    commands.spawn((
        DirectionalLight {
            color: Color::srgb(1., 0.92, 0.74),
            illuminance: 18000.,
            shadow_maps_enabled: true,
            ..default()
        },
        Transform::from_xyz(240., 420., -300.).looking_at(Vec3::new(20., 0., -100.), Vec3::Y),
        bevy::light::CascadeShadowConfigBuilder {
            first_cascade_far_bound: 300.,
            maximum_distance: 1500.,
            ..default()
        }
        .build(),
        VolumetricLight,
        Title_Sun,
        RenderLayers::layer(1),
    ));
    commands.spawn((
        FogVolume {
            density_factor: 0.0015,
            scattering: 0.35,
            absorption: 0.08,
            scattering_asymmetry: 0.6,
            fog_color: Color::srgb(0.86, 0.91, 0.79),
            light_intensity: 1.2,
            ..default()
        },
        Transform::from_xyz(0., 150., -400.).with_scale(Vec3::new(1800., 500., 1800.)),
    ));
    let mote_mesh = meshes.add(Sphere::new(0.32).mesh().uv(6, 4));
    let mote_material = materials.add(StandardMaterial {
        base_color: Color::srgb(1., 0.91, 0.53),
        emissive: LinearRgba::new(2.2, 1.7, 0.55, 1.),
        unlit: true,
        ..default()
    });
    for i in 0..60 {
        let phase = i as f32 * 2.399963;
        let origin = Vec3::new(
            phase.sin() * 200. + 40.,
            12. + (i * 37 % 97) as f32,
            -(i * 73 % 430) as f32 + 50.,
        );
        commands.spawn((
            Mesh3d(mote_mesh.clone()),
            MeshMaterial3d(mote_material.clone()),
            Transform::from_translation(origin),
            bevy::light::NotShadowCaster,
            RenderLayers::layer(1),
            Mote { origin, phase },
        ));
    }
}

fn advance_time(
    mode: Res<State<Mode>>,
    time: Res<Time>,
    mut scene: ResMut<Title_Scene>,
    #[cfg(debug_assertions)] controller: Res<crate::automation::Controller>,
) {
    if *mode.get() != Mode::Title {
        return;
    }
    let dt = time.delta_secs();
    #[cfg(debug_assertions)]
    let dt = if crate::automation::waiting(&controller) {
        0.
    } else if controller.stepping {
        STEP
    } else {
        dt
    };
    scene.elapsed += dt;
}

fn animate(
    scene: Res<Title_Scene>,
    mut canopy: Query<&mut Transform, (With<Canopy>, Without<Mote>)>,
    mut motes: Query<(&Mote, &mut Transform)>,
) {
    let t = scene.elapsed;
    for mut transform in &mut canopy {
        transform.translation = Vec3::new(
            (t * 0.35).sin() * 1.8,
            (t * 0.27).sin() * 0.6,
            (t * 0.23).sin() * 1.2,
        );
    }
    for (mote, mut transform) in &mut motes {
        transform.translation = mote.origin
            + Vec3::new(
                (t * 0.23 + mote.phase).sin() * 9.,
                (t * 0.3 + mote.phase).sin() * 5.,
                (t * 0.19 + mote.phase).cos() * 7.,
            );
        transform.scale = Vec3::splat(0.6 + (t * 0.8 + mote.phase).sin() * 0.3);
    }
}

fn configure_view(
    mut commands: Commands,
    mode: Res<State<Mode>>,
    cameras: Query<(Entity, Has<VolumetricFog>), With<Main_Camera>>,
    lights: Query<(Entity, Has<VolumetricLight>), With<Title_Sun>>,
) {
    for (entity, volumetric) in &cameras {
        if !volumetric {
            commands.entity(entity).insert(VolumetricFog {
                ambient_intensity: 0.,
                step_count: 64,
                ..default()
            });
        }
    }
    // Keep the view registered: Bevy clears all private fog-pass state when
    // its last volumetric light is disabled, but not when a view removes fog.
    for (entity, volumetric) in &lights {
        if *mode.get() == Mode::Title && !volumetric {
            commands.entity(entity).insert(VolumetricLight);
        } else if *mode.get() != Mode::Title && volumetric {
            commands.entity(entity).remove::<VolumetricLight>();
        }
    }
}

pub(super) struct Title_Plugin;
impl Plugin for Title_Plugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Title_Scene>()
            .add_systems(Startup, setup)
            .add_systems(Update, advance_time.in_set(crate::app::Game_Systems::Room))
            .add_systems(
                Update,
                (configure_view, animate).in_set(crate::app::Game_Systems::Presentation),
            );
    }
}
