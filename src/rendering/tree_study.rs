use super::*;
use bevy::camera::visibility::RenderLayers;

#[derive(Clone, Copy, Debug, Default)]
pub(crate) enum Study_Light {
    #[default]
    Daylight,
    Reverse,
    Dim,
    Sunset,
    Moonlight,
    Lantern,
    Darkness,
    Ambient,
}

#[derive(Resource, Default)]
pub(crate) struct Tree_Study {
    pub preset: Study_Light,
    yaw: f32,
    sun_turn: f32,
}
impl Tree_Study {
    pub(crate) fn caption(&self) -> String {
        format!(
            "Tree study — {:?}\n\nLeft / Right   Orbit tree\nL   Turn sun\nD   Daylight    R   Reverse sun\nF   Dim daylight    E   Sunset\nN   Moonlight    P   Lantern\nA   Ambient only    B   No lights\nEsc   Return to title",
            self.preset
        )
    }
}
#[derive(Component)]
pub(crate) struct Study_Sun;
#[derive(Component)]
pub(crate) struct Study_Lamp;
#[derive(Component)]
pub(crate) struct Tree_Specimen;

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    mut woodlands: ResMut<Assets<Woodland_Material>>,
    mut study: ResMut<Tree_Study>,
) {
    *study = default();
    let (wood, leaves) = title::forest::study_tree();
    let bark = woodlands.add(woodland_material(Woodland_Kind::Bark));
    let foliage = woodlands.add(woodland_material(Woodland_Kind::Canopy));
    commands
        .spawn((
            Transform::default(),
            Visibility::default(),
            Tree_Specimen,
            DespawnOnExit(Mode::Tree_Study),
        ))
        .with_children(|tree| {
            for (mesh, material) in [(wood, bark), (leaves, foliage)] {
                tree.spawn((
                    Mesh3d(meshes.add(mesh)),
                    MeshMaterial3d(material),
                    RenderLayers::layer(2),
                ));
            }
        });
    commands.spawn((
        Mesh3d(meshes.add(Plane3d::default().mesh().size(10000., 10000.))),
        MeshMaterial3d(materials.add(StandardMaterial {
            base_color: Color::srgb(0.55, 0.52, 0.43),
            perceptual_roughness: 1.,
            reflectance: 0.,
            ..default()
        })),
        Transform::from_xyz(0., -0.5, 0.),
        RenderLayers::layer(2),
        DespawnOnExit(Mode::Tree_Study),
    ));
    commands.spawn((
        DirectionalLight {
            shadow_maps_enabled: true,
            ..default()
        },
        Transform::default(),
        Study_Sun,
        RenderLayers::layer(2),
        bevy::light::CascadeShadowConfigBuilder {
            first_cascade_far_bound: 450.,
            maximum_distance: 1200.,
            ..default()
        }
        .build(),
        DespawnOnExit(Mode::Tree_Study),
    ));
    commands.spawn((
        PointLight {
            intensity: 0.,
            range: 700.,
            radius: 12.,
            shadow_map_near_z: 5.,
            shadow_normal_bias: 1.2,
            color: Color::srgb(1., 0.48, 0.18),
            shadow_maps_enabled: true,
            ..default()
        },
        Transform::from_xyz(0., 170., 220.),
        Study_Lamp,
        RenderLayers::layer(2),
        DespawnOnExit(Mode::Tree_Study),
    ));
}

fn controls(
    keys: Res<ButtonInput<KeyCode>>,
    time: Res<Time>,
    mut study: ResMut<Tree_Study>,
    #[cfg(debug_assertions)] controller: Res<crate::automation::Controller>,
) {
    #[cfg(debug_assertions)]
    if crate::automation::waiting(&controller) {
        return;
    }
    for (key, preset) in [
        (KeyCode::KeyD, Study_Light::Daylight),
        (KeyCode::KeyR, Study_Light::Reverse),
        (KeyCode::KeyF, Study_Light::Dim),
        (KeyCode::KeyE, Study_Light::Sunset),
        (KeyCode::KeyN, Study_Light::Moonlight),
        (KeyCode::KeyP, Study_Light::Lantern),
        (KeyCode::KeyB, Study_Light::Darkness),
        (KeyCode::KeyA, Study_Light::Ambient),
    ] {
        if keys.just_pressed(key) {
            study.preset = preset;
            study.sun_turn = 0.;
        }
    }
    if keys.just_pressed(KeyCode::KeyL) {
        study.sun_turn += std::f32::consts::FRAC_PI_4;
    }
    let dt = time.delta_secs();
    #[cfg(debug_assertions)]
    let dt = if controller.stepping { STEP } else { dt };
    study.yaw += (keys.pressed(KeyCode::ArrowRight) as u8 as f32
        - keys.pressed(KeyCode::ArrowLeft) as u8 as f32)
        * dt
        * 0.8;
}

