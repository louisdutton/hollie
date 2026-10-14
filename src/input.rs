use crate::{app::Mode, simulation::Player_Input};
use bevy::prelude::*;

#[derive(Resource)]
pub struct Key_Bindings {
    pub player_one: [KeyCode; 8],
}
impl Default for Key_Bindings {
    fn default() -> Self {
        Self {
            player_one: [
                KeyCode::KeyW,
                KeyCode::KeyS,
                KeyCode::KeyA,
                KeyCode::KeyD,
                KeyCode::KeyH,
                KeyCode::KeyJ,
                KeyCode::KeyP,
                KeyCode::KeyR,
            ],
        }
    }
}
#[derive(Resource, Default)]
pub struct Controls {
    pub players: [Player_Input; 2],
    pub pads: [Option<Entity>; 2],
}
fn axis(keys: &ButtonInput<KeyCode>, positive: KeyCode, negative: KeyCode) -> f32 {
    (keys.pressed(positive) as u8 as f32) - (keys.pressed(negative) as u8 as f32)
}
pub fn collect_input(
    keys: Res<ButtonInput<KeyCode>>,
    pads: Query<(Entity, &Gamepad)>,
    bindings: Res<Key_Bindings>,
    mode: Res<State<Mode>>,
    windows: Query<&Window>,
    mut controls: ResMut<Controls>,
) {
    for slot in &mut controls.pads {
        if slot.is_some_and(|e| !pads.contains(e)) {
            *slot = None;
        }
    }
    for (entity, _) in &pads {
        if !controls.pads.contains(&Some(entity)) {
            if let Some(slot) = controls.pads.iter_mut().find(|slot| slot.is_none()) {
                *slot = Some(entity);
            }
        }
    }
    let b = bindings.player_one;
    let mut inputs = [
        Player_Input {
            movement: Vec2::new(axis(&keys, b[3], b[2]), axis(&keys, b[1], b[0]))
                .clamp_length_max(1.),
            jump: keys.just_pressed(b[4]),
            interact: keys.just_pressed(b[5]),
        },
        Player_Input {
            movement: Vec2::new(
                axis(&keys, KeyCode::ArrowRight, KeyCode::ArrowLeft),
                axis(&keys, KeyCode::ArrowDown, KeyCode::ArrowUp),
            )
            .clamp_length_max(1.),
            jump: keys.just_pressed(KeyCode::Semicolon),
            interact: keys.just_pressed(KeyCode::KeyL),
        },
    ];
    for (index, entity) in controls.pads.iter().enumerate() {
        if let Some(entity) = entity {
            if let Ok((_, pad)) = pads.get(*entity) {
                let stick = pad.left_stick();
                if stick.length() > 0.15 {
                    inputs[index].movement = Vec2::new(stick.x, -stick.y).clamp_length_max(1.);
                }
                inputs[index].jump |= pad.just_pressed(GamepadButton::South);
                inputs[index].interact |= pad.just_pressed(GamepadButton::West);
            }
        }
    }
    let active = *mode.get() == Mode::Gameplay && windows.iter().all(|w| w.focused);
    for (input, previous) in inputs.iter_mut().zip(&controls.players) {
        input.jump = active && (input.jump || previous.jump);
        input.interact = active && (input.interact || previous.interact);
    }
    controls.players = inputs;
}

pub struct Input_Plugin;
impl Plugin for Input_Plugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Controls>()
            .init_resource::<Key_Bindings>()
            .add_systems(PreUpdate, collect_input.after(bevy::input::InputSystems));
    }
}
