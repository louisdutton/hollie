use crate::{app::Mode, simulation::Player_Input};
use bevy::prelude::*;

#[derive(Resource)]
pub struct Key_Bindings {
    pub keyboard: [KeyCode; 8],
}
impl Default for Key_Bindings {
    fn default() -> Self {
        Self {
            keyboard: [
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
    pub player: Player_Input,
    pub pad: Option<Entity>,
}
fn axis(keys: &ButtonInput<KeyCode>, positive: KeyCode, negative: KeyCode) -> f32 {
    (keys.pressed(positive) as u8 as f32) - (keys.pressed(negative) as u8 as f32)
}
fn collect_input(
    keys: Res<ButtonInput<KeyCode>>,
    pads: Query<(Entity, &Gamepad)>,
    bindings: Res<Key_Bindings>,
    mode: Res<State<Mode>>,
    transition: Res<crate::transition::Scene_Transition>,
    windows: Query<&Window>,
    mut controls: ResMut<Controls>,
) {
    if controls.pad.is_some_and(|entity| !pads.contains(entity)) {
        controls.pad = None;
    }
    if controls.pad.is_none() {
        controls.pad = pads.iter().map(|(entity, _)| entity).next();
    }
    let b = bindings.keyboard;
    let mut input = Player_Input {
        movement: Vec2::new(axis(&keys, b[3], b[2]), axis(&keys, b[1], b[0])).clamp_length_max(1.),
        jump: keys.just_pressed(b[4]),
        interact: keys.just_pressed(b[5]),
    };
    if let Some(entity) = controls.pad {
        if let Ok((_, pad)) = pads.get(entity) {
            let stick = pad.left_stick();
            if stick.length() > 0.15 {
                input.movement = Vec2::new(stick.x, -stick.y).clamp_length_max(1.);
            }
            input.jump |= pad.just_pressed(GamepadButton::South);
            input.interact |= pad.just_pressed(GamepadButton::West);
        }
    }
    let active =
        *mode.get() == Mode::Gameplay && !transition.busy() && windows.iter().all(|w| w.focused);
    if !active {
        input.movement = Vec2::ZERO;
    }
    input.jump = active && (input.jump || controls.player.jump);
    input.interact = active && (input.interact || controls.player.interact);
    controls.player = input;
}

pub struct Input_Plugin;
impl Plugin for Input_Plugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Controls>()
            .init_resource::<Key_Bindings>()
            .add_systems(PreUpdate, collect_input.after(bevy::input::InputSystems));
    }
}