fn present(
    study: Res<Tree_Study>,
    mut clear: ResMut<ClearColor>,
    mut ambient: ResMut<GlobalAmbientLight>,
    mut sun: Query<(&mut DirectionalLight, &mut Transform), With<Study_Sun>>,
    mut lamps: Query<&mut PointLight, With<Study_Lamp>>,
    mut cameras: Query<
        (
            &mut Transform,
            &mut Projection,
            &mut DistanceFog,
            &mut RenderLayers,
        ),
        (With<Main_Camera>, Without<Study_Sun>),
    >,
) {
    clear.0 = Color::srgb(0.73, 0.72, 0.65);
    let (position, colour, illuminance, fill) = match study.preset {
        Study_Light::Daylight => (
            Vec3::new(-250., 380., 320.),
            Color::srgb(1., 0.94, 0.82),
            18000.,
            400.,
        ),
        Study_Light::Reverse => (
            Vec3::new(250., 380., -320.),
            Color::srgb(1., 0.94, 0.82),
            18000.,
            400.,
        ),
        Study_Light::Dim => (
            Vec3::new(-250., 380., 320.),
            Color::srgb(1., 0.94, 0.82),
            3600.,
            80.,
        ),
        Study_Light::Sunset => (
            Vec3::new(-250., 180., 320.),
            Color::srgb(1., 0.48, 0.22),
            6500.,
            40.,
        ),
        Study_Light::Moonlight => (
            Vec3::new(-250., 380., 320.),
            Color::srgb(0.36, 0.50, 1.),
            650.,
            12.,
        ),
        Study_Light::Lantern | Study_Light::Darkness => {
            (Vec3::new(-250., 380., 320.), Color::WHITE, 0., 0.)
        }
        Study_Light::Ambient => (Vec3::new(-250., 380., 320.), Color::WHITE, 0., 400.),
    };
    ambient.color = Color::WHITE;
    ambient.brightness = fill;
    for (mut light, mut transform) in &mut sun {
        light.color = colour;
        light.illuminance = illuminance;
        *transform = Transform::from_translation(Quat::from_rotation_y(study.sun_turn) * position)
            .looking_at(Vec3::new(0., 120., 0.), Vec3::Y);
    }
    for mut lamp in &mut lamps {
        lamp.intensity = if matches!(study.preset, Study_Light::Lantern) {
            2_000_000_000.
        } else {
            0.
        };
    }
    for (mut transform, mut projection, mut fog, mut layers) in &mut cameras {
        let offset = Quat::from_rotation_y(study.yaw) * Vec3::new(140., 40., 450.);
        *transform = Transform::from_translation(Vec3::Y * 145. + offset)
            .looking_at(Vec3::Y * 145., Vec3::Y);
        *projection = Projection::Perspective(PerspectiveProjection {
            fov: 42_f32.to_radians(),
            far: 3000.,
            ..default()
        });
        fog.color = clear.0;
        fog.falloff = FogFalloff::Linear {
            start: 1000.,
            end: 3000.,
        };
        *layers = RenderLayers::layer(2);
    }
}

pub(super) struct Tree_Study_Plugin;
impl Plugin for Tree_Study_Plugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Tree_Study>()
            .add_systems(OnEnter(Mode::Tree_Study), setup)
            .add_systems(
                Update,
                controls
                    .run_if(in_state(Mode::Tree_Study))
                    .in_set(crate::app::Game_Systems::Actions),
            )
            .add_systems(
                Update,
                present
                    .run_if(in_state(Mode::Tree_Study))
                    .in_set(crate::app::Game_Systems::Presentation),
            );
    }
}
