use super::*;
use bevy::camera::visibility::RenderLayers;

pub(super) const SKY: Color = Color::srgb(0.78, 0.85, 0.76);

#[derive(Resource, Default)]
pub(crate) struct Title_Scene {
    pub elapsed: f32,
    pub grass_vertices: usize,
}

fn ground_mesh() -> Mesh {
    let mut positions = Vec::new();
    let mut normals = Vec::new();
    let mut indices = Vec::new();
    for z in 0..=64 {
        for x in 0..=64 {
            let p = Vec2::new(x as f32 * 64. - 2048., z as f32 * 64. - 2648.);
            let a = p.x * 0.009 + p.y * 0.004;
            let b = p.y * 0.010;
            positions.push([p.x, a.sin() * 12. + b.sin() * 8. - 0.1, p.y]);
            normals.push(
                Vec3::new(-a.cos() * 0.108, 1., -a.cos() * 0.048 - b.cos() * 0.08)
                    .normalize()
                    .to_array(),
            );
            if x < 64 && z < 64 {
                let i = z * 65 + x;
                indices.extend([i, i + 65, i + 1, i + 1, i + 65, i + 66]);
            }
        }
    }
    Mesh::new(
        PrimitiveTopology::TriangleList,
        RenderAssetUsages::default(),
    )
    .with_inserted_attribute(Mesh::ATTRIBUTE_POSITION, positions)
    .with_inserted_attribute(Mesh::ATTRIBUTE_NORMAL, normals)
    .with_inserted_indices(Indices::U32(indices))
}

fn sky_mesh() -> Mesh {
    let mut mesh = Sphere::new(3000.).mesh().uv(64, 32);
    let Some(VertexAttributeValues::Float32x3(positions)) =
        mesh.attribute(Mesh::ATTRIBUTE_POSITION)
    else {
        unreachable!("sphere positions");
    };
    let colors: Vec<_> = positions
        .iter()
        .map(|p| {
            let t = (p[1] / 900.).clamp(0., 1.);
            Color::srgb(
                0.78 + (0.48 - 0.78) * t,
                0.85 + (0.70 - 0.85) * t,
                0.76 + (0.75 - 0.76) * t,
            )
            .to_linear()
            .to_f32_array()
        })
        .collect();
    mesh.insert_attribute(Mesh::ATTRIBUTE_COLOR, colors);
    mesh
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut meadows: ResMut<Assets<Meadow_Material>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    mut scene: ResMut<Title_Scene>,
) {
    // Keep title geometry independent of room loading and gameplay state.
    let patches = (-32..8).flat_map(|z| {
        (-20..20).map(move |x| {
            let density = if z < -16 {
                0.28
            } else if z < -6 {
                0.65
            } else {
                1.
            };
            (
                ((z + 32) * 40 + x + 20) as u32,
                Vec2::new(x as f32, z as f32) * 32.,
                density,
            )
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
    commands.spawn((
        Mesh3d(meshes.add(ground_mesh())),
        MeshMaterial3d(materials.add(StandardMaterial {
            base_color: Color::srgb(0.44, 0.65, 0.38),
            perceptual_roughness: 1.,
            ..default()
        })),
        Transform::default(),
        RenderLayers::layer(1),
    ));
    commands.spawn((
        Mesh3d(meshes.add(sky_mesh())),
        MeshMaterial3d(materials.add(StandardMaterial {
            unlit: true,
            cull_mode: None,
            fog_enabled: false,
            ..default()
        })),
        Transform::default(),
        bevy::light::NotShadowCaster,
        bevy::light::NotShadowReceiver,
        RenderLayers::layer(1),
    ));
    commands.spawn((
        Mesh3d(meshes.add(Sphere::new(36.))),
        MeshMaterial3d(materials.add(StandardMaterial {
            base_color: Color::srgb(0.97, 0.92, 0.74),
            unlit: true,
            fog_enabled: false,
            ..default()
        })),
        Transform::from_xyz(350., 230., -1100.),
        RenderLayers::layer(1),
    ));
}

pub(super) struct Title_Plugin;
impl Plugin for Title_Plugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Title_Scene>()
            .add_systems(Startup, setup);
    }
}
