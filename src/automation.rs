use crate::{
    app::Mode,
    simulation::{Game_Access, Game_State, Game_View, Game_World, Player_Input, STEP},
};
use anyhow::{Result, ensure};
use bevy::{
    prelude::*,
    render::view::screenshot::{Screenshot, ScreenshotCaptured},
};
use serde::Deserialize;
use serde_json::{Value, json};
use std::{
    collections::BTreeSet,
    fs,
    io::Write,
    path::{Path, PathBuf},
};

#[derive(Clone, Default, Deserialize)]
#[serde(deny_unknown_fields)]
struct Gamepad_Input {
    player: String,
    #[serde(default)]
    axes: Vec<f32>,
    #[serde(default)]
    buttons: Vec<String>,
}
#[derive(Clone, Default, Deserialize)]
#[serde(deny_unknown_fields)]
struct Command {
    id: u64,
    op: String,
    room: Option<String>,
    players: Option<usize>,
    seed: Option<u64>,
    frames: Option<u32>,
    #[serde(default)]
    keys: Vec<String>,
    #[serde(default)]
    gamepads: Vec<Gamepad_Input>,
    #[serde(default)]
    capture: String,
}
#[derive(Resource, Default)]
pub(crate) struct Controller {
    pub(crate) stepping: bool,
    pub(crate) debug_toggle: bool,
    directory: Option<PathBuf>,
    last_id: u64,
    pending: Option<Pending>,
    previous_keys: BTreeSet<String>,
    previous_buttons: [BTreeSet<String>; 2],
    ready_frames: u32,
    render_on_demand: bool,
}
struct Pending {
    id: u64,
    error: String,
    capture: String,
    remaining: u32,
    inputs: [Player_Input; 2],
    debug_toggle: bool,
    keys: Vec<KeyCode>,
    settle: u32,
    screenshot: bool,
    stop: bool,
}
pub struct Automation_Plugin;
impl Plugin for Automation_Plugin {
    fn build(&self, app: &mut App) {
        let directory = std::env::var_os("HOLLIE_CONTROL_DIR").map(PathBuf::from);
        if let Some(path) = &directory {
            assert!(
                path.is_dir(),
                "HOLLIE_CONTROL_DIR must be an existing private directory"
            );
        }
        app.insert_resource(Controller {
            render_on_demand: directory.is_some()
                && std::env::var("HOLLIE_OFFSCREEN").as_deref() == Ok("1")
                && std::env::var("HOLLIE_AUTOMATION_REALTIME").as_deref() != Ok("1")
                && std::env::var("HOLLIE_AUTOMATION_RENDER_EVERY_TICK").as_deref() != Ok("1"),
            directory,
            ..default()
        })
        .add_systems(Update, poll.in_set(crate::app::Game_Systems::Automation))
        .add_systems(
            Update,
            activate_capture_camera.after(crate::app::Game_Systems::Automation),
        )
        .add_systems(Last, respond);
    }
}
fn activate_capture_camera(
    controller: Res<Controller>,
    mut cameras: Query<&mut Camera, With<crate::rendering::Main_Camera>>,
) {
    if !controller.render_on_demand {
        return;
    }
    // Keep all main-world systems ticking. Only drawing is unnecessary between
    // captures; extraction still uploads assets and processes renderer messages.
    let active = controller.last_id == 0
        || controller
            .pending
            .as_ref()
            .is_some_and(|pending| pending.remaining == 0);
    for mut camera in &mut cameras {
        if camera.is_active != active {
            camera.is_active = active;
        }
    }
}
fn valid_key(key: &str) -> bool {
    key.len() == 1 && key.as_bytes()[0].is_ascii_uppercase()
        || matches!(
            key,
            "SPACE"
                | "ENTER"
                | "ESCAPE"
                | "BACKSPACE"
                | "LEFT"
                | "RIGHT"
                | "UP"
                | "DOWN"
                | "SEMICOLON"
                | "TAB"
                | "F1"
                | "F3"
                | "G"
                | "DELETE"
                | "LEFT_CONTROL"
                | "RIGHT_CONTROL"
                | "MINUS"
                | "EQUAL"
        )
}
impl Controller {
    pub(crate) fn enabled(&self) -> bool {
        self.directory.is_some()
    }
}
pub(crate) fn waiting(controller: &Controller) -> bool {
    controller.directory.is_some() && !controller.stepping
}
fn native_key(key: &str) -> KeyCode {
    match key {
        "A" => KeyCode::KeyA,
        "B" => KeyCode::KeyB,
        "C" => KeyCode::KeyC,
        "D" => KeyCode::KeyD,
        "E" => KeyCode::KeyE,
        "F" => KeyCode::KeyF,
        "G" => KeyCode::KeyG,
        "H" => KeyCode::KeyH,
        "I" => KeyCode::KeyI,
        "J" => KeyCode::KeyJ,
        "K" => KeyCode::KeyK,
        "L" => KeyCode::KeyL,
        "M" => KeyCode::KeyM,
        "N" => KeyCode::KeyN,
        "O" => KeyCode::KeyO,
        "P" => KeyCode::KeyP,
        "Q" => KeyCode::KeyQ,
        "R" => KeyCode::KeyR,
        "S" => KeyCode::KeyS,
        "T" => KeyCode::KeyT,
        "U" => KeyCode::KeyU,
        "V" => KeyCode::KeyV,
        "W" => KeyCode::KeyW,
        "X" => KeyCode::KeyX,
        "Y" => KeyCode::KeyY,
        "Z" => KeyCode::KeyZ,
        "SPACE" => KeyCode::Space,
        "ENTER" => KeyCode::Enter,
        "ESCAPE" => KeyCode::Escape,
        "BACKSPACE" => KeyCode::Backspace,
        "LEFT" => KeyCode::ArrowLeft,
        "RIGHT" => KeyCode::ArrowRight,
        "UP" => KeyCode::ArrowUp,
        "DOWN" => KeyCode::ArrowDown,
        "SEMICOLON" => KeyCode::Semicolon,
        "TAB" => KeyCode::Tab,
        "F1" => KeyCode::F1,
        "F3" => KeyCode::F3,
        "DELETE" => KeyCode::Delete,
        "LEFT_CONTROL" => KeyCode::ControlLeft,
        "RIGHT_CONTROL" => KeyCode::ControlRight,
        "MINUS" => KeyCode::Minus,
        "EQUAL" => KeyCode::Equal,
        _ => unreachable!("validated legacy key"),
    }
}
fn valid_button(button: &str) -> bool {
    matches!(
        button,
        "LEFT_FACE_UP"
            | "LEFT_FACE_RIGHT"
            | "LEFT_FACE_DOWN"
            | "LEFT_FACE_LEFT"
            | "RIGHT_FACE_UP"
            | "RIGHT_FACE_RIGHT"
            | "RIGHT_FACE_DOWN"
            | "RIGHT_FACE_LEFT"
            | "LEFT_TRIGGER_1"
            | "LEFT_TRIGGER_2"
            | "RIGHT_TRIGGER_1"
            | "RIGHT_TRIGGER_2"
            | "MIDDLE_LEFT"
            | "MIDDLE"
            | "MIDDLE_RIGHT"
            | "LEFT_THUMB"
            | "RIGHT_THUMB"
    )
}
fn validate_inputs(command: &Command) -> Result<()> {
    ensure!(
        command.keys.iter().all(|key| valid_key(key)),
        "invalid input state"
    );
    let mut players = BTreeSet::new();
    for pad in &command.gamepads {
        ensure!(
            matches!(pad.player.as_str(), "Player_1" | "Player_2")
                && players.insert(&pad.player)
                && pad.axes.len() <= 6
                && pad
                    .axes
                    .iter()
                    .all(|a| a.is_finite() && (-1.0..=1.).contains(a))
                && pad.buttons.iter().all(|b| valid_button(b)),
            "invalid input state"
        );
    }
    Ok(())
}
fn capture_valid(capture: &str) -> bool {
    capture.is_empty()
        || capture.ends_with(".png")
            && !capture.contains(['/', '\\'])
            && capture != ".png"
            && Path::new(capture)
                .file_name()
                .is_some_and(|name| name == capture)
}
fn input_snapshot(command: &Command, controller: &Controller) -> [Player_Input; 2] {
    let held: BTreeSet<_> = command.keys.iter().map(String::as_str).collect();
    let key = |k: &str| held.contains(k);
    let edge = |k: &str| key(k) && !controller.previous_keys.contains(k);
    let mut result = [
        Player_Input {
            movement: Vec2::new(
                key("D") as u8 as f32 - key("A") as u8 as f32,
                key("S") as u8 as f32 - key("W") as u8 as f32,
            )
            .clamp_length_max(1.),
            jump: edge("H"),
            interact: edge("J"),
        },
        Player_Input {
            movement: Vec2::new(
                key("RIGHT") as u8 as f32 - key("LEFT") as u8 as f32,
                key("DOWN") as u8 as f32 - key("UP") as u8 as f32,
            )
            .clamp_length_max(1.),
            jump: edge("SEMICOLON"),
            interact: edge("L"),
        },
    ];
    for pad in &command.gamepads {
        let i = if pad.player == "Player_1" { 0 } else { 1 };
        let button = |name: &str| pad.buttons.iter().any(|b| b == name);
        let pressed = |name: &str| button(name) && !controller.previous_buttons[i].contains(name);
        let analog = Vec2::new(
            pad.axes.first().copied().unwrap_or(0.),
            pad.axes.get(1).copied().unwrap_or(0.),
        );
        if analog.length() > 0.15 {
            result[i].movement = analog.clamp_length_max(1.);
        }
        result[i].jump |= pressed("RIGHT_FACE_DOWN");
        result[i].interact |= pressed("RIGHT_FACE_LEFT");
    }
    result
}
fn execute(
    command: &Command,
    controller: &mut Controller,
    game: &mut Game_World<'_, impl std::ops::DerefMut<Target = Game_State>>,
    next: &mut NextState<Mode>,
) -> Result<Pending> {
    ensure!(
        capture_valid(&command.capture),
        "capture must be a plain PNG filename"
    );
    let mut pending = Pending {
        id: command.id,
        error: String::new(),
        capture: command.capture.clone(),
        remaining: 0,
        inputs: default(),
        debug_toggle: false,
        keys: Vec::new(),
        // Keep captures and room resets fully settled. Other commands only
        // need deferred state transitions and their main-world presentation.
        settle: if controller.render_on_demand
            && command.op != "reset"
            && command.capture.is_empty()
        {
            2
        } else {
            12
        },
        screenshot: false,
        stop: false,
    };
    match command.op.as_str() {
        "reset" => {
            let room = command.room.as_deref().unwrap_or("demo");
            ensure!(game.registry.rooms.contains_key(room), "unknown room");
            game.reset(
                room,
                command.players.unwrap_or(1),
                command.seed.unwrap_or(42),
            )?;
            controller.previous_keys.clear();
            controller.previous_buttons = default();
            next.set(Mode::Gameplay);
        }
        "step" => {
            let frames = command.frames.unwrap_or(0);
            ensure!(
                (1..=600).contains(&frames),
                "frames must be between 1 and 600"
            );
            validate_inputs(command)?;
            pending.inputs = input_snapshot(command, controller);
            pending.debug_toggle = command.gamepads.iter().any(|pad| {
                pad.player == "Player_1"
                    && pad.buttons.iter().any(|b| b == "RIGHT_THUMB")
                    && !controller.previous_buttons[0].contains("RIGHT_THUMB")
            });
            pending.remaining = frames;
            pending.keys = command.keys.iter().map(|key| native_key(key)).collect();
            for pad in &command.gamepads {
                for button in &pad.buttons {
                    if let Some(key) = match button.as_str() {
                        "MIDDLE_RIGHT" => Some(KeyCode::Escape),
                        "MIDDLE_LEFT" => Some(KeyCode::F1),
                        "LEFT_FACE_UP" => Some(KeyCode::ArrowUp),
                        "LEFT_FACE_DOWN" => Some(KeyCode::ArrowDown),
                        "LEFT_FACE_LEFT" => Some(KeyCode::ArrowLeft),
                        "LEFT_FACE_RIGHT" => Some(KeyCode::ArrowRight),
                        "RIGHT_FACE_DOWN" => Some(KeyCode::Enter),
                        _ => None,
                    } {
                        pending.keys.push(key);
                    }
                }
            }
            controller.previous_keys = command.keys.iter().cloned().collect();
            controller.previous_buttons = default();
            for pad in &command.gamepads {
                let i = if pad.player == "Player_1" { 0 } else { 1 };
                controller.previous_buttons[i] = pad.buttons.iter().cloned().collect();
            }
        }
        "observe" => {}
        "stop" => pending.stop = true,
        _ => anyhow::bail!("unknown operation"),
    }
    Ok(pending)
}
fn poll(
    mut controller: ResMut<Controller>,
    mut game: Game_Access,
    mut next: ResMut<NextState<Mode>>,
    mode: Res<State<Mode>>,
    mut keys: ResMut<ButtonInput<KeyCode>>,
    mut debug: ResMut<crate::debug::Debug_State>,
) {
    let Some(directory) = controller.directory.clone() else {
        return;
    };
    controller.stepping = controller.pending.as_ref().is_some_and(|p| p.remaining > 0);
    controller.debug_toggle = false;
    // Publish the controller edge separately from keyboard F3.
    let toggle = controller
        .pending
        .as_ref()
        .is_some_and(|p| p.remaining > 0 && p.debug_toggle);
    controller.debug_toggle = toggle;
    if let Some(pending) = &mut controller.pending {
        if pending.remaining > 0 {
            pending.debug_toggle = false;
            let released: Vec<_> = keys
                .get_pressed()
                .filter(|key| !pending.keys.contains(key))
                .copied()
                .collect();
            for key in released {
                keys.release(key);
            }
            for key in &pending.keys {
                keys.press(*key);
            }
            let result = if *mode.get() == Mode::Gameplay {
                game.step(pending.inputs, STEP)
            } else {
                game.frame += 1;
                Ok(())
            };
            if let Err(error) = result {
                pending.error = error.to_string();
                pending.remaining = 0;
            } else {
                pending.remaining -= 1;
            }
            for input in &mut pending.inputs {
                input.jump = false;
                input.interact = false;
            }
        }
        return;
    }
    if controller.last_id == 0 && controller.ready_frames < 30 {
        controller.ready_frames += 1;
        return;
    }
    let Ok(bytes) = fs::read(directory.join("request.json")) else {
        return;
    };
    let command: Command = match serde_json::from_slice(&bytes) {
        Ok(value) => value,
        Err(error) => {
            error!("Malformed control request: {error}");
            return;
        }
    };
    if command.id <= controller.last_id {
        return;
    }
    let pending = match game
        .with_simulation(|simulation| execute(&command, &mut controller, simulation, &mut next))
    {
        Ok(p) => p,
        Err(error) => Pending {
            id: command.id,
            error: error.to_string(),
            capture: String::new(),
            remaining: 0,
            inputs: default(),
            debug_toggle: false,
            keys: Vec::new(),
            settle: 0,
            screenshot: false,
            stop: false,
        },
    };
    if command.op == "reset" && pending.error.is_empty() {
        keys.reset_all();
        debug.enabled = false;
    }
    controller.last_id = command.id;
    controller.pending = Some(pending);
}
fn audio_snapshot(
    audio: &Query<(
        &AudioPlayer,
        &crate::rendering::Audio_Layer,
        Option<&AudioSink>,
    )>,
    server: &AssetServer,
) -> Value {
    let mut layers = serde_json::Map::new();
    for (player, layer, sink) in audio.iter() {
        layers.insert(format!("{layer:?}"), json!({"path":server.get_path(player.0.id()).map(|p|p.path().to_string_lossy().into_owned()), "playing":sink.is_some_and(|s| !s.empty())}));
    }
    Value::Object(layers)
}
#[derive(bevy::ecs::system::SystemParam)]
struct Presentation_Observation<'w, 's> {
    scale: Res<'w, UiScale>,
    title: Res<'w, crate::rendering::Title_Scene>,
    area: Query<'w, 's, (&'static Text, &'static TextColor), With<crate::ui::Area_Title>>,
    cameras: Query<'w, 's, Has<bevy::light::VolumetricFog>, With<crate::rendering::Main_Camera>>,
    volumetric_lights: Query<'w, 's, (), With<bevy::light::VolumetricLight>>,
}
impl Presentation_Observation<'_, '_> {
    fn snapshot(&self) -> Value {
        let area = self.area.iter().next();
        json!({
            "ui_scale": self.scale.0,
            "title_elapsed": self.title.elapsed,
            "title_grass_vertices": self.title.grass_vertices,
            "volumetric_lighting": self.cameras.iter().any(|enabled| enabled) && !self.volumetric_lights.is_empty(),
            "area_title": area.map(|(text, color)| json!({"text": text.0, "alpha": color.0.alpha()})),
        })
    }
}
fn observation(
    game: &Game_View,
    mode: &Mode,
    editor: &crate::editor::Editor_State,
    fade_alpha: f32,
    grass_vertices: usize,
    debug: &crate::debug::Debug_State,
    audio: Value,
    presentation: Value,
) -> Value {
    let mut state = game.observation();
    state["scene"] = json!(format!("{mode:?}"));
    state["audio"] = audio;
    state["debug"] = json!({"enabled":debug.enabled,"colliders":debug.collider_count});
    state["render"] = json!({"fade_alpha":fade_alpha,"grass_vertices":grass_vertices});
    state["presentation"] = presentation;
    if *mode == Mode::Editor {
        state["editor"] = json!({"dirty":editor.dirty,"cursor":[editor.cursor.x,editor.cursor.y],"base":game.room.layers.base});
    }
    state
}
fn write_response(
    directory: &Path,
    id: u64,
    error: &str,
    state: Value,
    capture: &str,
) -> Result<()> {
    let mut file = tempfile::NamedTempFile::new_in(directory)?;
    file.write_all(
        serde_json::to_string(&json!({"id":id,"error":error,"state":state,"capture":capture}))?
            .as_bytes(),
    )?;
    file.persist(directory.join("response.json"))?;
    Ok(())
}
fn respond(
    mut commands: Commands,
    mut controller: ResMut<Controller>,
    game: Game_View,
    mut exit: MessageWriter<AppExit>,
    mode: Res<State<Mode>>,
    editor: Res<crate::editor::Editor_State>,
    server: Res<AssetServer>,
    models: Query<&crate::rendering::Model>,
    target: Option<Res<crate::rendering::Offscreen_Target>>,
    fade: Query<&BackgroundColor, With<crate::ui::Transition_Fade>>,
    stats: Res<crate::rendering::Scene_Stats>,
    debug: Res<crate::debug::Debug_State>,
    presentation: Presentation_Observation,
    audio: Query<(
        &AudioPlayer,
        &crate::rendering::Audio_Layer,
        Option<&AudioSink>,
    )>,
) {
    let Some(directory) = controller.directory.clone() else {
        return;
    };
    if controller.last_id == 0
        && controller.ready_frames >= 30
        && !directory.join("response.json").exists()
    {
        let _ = write_response(&directory, 0, "", json!({"scene":"Title","frame":0}), "");
    }
    let Some(pending) = &mut controller.pending else {
        return;
    };
    if pending.remaining > 0 || pending.screenshot {
        return;
    }
    if !pending.capture.is_empty()
        && models
            .iter()
            .any(|m| !server.is_loaded_with_dependencies(m.gltf.id()))
    {
        return;
    }
    if pending.settle > 0 {
        pending.settle -= 1;
        return;
    }
    if pending.capture.is_empty() {
        let pending = controller.pending.take().unwrap();
        if let Err(error) = write_response(
            &directory,
            pending.id,
            &pending.error,
            observation(
                &game,
                mode.get(),
                &editor,
                fade.single().map_or(0., |c| c.0.alpha()),
                stats.grass_vertices,
                &debug,
                audio_snapshot(&audio, &server),
                presentation.snapshot(),
            ),
            "",
        ) {
            error!("{error}");
        }
        if pending.stop {
            exit.write(AppExit::Success);
        }
    } else {
        pending.screenshot = true;
        let screenshot = target.map_or_else(Screenshot::primary_window, |target| {
            Screenshot::image(target.0.clone())
        });
        commands.spawn(screenshot).observe(
            move |event: On<ScreenshotCaptured>,
                  mut controller: ResMut<Controller>,
                  game: Game_View,
                  mode: Res<State<Mode>>,
                  editor: Res<crate::editor::Editor_State>,
                  fade: Query<&BackgroundColor, With<crate::ui::Transition_Fade>>,
                  stats: Res<crate::rendering::Scene_Stats>,
                  debug: Res<crate::debug::Debug_State>,
                  presentation: Presentation_Observation,
                  server: Res<AssetServer>,
                  audio: Query<(
                &AudioPlayer,
                &crate::rendering::Audio_Layer,
                Option<&AudioSink>,
            )>,
                  mut exit: MessageWriter<AppExit>| {
                let Some(pending) = controller.pending.take() else {
                    return;
                };
                let path = directory.join(&pending.capture);
                let result = event
                    .image
                    .clone()
                    .try_into_dynamic()
                    .map_err(|e| anyhow::anyhow!("{e:?}"))
                    .and_then(|image| {
                        image.save(&path)?;
                        Ok(())
                    });
                let error = result.err().map(|e| e.to_string()).unwrap_or(pending.error);
                if let Err(error) = write_response(
                    &directory,
                    pending.id,
                    &error,
                    observation(
                        &game,
                        mode.get(),
                        &editor,
                        fade.single().map_or(0., |c| c.0.alpha()),
                        stats.grass_vertices,
                        &debug,
                        audio_snapshot(&audio, &server),
                        presentation.snapshot(),
                    ),
                    path.to_str().unwrap_or(""),
                ) {
                    error!("{error}");
                }
                if pending.stop {
                    exit.write(AppExit::Success);
                }
            },
        );
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn invalid_input_and_paths_rejected() {
        let command = Command {
            gamepads: vec![Gamepad_Input {
                player: "Player_1".into(),
                axes: vec![0., 2.],
                buttons: vec![],
            }],
            ..default()
        };
        assert!(validate_inputs(&command).is_err());
        for path in ["../escape.png", "/tmp/x.png", "x.jpg", "nested/x.png"] {
            assert!(!capture_valid(path));
        }
        assert!(capture_valid("state.png"));
    }
    #[test]
    fn held_actions_only_fire_on_rising_edge() {
        let command = Command {
            keys: vec!["H".into()],
            ..default()
        };
        let mut controller = Controller::default();
        assert!(input_snapshot(&command, &controller)[0].jump);
        controller.previous_keys.insert("H".into());
        assert!(!input_snapshot(&command, &controller)[0].jump);
        assert!(input_snapshot(&Command::default(), &controller)[0].movement == Vec2::ZERO);
    }
    #[test]
    fn rejected_command_does_not_change_state_or_inputs() {
        let mut game =
            Game_World::new(crate::content::Room_Registry::load(Path::new("res")).unwrap())
                .unwrap();
        game.reset("demo", 1, 42).unwrap();
        let before = game.observation();
        let mut controller = Controller::default();
        controller.previous_keys.insert("S".into());
        let mut next = NextState::default();
        assert!(
            execute(
                &Command {
                    op: "step".into(),
                    frames: Some(0),
                    ..default()
                },
                &mut controller,
                &mut game,
                &mut next
            )
            .is_err()
        );
        assert_eq!(game.observation(), before);
        assert!(controller.previous_keys.contains("S"));
    }
}
