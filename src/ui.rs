use crate::{
    app::{Mode, Preferences},
    editor::Editor_State,
    input::Controls,
    rendering::Title_Background,
    simulation::{DIALOG, Game_World},
};
use bevy::{
    picking::hover::Hovered,
    prelude::*,
    ui_widgets::{Activate, Button},
    window::{MonitorSelection, WindowMode},
};

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
enum Menu {
    #[default]
    Main,
    Options,
    Audio,
    Visual,
    Controls,
}
#[derive(Resource, Default)]
pub(crate) struct Menu_State {
    menu: Menu,
    selection: usize,
    last: String,
    rebuild: bool,
    repeat: f32,
    rebinding: Option<usize>,
}
#[derive(Component)]
struct Ui_Root;
#[derive(Component)]
struct Menu_Option(usize);
pub struct Ui_Plugin;
impl Plugin for Ui_Plugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Menu_State>()
            .add_systems(Startup, setup_transition_fade)
            .add_systems(
                Update,
                (menu_input, button_input, draw_ui, update_transition_fade).chain(),
            );
    }
}
#[derive(Component)]
pub(crate) struct Transition_Fade;
fn setup_transition_fade(mut commands: Commands) {
    commands.spawn((
        Node {
            position_type: PositionType::Absolute,
            width: percent(100),
            height: percent(100),
            ..default()
        },
        GlobalZIndex(100),
        BackgroundColor(Color::NONE),
        Pickable::IGNORE,
        Transition_Fade,
    ));
}
fn update_transition_fade(
    game: Res<Game_World>,
    mut fades: Query<&mut BackgroundColor, With<Transition_Fade>>,
) {
    let opacity = game
        .transition
        .as_ref()
        .map_or(0., |transition| {
            if transition.elapsed < 0.3 {
                transition.elapsed / 0.3
            } else {
                1. - (transition.elapsed - 0.3) / 0.3
            }
        })
        .clamp(0., 1.);
    for mut color in &mut fades {
        color.0 = Color::srgba(0., 0., 0., opacity);
    }
}
fn items(
    mode: &Mode,
    menu: Menu,
    preferences: &Preferences,
    bindings: &crate::input::Key_Bindings,
) -> Vec<String> {
    match menu {
        Menu::Main => {
            if *mode == Mode::Title {
                ["1 player", "2 players", "Options", "Exit game"]
                    .map(str::to_string)
                    .into()
            } else {
                ["Resume", "Options", "Return to title"]
                    .map(str::to_string)
                    .into()
            }
        }
        Menu::Options => ["Audio", "Visual", "Controls", "Back"]
            .map(str::to_string)
            .into(),
        Menu::Audio => vec![
            format!("Master   {:.0}%", preferences.master * 100.),
            format!("Music    {:.0}%", preferences.music * 100.),
            format!("Effects  {:.0}%", preferences.effects * 100.),
            "Back".into(),
        ],
        Menu::Visual => vec![
            format!(
                "Fullscreen    {}",
                if preferences.fullscreen { "on" } else { "off" }
            ),
            "Back".into(),
        ],
        Menu::Controls => {
            let mut items: Vec<_> = [
                "Move up",
                "Move down",
                "Move left",
                "Move right",
                "Jump",
                "Interact",
                "Pause",
                "Reload",
            ]
            .iter()
            .enumerate()
            .map(|(i, label)| format!("{label}   {:?}", bindings.player_one[i]))
            .collect();
            items.push("Back".into());
            items
        }
    }
}
fn activate(
    index: usize,
    menu: &mut Menu_State,
    mode: &Mode,
    next: &mut NextState<Mode>,
    game: &mut Game_World,
    preferences: &mut Preferences,
    exit: &mut MessageWriter<AppExit>,
) {
    match menu.menu {
        Menu::Main => {
            if *mode == Mode::Title {
                match index {
                    0 | 1 => {
                        let id = crate::simulation::INITIAL_ROOM;
                        if let Err(error) = game.reset(id, index + 1, 42) {
                            error!("{error}");
                            return;
                        }
                        next.set(Mode::Gameplay);
                    }
                    2 => menu.menu = Menu::Options,
                    3 => {
                        exit.write(AppExit::Success);
                    }
                    _ => {}
                }
            } else {
                match index {
                    0 => next.set(Mode::Gameplay),
                    1 => menu.menu = Menu::Options,
                    2 => next.set(Mode::Title),
                    _ => {}
                }
            }
        }
        Menu::Options => {
            menu.menu = match index {
                0 => Menu::Audio,
                1 => Menu::Visual,
                2 => Menu::Controls,
                _ => Menu::Main,
            }
        }
        Menu::Audio => {
            if index == 3 {
                menu.menu = Menu::Options;
            }
        }
        Menu::Visual => {
            if index == 0 {
                preferences.fullscreen = !preferences.fullscreen;
            } else {
                menu.menu = Menu::Options;
            }
        }
        Menu::Controls => {
            if index == 8 {
                menu.menu = Menu::Options;
            } else {
                menu.rebinding = Some(index);
            }
        }
    }
    menu.selection = 0;
    menu.rebuild = true;
}
pub(crate) fn menu_input(
    #[cfg(debug_assertions)] controller: Res<crate::automation::Controller>,
    keys: Res<ButtonInput<KeyCode>>,
    pads: Query<&Gamepad>,
    windows: Query<&Window>,
    mode: Res<State<Mode>>,
    mut next: ResMut<NextState<Mode>>,
    mut menu: ResMut<Menu_State>,
    mut game: ResMut<Game_World>,
    mut preferences: ResMut<Preferences>,
    mut exit: MessageWriter<AppExit>,
    time: Res<Time>,
    mut controls: ResMut<Controls>,
    mut bindings: ResMut<crate::input::Key_Bindings>,
) {
    #[cfg(debug_assertions)]
    if crate::automation::waiting(&controller) {
        return;
    }
    if windows.iter().any(|w| !w.focused) {
        return;
    }
    if let Some(index) = menu.rebinding {
        if let Some(key) = keys.get_just_pressed().find(|key| **key != KeyCode::Enter) {
            if *key != KeyCode::Escape {
                bindings.player_one[index] = *key;
            }
            menu.rebinding = None;
            menu.rebuild = true;
        }
        return;
    }
    if keys.just_pressed(KeyCode::Backspace) {
        exit.write(AppExit::Success);
        return;
    }
    if keys.just_pressed(KeyCode::F1) || pads.iter().any(|p| p.just_pressed(GamepadButton::Select))
    {
        #[cfg(debug_assertions)]
        if *mode.get() == Mode::Gameplay {
            next.set(Mode::Editor);
        } else if *mode.get() == Mode::Editor {
            next.set(Mode::Gameplay);
        }
    }
    if *mode.get() == Mode::Gameplay {
        if keys.just_pressed(bindings.player_one[6])
            || keys.just_pressed(KeyCode::Escape)
            || pads.iter().any(|p| p.just_pressed(GamepadButton::Start))
        {
            next.set(Mode::Paused);
            menu.menu = Menu::Main;
            menu.selection = 0;
            for p in &mut controls.players {
                p.interact = false;
                p.jump = false;
            }
        }
        #[cfg(debug_assertions)]
        {
            if keys.just_pressed(bindings.player_one[7]) {
                let id = game.room.id.clone();
                let count = game.player_count;
                let seed = game.seed;
                let _ = game.reset(&id, count, seed);
            }
            if keys.just_pressed(KeyCode::KeyN)
                || pads
                    .iter()
                    .any(|p| p.just_pressed(GamepadButton::DPadRight))
            {
                game.night = !game.night;
            }
        }
        return;
    }
    if *mode.get() == Mode::Editor {
        return;
    }
    let dt = time.delta_secs();
    #[cfg(debug_assertions)]
    let dt = if controller.stepping {
        crate::simulation::STEP
    } else {
        dt
    };
    menu.repeat -= dt;
    let stick = pads
        .iter()
        .next()
        .map(|p| p.left_stick())
        .unwrap_or_default();
    let up = keys.just_pressed(KeyCode::ArrowUp)
        || keys.just_pressed(KeyCode::KeyW)
        || pads.iter().any(|p| p.just_pressed(GamepadButton::DPadUp))
        || stick.y > 0.6 && menu.repeat <= 0.;
    let down = keys.just_pressed(KeyCode::ArrowDown)
        || keys.just_pressed(KeyCode::KeyS)
        || pads.iter().any(|p| p.just_pressed(GamepadButton::DPadDown))
        || stick.y < -0.6 && menu.repeat <= 0.;
    let count = items(mode.get(), menu.menu, &preferences, &bindings).len();
    if up {
        menu.selection = (menu.selection + count - 1) % count;
        menu.repeat = 0.2;
    }
    if down {
        menu.selection = (menu.selection + 1) % count;
        menu.repeat = 0.2;
    }
    if keys.just_pressed(KeyCode::Escape)
        || pads.iter().any(|p| p.just_pressed(GamepadButton::East))
    {
        if menu.menu == Menu::Main {
            if *mode.get() == Mode::Paused {
                next.set(Mode::Gameplay);
            } else {
                exit.write(AppExit::Success);
            }
        } else {
            menu.menu = if menu.menu == Menu::Options {
                Menu::Main
            } else {
                Menu::Options
            };
            menu.selection = 0;
        }
    }
    if menu.menu == Menu::Audio {
        let delta = if keys.just_pressed(KeyCode::ArrowLeft) {
            -0.05
        } else if keys.just_pressed(KeyCode::ArrowRight) {
            0.05
        } else {
            0.
        };
        let selected = menu.selection;
        let value = match selected {
            0 => Some(&mut preferences.master),
            1 => Some(&mut preferences.music),
            2 => Some(&mut preferences.effects),
            _ => None,
        };
        if let Some(value) = value {
            *value = (*value + delta).clamp(0., 1.);
        }
    }
    if keys.just_pressed(KeyCode::Enter)
        || pads.iter().any(|p| p.just_pressed(GamepadButton::South))
    {
        let index = menu.selection;
        activate(
            index,
            &mut menu,
            mode.get(),
            &mut next,
            &mut game,
            &mut preferences,
            &mut exit,
        );
    }
}
fn button_input(
    buttons: Query<(&Hovered, &Menu_Option), Changed<Hovered>>,
    mut menu: ResMut<Menu_State>,
    preferences: Res<Preferences>,
    mut windows: Query<&mut Window>,
) {
    for (hovered, option) in &buttons {
        if hovered.0 {
            menu.selection = option.0;
        }
    }
    if preferences.is_changed() {
        for mut window in &mut windows {
            window.mode = if preferences.fullscreen {
                WindowMode::BorderlessFullscreen(MonitorSelection::Current)
            } else {
                WindowMode::Windowed
            };
        }
    }
}
fn button_activate(
    event: On<Activate>,
    options: Query<&Menu_Option>,
    mut menu: ResMut<Menu_State>,
    mode: Res<State<Mode>>,
    mut next: ResMut<NextState<Mode>>,
    mut game: ResMut<Game_World>,
    mut preferences: ResMut<Preferences>,
    mut exit: MessageWriter<AppExit>,
) {
    if let Ok(option) = options.get(event.entity) {
        activate(
            option.0,
            &mut menu,
            mode.get(),
            &mut next,
            &mut game,
            &mut preferences,
            &mut exit,
        );
    }
}
fn draw_ui(
    bindings: Res<crate::input::Key_Bindings>,
    mut commands: Commands,
    root: Query<Entity, With<Ui_Root>>,
    mode: Res<State<Mode>>,
    game: Res<Game_World>,
    preferences: Res<Preferences>,
    editor: Res<Editor_State>,
    background: Res<Title_Background>,
    server: Res<AssetServer>,
    mut menu: ResMut<Menu_State>,
) {
    let status = if menu.rebinding.is_some() {
        "Press a new key, or Escape to cancel".to_string()
    } else if *mode.get() == Mode::Editor {
        editor.status(&game)
    } else if let Some(page) = game.dialog {
        format!(
            "Village NPC\n\n{}\n\nJ / west button to continue",
            DIALOG[page]
                .chars()
                .take(game.dialog_characters as usize)
                .collect::<String>()
        )
    } else {
        game.room.name.clone()
    };
    let key = format!(
        "{:?}|{:?}|{}|{}|{:?}|{}",
        mode.get(),
        menu.menu,
        menu.selection,
        format!("{status}|{:?}", bindings.player_one),
        [preferences.master, preferences.music, preferences.effects],
        preferences.fullscreen
    );
    if key == menu.last && !menu.rebuild {
        return;
    }
    menu.last = key;
    menu.rebuild = false;
    for entity in &root {
        commands.entity(entity).despawn();
    }
    let font = server.load("font/aoboshi-one/AoboshiOne-Regular.ttf");
    let text_font = |size: f32| TextFont::from_font_size(size).with_font(font.clone());
    let color = Color::srgb(0.99, 0.96, 0.83);
    let node = commands
        .spawn((
            Node {
                width: percent(100),
                height: percent(100),
                position_type: PositionType::Absolute,
                ..default()
            },
            Ui_Root,
        ))
        .id();
    commands.entity(node).with_children(|parent| {
        if *mode.get() == Mode::Title {
            parent.spawn((
                ImageNode::new(background.0.clone()),
                Node {
                    width: percent(100),
                    height: percent(100),
                    position_type: PositionType::Absolute,
                    ..default()
                },
            ));
        }
        if matches!(mode.get(), Mode::Title | Mode::Paused) {
            let list = items(mode.get(), menu.menu, &preferences, &bindings);
            parent
                .spawn((
                    Node {
                        position_type: PositionType::Absolute,
                        left: percent(5),
                        top: percent(10),
                        padding: UiRect::all(px(24)),
                        flex_direction: FlexDirection::Column,
                        row_gap: px(12),
                        ..default()
                    },
                    BackgroundColor(Color::srgba(0.08, 0.15, 0.13, 0.7)),
                ))
                .with_children(|panel| {
                    panel.spawn((
                        Text::new(if *mode.get() == Mode::Title {
                            "Hollie"
                        } else {
                            "Paused"
                        }),
                        text_font(64.),
                        TextColor(color),
                    ));
                    for (index, item) in list.iter().enumerate() {
                        panel
                            .spawn((
                                Button,
                                Hovered::default(),
                                Menu_Option(index),
                                Node {
                                    padding: UiRect::axes(px(16), px(8)),
                                    ..default()
                                },
                                BackgroundColor(if index == menu.selection {
                                    Color::srgba(0.53, 0.58, 0.35, 0.65)
                                } else {
                                    Color::NONE
                                }),
                            ))
                            .observe(button_activate)
                            .with_children(|button| {
                                button.spawn((Text::new(item), text_font(22.), TextColor(color)));
                            });
                    }
                });
        } else {
            parent.spawn((
                Text::new(status),
                text_font(if game.dialog.is_some() { 22. } else { 18. }),
                TextColor(color),
                Node {
                    position_type: PositionType::Absolute,
                    left: px(24),
                    top: px(20),
                    max_width: percent(80),
                    padding: UiRect::all(px(12)),
                    ..default()
                },
                BackgroundColor(Color::srgba(0.07, 0.14, 0.13, 0.8)),
            ));
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn fade_updates_and_clears_without_a_menu_rebuild() {
        let game = Game_World::new(
            crate::content::Room_Registry::load(std::path::Path::new("res")).unwrap(),
        )
        .unwrap();
        let mut app = App::new();
        app.add_plugins(MinimalPlugins)
            .insert_resource(game)
            .add_systems(Update, update_transition_fade);
        let fade = app
            .world_mut()
            .spawn((BackgroundColor(Color::NONE), Transition_Fade))
            .id();
        for (elapsed, expected) in [(0.15, 0.5), (0.3, 1.), (0.45, 0.5)] {
            app.world_mut().resource_mut::<Game_World>().transition =
                Some(crate::simulation::Transition {
                    room: "demo".into(),
                    door: String::new(),
                    loaded: true,
                    elapsed,
                });
            app.update();
            assert!(
                (app.world().get::<BackgroundColor>(fade).unwrap().0.alpha() - expected).abs()
                    < 0.001
            );
        }
        app.world_mut().resource_mut::<Game_World>().transition = None;
        app.update();
        assert_eq!(
            app.world().get::<BackgroundColor>(fade).unwrap().0.alpha(),
            0.
        );
    }
}
