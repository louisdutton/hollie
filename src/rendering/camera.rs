use super::*;

pub(super) fn game_camera_projection() -> Projection {
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
            bevy::camera::ShadowLodOrigin,
            bevy::camera::visibility::RenderLayers::default(),
        ))
        .id();
    if cfg!(debug_assertions) && std::env::var("HOLLIE_OFFSCREEN").is_ok_and(|v| v == "1") {
        let size = std::env::var("HOLLIE_CAPTURE_SIZE").unwrap_or_else(|_| "1280x720".into());
        let (width, height) = size
            .split_once('x')
            .expect("capture size must be WIDTHxHEIGHT");
        let mut target = Image::new_target_texture(
            width.parse().expect("capture width must be positive"),
            height.parse().expect("capture height must be positive"),
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
        bevy::camera::visibility::RenderLayers::default(),
    ));
}
pub(super) fn player_center(game: &Game_View) -> Vec3 {
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
pub(super) fn bounded_camera_target(
    mut target: Vec3,
    room: &Room,
    viewport: Vec2,
    zoom: f32,
) -> Vec3 {
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
pub(super) fn follow_camera(
    game: Game_View,
    mode: Res<State<Mode>>,
    time: Res<Time>,
    mut state: ResMut<Camera_State>,
    mut cameras: Query<
        (
            &Camera,
            &mut Transform,
            &mut Projection,
            &mut DistanceFog,
            &mut bevy::camera::visibility::RenderLayers,
        ),
        With<Main_Camera>,
    >,
    editor: Res<crate::editor::Editor_State>,
    #[cfg(debug_assertions)] controller: Res<crate::automation::Controller>,
) {
    if *mode.get() == Mode::Tree_Study {
        return;
    }
    if *mode.get() == Mode::Title {
        for (_, mut transform, mut projection, mut fog, mut layers) in &mut cameras {
            *transform =
                Transform::from_xyz(0., 48., 220.).looking_at(Vec3::new(32., 42., -170.), Vec3::Y);
            *projection = Projection::Perspective(PerspectiveProjection {
                fov: 53_f32.to_radians(),
                far: 5000.,
                ..default()
            });
            fog.color = title::SKY;
            fog.falloff = FogFalloff::Linear {
                start: 350.,
                end: 1300.,
            };
            *layers = bevy::camera::visibility::RenderLayers::layer(1);
        }
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
            .and_then(|(camera, _, _, _, _)| camera.logical_viewport_size())
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
    state.camera_target.smooth_nudge(&target, 6., dt);
    let zoom = if *mode.get() == Mode::Editor {
        editor.zoom
    } else if game.dialog.is_some() {
        1. / 3.
    } else if game
        .actors
        .iter()
        .any(|a| a.player().is_some() && a.mounted().is_some())
    {
        1. / 1.4
    } else {
        1. / 1.8
    };
    if state.zoom == 0. {
        state.zoom = zoom;
    }
    state.zoom.smooth_nudge(&zoom, 2.5, dt);
    #[cfg(debug_assertions)]
    if controller.enabled() {
        state.camera_target = target;
        state.zoom = zoom;
    }
    for (_, mut transform, mut projection, mut fog, mut layers) in &mut cameras {
        *layers = bevy::camera::visibility::RenderLayers::default();
        fog.color = Color::srgb(0.62, 0.77, 0.78);
        fog.falloff = FogFalloff::Linear {
            start: 2400.,
            end: 5000.,
        };
        if !matches!(*projection, Projection::Orthographic(_)) {
            *projection = game_camera_projection();
        }
        *transform = Transform::from_translation(state.camera_target + Vec3::splat(500.))
            .looking_at(state.camera_target, Vec3::Y);
        if let Projection::Orthographic(p) = &mut *projection {
            p.scale = state.zoom;
        }
    }
}

#[derive(Resource, Default)]
pub(super) struct Camera_State {
    pub(super) camera_target: Vec3,
    zoom: f32,
}
pub(super) struct Camera_Plugin;
impl Plugin for Camera_Plugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Camera_State>()
            .add_systems(Startup, setup)
            .add_systems(
                Update,
                follow_camera.in_set(crate::app::Game_Systems::Presentation),
            );
    }
}
