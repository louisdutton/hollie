use super::*;

fn update_materials(
    game: Game_View,
    mode: Res<State<Mode>>,
    time: Res<Time>,
    mut title: ResMut<title::Title_Scene>,
    #[cfg(debug_assertions)] controller: Res<crate::automation::Controller>,
    mut materials: ResMut<Assets<Painted_Material>>,
    mut meadows: ResMut<Assets<Meadow_Material>>,
    actor_materials: Query<(&Actor_Material, &MeshMaterial3d<Painted_Material>)>,
) {
    if *mode.get() == Mode::Title {
        let dt = time.delta_secs();
        #[cfg(debug_assertions)]
        let dt = if crate::automation::waiting(&controller) {
            0.
        } else if controller.stepping {
            STEP
        } else {
            dt
        };
        title.elapsed += dt;
    }
    for (_, m) in materials.iter_mut() {
        m.extension.parameters.w = game.elapsed;
    }
    for (reference, handle) in &actor_materials {
        if let (Some(actor), Some(mut material)) = (
            game.actors.get(reference.actor).ok(),
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
    let mut meadow = Meadow_Uniform {
        time: Vec4::new(
            game.elapsed,
            game.surfaces.grass.len() as f32,
            game.surfaces.grass_trails.len() as f32,
            0.,
        ),
        ..default()
    };
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
        m.extension.meadow = if *mode.get() == Mode::Title {
            Meadow_Uniform {
                time: Vec4::new(title.elapsed, 0., 0., 1.),
                ..default()
            }
        } else {
            meadow.clone()
        };
    }
}
fn update_lighting(
    game: Res<Game_State>,
    mode: Res<State<Mode>>,
    mut clear: ResMut<ClearColor>,
    mut sun: Query<&mut DirectionalLight, With<Sun>>,
    mut ambient: ResMut<GlobalAmbientLight>,
) {
    let night = game.night && *mode.get() != Mode::Title;
    clear.0 = if *mode.get() == Mode::Title {
        title::SKY
    } else {
        Color::srgb(0.47, 0.72, 0.77)
    };
    for mut light in &mut sun {
        light.color = if night {
            Color::srgb(0.55, 0.65, 1.)
        } else {
            Color::srgb(1., 0.94, 0.85)
        };
        light.illuminance = if night { 1300. } else { 6500. };
    }
    ambient.brightness = if night { 85. } else { 650. };
}
fn animate_effects(
    game: Res<Game_State>,
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<Painted_Material>>,
    mut effects: Query<(Entity, &Effect, &mut Transform)>,
    mut impacts: MessageReader<crate::simulation::Impact>,
) {
    for (entity, effect, mut transform) in &mut effects {
        let age = game.elapsed - effect.born;
        if age > 0.7 {
            commands.entity(entity).despawn();
        } else {
            transform.translation = effect.origin + effect.velocity * age;
            transform.scale = Vec3::splat((1. - age / 0.7) * 2.);
        }
    }
    for impact in impacts
        .read()
        .filter(|impact| impact.generation == game.generation)
    {
        let position = impact.position;
        let mesh = meshes.add(Sphere::new(1.));
        let material = paint(&mut materials, Color::srgb(0.80, 0.71, 0.48), false);
        for i in 0..if impact.burst { 12 } else { 4 } {
            let angle = i as f32 * 2.4;
            commands.spawn((
                Mesh3d(mesh.clone()),
                MeshMaterial3d(material.clone()),
                Transform::from_translation(position),
                Effect {
                    born: impact.born,
                    origin: position,
                    velocity: Vec3::new(angle.cos() * 20., 8., angle.sin() * 20.),
                },
                Room_Visual,
            ));
        }
    }
}
pub(super) struct Environment_Plugin;
impl Plugin for Environment_Plugin {
    fn build(&self, app: &mut App) {
        app.add_systems(
            Update,
            (update_materials, update_lighting, animate_effects)
                .in_set(crate::app::Game_Systems::Presentation),
        );
    }
}
