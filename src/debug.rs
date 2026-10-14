use crate::{
    app::Mode,
    content::Entity_Properties,
    simulation::{Aabb, Game_World},
};
use bevy::{
    gizmos::{
        AppGizmoBuilder,
        config::{GizmoConfig, GizmoConfigGroup},
    },
    prelude::*,
};

#[derive(Resource, Default)]
pub(crate) struct Debug_State {
    pub enabled: bool,
    pub collider_count: usize,
}
#[derive(Default, Reflect, GizmoConfigGroup)]
struct Collider_Gizmos;
#[derive(Component)]
struct Debug_Label(Option<u64>);
pub(crate) struct Debug_Plugin;
impl Plugin for Debug_Plugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Debug_State>()
            .insert_gizmo_config(
                Collider_Gizmos,
                GizmoConfig {
                    depth_bias: -1.,
                    ..default()
                },
            )
            .add_systems(
                Update,
                (toggle_debug, draw_colliders)
                    .chain()
                    .after(crate::ui::menu_input),
            )
            .add_systems(
                PostUpdate,
                draw_labels
                    .after(bevy::transform::TransformSystems::Propagate)
                    .after(bevy::camera::CameraUpdateSystems),
            );
    }
}
fn toggle_debug(
    keys: Res<ButtonInput<KeyCode>>,
    pads: Query<&Gamepad>,
    controls: Res<crate::input::Controls>,
    mode: Res<State<Mode>>,
    controller: Res<crate::automation::Controller>,
    windows: Query<&Window>,
    mut debug: ResMut<Debug_State>,
) {
    if *mode.get() != Mode::Gameplay
        || crate::automation::waiting(&controller)
        || windows.iter().any(|w| !w.focused)
    {
        return;
    }
    let right_stick = controls.pads[0]
        .and_then(|id| pads.get(id).ok())
        .is_some_and(|pad| pad.just_pressed(GamepadButton::RightThumb));
    if keys.just_pressed(KeyCode::F3) || right_stick || controller.debug_toggle {
        debug.enabled = !debug.enabled;
    }
}
fn draw_colliders(
    game: Res<Game_World>,
    mode: Res<State<Mode>>,
    mut debug: ResMut<Debug_State>,
    mut gizmos: Gizmos<Collider_Gizmos>,
) {
    debug.collider_count = 0;
    if !debug.enabled || !matches!(mode.get(), Mode::Gameplay | Mode::Paused) {
        return;
    }
    let mut outline = |bounds: Aabb, color: Color| {
        let mut size = bounds.max - bounds.min;
        size.y = size.y.max(0.25);
        gizmos.cube(
            Transform::from_translation((bounds.min + bounds.max) * 0.5 + Vec3::Y * 0.01)
                .with_scale(size),
            color,
        );
        debug.collider_count += 1;
    };
    for bounds in game.static_obstacles() {
        outline(bounds, Color::srgb(1., 0.5, 0.1));
    }
    let tile = game.room.grid.tile_size as f32;
    for (i, value) in game.room.layers.collision.iter().enumerate() {
        if *value != 1 {
            continue;
        }
        let min = Vec3::new(
            (i % game.room.size.width) as f32 * tile,
            0.,
            (i / game.room.size.width) as f32 * tile,
        );
        outline(
            Aabb {
                min,
                max: min + Vec3::new(tile, 1., tile),
            },
            Color::srgb(1., 0.2, 0.2),
        );
    }
    for actor in &game.actors {
        if actor.open {
            continue;
        }
        let color = match actor.properties {
            Entity_Properties::Player(_) => Color::srgb(0.2, 1., 0.3),
            Entity_Properties::Enemy(_) => Color::srgb(1., 0.2, 0.2),
            Entity_Properties::Npc(_) => Color::WHITE,
            Entity_Properties::Holdable(_) => Color::srgb(1., 1., 0.2),
            Entity_Properties::Pressure_Plate(_) => Color::srgb(0.2, 0.4, 1.),
            Entity_Properties::Gate(_) => Color::srgb(0.2, 0.8, 1.),
            Entity_Properties::Door(_) => Color::srgb(0.8, 0.3, 1.),
        };
        outline(actor.body.bounds(), color);
    }
}
fn draw_labels(
    mut commands: Commands,
    game: Res<Game_World>,
    mode: Res<State<Mode>>,
    debug: Res<Debug_State>,
    cameras: Query<(&Camera, &GlobalTransform), With<Camera3d>>,
    windows: Query<&Window>,
    mut labels: Query<(Entity, &Debug_Label, &mut Node, &mut Visibility, &mut Text)>,
    mut last: Local<Option<(u64, bool)>>,
) {
    let show = debug.enabled && matches!(mode.get(), Mode::Gameplay | Mode::Paused);
    let key = (game.generation, show);
    if *last != Some(key) {
        for (entity, _, _, _, _) in &mut labels {
            commands.entity(entity).despawn();
        }
        if show {
            commands.spawn((
                Text::new("Debug colliders (R3 / F3)"),
                TextFont {
                    font_size: bevy::text::FontSize::Px(18.),
                    ..default()
                },
                Node {
                    position_type: PositionType::Absolute,
                    left: px(20),
                    bottom: px(20),
                    ..default()
                },
                GlobalZIndex(20),
                Pickable::IGNORE,
                Debug_Label(None),
            ));
            for actor in &game.actors {
                if let Entity_Properties::Door(ref door) = actor.properties {
                    commands.spawn((
                        Text::new(door.target_room_id.clone()),
                        TextFont {
                            font_size: bevy::text::FontSize::Px(18.),
                            ..default()
                        },
                        TextColor(Color::srgb(0.85, 0.5, 1.)),
                        BackgroundColor(Color::srgba(0., 0., 0., 0.7)),
                        Node {
                            position_type: PositionType::Absolute,
                            ..default()
                        },
                        GlobalZIndex(20),
                        Pickable::IGNORE,
                        Debug_Label(Some(actor.id)),
                    ));
                }
            }
        }
        *last = Some(key);
        return;
    }
    let Ok((camera, transform)) = cameras.single() else {
        return;
    };
    for (_, label, mut node, mut visibility, mut text) in &mut labels {
        let Some(id) = label.0 else {
            let size = camera.physical_viewport_size().unwrap_or_default();
            let window = windows
                .single()
                .map(|w| {
                    format!(
                        "{}x{} | scale {:.2}",
                        w.physical_width(),
                        w.physical_height(),
                        w.scale_factor()
                    )
                })
                .unwrap_or_else(|_| "offscreen".into());
            let message = format!(
                "Debug colliders (R3 / F3) | render {}x{} | window {window}",
                size.x, size.y
            );
            if text.0 != message {
                text.0 = message;
            }
            continue;
        };
        let point = game.actors.iter().find(|a| a.id == id).and_then(|actor| {
            let bounds = actor.body.bounds();
            camera
                .world_to_viewport(transform, (bounds.min + bounds.max) * 0.5 + Vec3::Y * 4.)
                .ok()
        });
        if let Some(point) = point {
            node.left = px(point.x);
            node.top = px(point.y);
            *visibility = Visibility::Inherited;
        } else {
            *visibility = Visibility::Hidden;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn native_right_stick_toggles_once_per_press_and_only_in_gameplay() {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, bevy::state::app::StatesPlugin))
            .init_state::<Mode>()
            .init_resource::<Debug_State>()
            .init_resource::<crate::automation::Controller>()
            .init_resource::<crate::input::Controls>()
            .init_resource::<ButtonInput<KeyCode>>()
            .add_systems(Update, toggle_debug);
        let pad = app.world_mut().spawn(Gamepad::default()).id();
        app.world_mut()
            .resource_mut::<crate::input::Controls>()
            .pads[0] = Some(pad);
        app.world_mut()
            .resource_mut::<NextState<Mode>>()
            .set(Mode::Gameplay);
        app.world_mut()
            .get_mut::<Gamepad>(pad)
            .unwrap()
            .digital_mut()
            .press(GamepadButton::RightThumb);
        app.update();
        assert!(app.world().resource::<Debug_State>().enabled);
        app.world_mut()
            .get_mut::<Gamepad>(pad)
            .unwrap()
            .digital_mut()
            .clear();
        app.update();
        assert!(app.world().resource::<Debug_State>().enabled);
        {
            let mut gamepad = app.world_mut().get_mut::<Gamepad>(pad).unwrap();
            gamepad.digital_mut().release(GamepadButton::RightThumb);
            gamepad.digital_mut().press(GamepadButton::RightThumb);
        }
        app.update();
        assert!(!app.world().resource::<Debug_State>().enabled);
        app.world_mut()
            .resource_mut::<NextState<Mode>>()
            .set(Mode::Editor);
        app.update();
        assert!(!app.world().resource::<Debug_State>().enabled);
    }
}
