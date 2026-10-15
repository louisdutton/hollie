use crate::{
    app::{Mode, Preferences},
    editor::Editor_State,
    input::Controls,
    simulation::{DIALOG, Game_Access, Game_State},
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
            .add_systems(OnEnter(Mode::Title), |mut menu: ResMut<Menu_State>| {
                *menu = Menu_State::default();
            })
            .add_systems(Startup, (setup_transition_fade, setup_area_title))
            .add_systems(
                Update,
                (menu_input, button_input)
                    .chain()
                    .in_set(crate::app::Game_Systems::Actions),
            )
            .add_systems(
                Update,
                (
                    apply_window_preferences,
                    scale_ui,
                    draw_ui,
                    update_transition_fade,
                    update_area_title,
                )
                    .in_set(crate::app::Game_Systems::Presentation),
            );
    }
}

fn scale_ui(
    cameras: Query<&Camera, With<crate::rendering::Main_Camera>>,
    mut scale: ResMut<UiScale>,
) {
    if let Some(size) = cameras
        .iter()
        .next()
        .and_then(Camera::logical_viewport_size)
    {
        scale.0 = (size.x / 1280.).min(size.y / 720.).max(0.1);
    }
}

#[derive(Component)]
pub(crate) struct Area_Title;

fn setup_area_title(mut commands: Commands, server: Res<AssetServer>) {
    commands
        .spawn((
            Node {
                position_type: PositionType::Absolute,
                top: percent(10.67),
                width: percent(100),
                justify_content: JustifyContent::Center,
                ..default()
            },
            GlobalZIndex(10),
            Pickable::IGNORE,
        ))
        .with_children(|parent| {
            parent.spawn((
                Text::default(),
                TextFont::from_font_size(67.2)
                    .with_font(server.load("font/aoboshi-one/AoboshiOne-Regular.ttf")),
                TextColor(Color::NONE),
                TextLayout::justify(Justify::Center),
                Node {
                    max_width: percent(90),
                    ..default()
                },
                Pickable::IGNORE,
                Area_Title,
            ));
        });
}

fn update_area_title(
    game: Res<Game_State>,
    mode: Res<State<Mode>>,
    mut entry: Local<Option<(u64, f32)>>,
    mut titles: Query<(&mut Text, &mut TextColor), With<Area_Title>>,
) {
    if *mode.get() == Mode::Title {
        *entry = None;
    } else if entry.is_none_or(|(generation, _)| generation != game.generation) {
        *entry = Some((game.generation, game.elapsed));
    }
    let opacity = if *mode.get() == Mode::Gameplay {
        entry.map_or(0., |(_, started)| {
            area_title_opacity(game.elapsed - started)
        })
    } else {
        0.
    };
    for (mut text, mut color) in &mut titles {
        if text.0 != game.room.name {
            text.0.clone_from(&game.room.name);
        }
        color.0 = Color::srgba(244. / 255., 242. / 255., 234. / 255., opacity);
    }
}

fn area_title_opacity(age: f32) -> f32 {
    if age < 0.5 {
        1. - (1. - age.max(0.) / 0.5).powi(2)
    } else {
        1. - (age - 2.5).clamp(0., 1.).powi(2)
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
    game: Res<Game_State>,
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
    game: &mut Game_Access,
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
#[derive(bevy::ecs::system::SystemParam)]
struct Menu_Actions<'w, 's> {
    next: ResMut<'w, NextState<Mode>>,
    game: Game_Access<'w, 's>,
    preferences: ResMut<'w, Preferences>,
    exit: MessageWriter<'w, AppExit>,
}
#[derive(bevy::ecs::system::SystemParam)]
struct Menu_Controls<'w, 's> {
    keys: Res<'w, ButtonInput<KeyCode>>,
    pads: Query<'w, 's, &'static Gamepad>,
    windows: Query<'w, 's, &'static Window>,
    controls: ResMut<'w, Controls>,
    bindings: ResMut<'w, crate::input::Key_Bindings>,
}
fn menu_input(
    #[cfg(debug_assertions)] controller: Res<crate::automation::Controller>,
    mode: Res<State<Mode>>,
    mut menu: ResMut<Menu_State>,
    time: Res<Time>,
    actions: Menu_Actions,
    input: Menu_Controls,
) {
    let Menu_Actions {
        mut next,
        mut game,
        mut preferences,
        mut exit,
    } = actions;
    let Menu_Controls {
        keys,
        pads,
        windows,
        mut controls,
        mut bindings,
    } = input;

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
) {
    for (hovered, option) in &buttons {
        if hovered.0 {
            menu.selection = option.0;
        }
    }
}
#[derive(Default)]
struct Window_Layout {
    windowed_size: Vec2,
    fullscreen: bool,
}
fn apply_window_preferences(
    preferences: Res<Preferences>,
    mut windows: Query<(
        Entity,
        &mut Window,
        Option<&bevy::window::OnMonitor>,
        Option<&bevy::window::RawHandleWrapper>,
    )>,
    monitors: Query<(
        Entity,
        &bevy::window::Monitor,
        Has<bevy::window::PrimaryMonitor>,
    )>,
    mut layouts: Local<std::collections::HashMap<Entity, Window_Layout>>,
) {
    for (entity, mut window, on_monitor, native) in &mut windows {
        let layout = layouts.entry(entity).or_insert_with(|| Window_Layout {
            windowed_size: window.size(),
            fullscreen: false,
        });
        if preferences.fullscreen {
            let monitor = on_monitor
                .and_then(|m| monitors.get(m.0).ok())
                .or_else(|| monitors.iter().find(|(_, _, primary)| *primary))
                .or_else(|| monitors.iter().next());
            let Some((monitor_entity, monitor, _)) = monitor else {
                continue;
            };
            let size = monitor.physical_size();
            if size.x == 0 || size.y == 0 {
                continue;
            }
            if !layout.fullscreen {
                layout.windowed_size = window.size();
            }
            // Gamescope's Wayland fullscreen request does not resize the client surface.
            // Set native pixels before window creation, then wait for the real handle.
            if native.is_none() {
                window
                    .resolution
                    .set_scale_factor(monitor.scale_factor as f32);
            }
            if window.physical_size() != size {
                window.resolution.set_physical_resolution(size.x, size.y);
            }
            if native.is_some() {
                let mode =
                    WindowMode::BorderlessFullscreen(MonitorSelection::Entity(monitor_entity));
                if window.mode != mode {
                    window.mode = mode;
                }
            }
            layout.fullscreen = true;
        } else if layout.fullscreen {
            window.mode = WindowMode::Windowed;
            window
                .resolution
                .set(layout.windowed_size.x, layout.windowed_size.y);
            layout.fullscreen = false;
        }
    }
}

fn button_activate(
    event: On<Activate>,
    options: Query<&Menu_Option>,
    mut menu: ResMut<Menu_State>,
    mode: Res<State<Mode>>,
    actions: Menu_Actions,
) {
    let Menu_Actions {
        mut next,
        mut game,
        mut preferences,
        mut exit,
    } = actions;

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
#[derive(bevy::ecs::system::SystemParam)]
struct Ui_Context<'w> {
    bindings: Res<'w, crate::input::Key_Bindings>,
    mode: Res<'w, State<Mode>>,
    game: Res<'w, Game_State>,
    preferences: Res<'w, Preferences>,
    editor: Res<'w, Editor_State>,
    server: Res<'w, AssetServer>,
}
fn draw_ui(
    mut commands: Commands,
    root: Query<Entity, With<Ui_Root>>,
    mut menu: ResMut<Menu_State>,
    context: Ui_Context,
) {
    let Ui_Context {
        bindings,
        mode,
        game,
        preferences,
        editor,
        server,
    } = context;

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
        String::new()
    };
    let key = format!(
        "{:?}|{:?}|{}|{}|{:?}|{}",
        mode.get(),
        menu.menu,
        menu.selection,
        format_args!("{status}|{:?}", bindings.player_one),
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
        } else if !status.is_empty() {
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
    fn area_titles_fade_hold_and_disappear_on_each_room_generation() {
        let game = crate::simulation::Game_World::new(
            crate::content::Room_Registry::load(std::path::Path::new("res")).unwrap(),
        )
        .unwrap();
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, bevy::state::app::StatesPlugin))
            .init_state::<Mode>()
            .insert_resource(*game.state)
            .add_systems(Update, update_area_title);
        let title = app
            .world_mut()
            .spawn((Text::default(), TextColor(Color::NONE), Area_Title))
            .id();
        app.world_mut()
            .resource_mut::<NextState<Mode>>()
            .set(Mode::Gameplay);
        app.update();
        for (elapsed, expected) in [(0.25, 0.75), (0.5, 1.), (2.5, 1.), (3., 0.75), (3.5, 0.)] {
            app.world_mut().resource_mut::<Game_State>().elapsed = elapsed;
            app.update();
            assert!(
                (app.world().get::<TextColor>(title).unwrap().0.alpha() - expected).abs() < 0.001
            );
        }
        app.world_mut().resource_mut::<Game_State>().generation += 1;
        app.update();
        app.world_mut().resource_mut::<Game_State>().elapsed += 0.5;
        app.update();
        assert_eq!(app.world().get::<TextColor>(title).unwrap().0.alpha(), 1.);
        app.world_mut()
            .resource_mut::<NextState<Mode>>()
            .set(Mode::Paused);
        app.update();
        assert_eq!(app.world().get::<TextColor>(title).unwrap().0.alpha(), 0.);
        app.world_mut()
            .resource_mut::<NextState<Mode>>()
            .set(Mode::Gameplay);
        app.update();
        assert_eq!(app.world().get::<TextColor>(title).unwrap().0.alpha(), 1.);
    }
    #[test]
    fn fullscreen_waits_for_monitor_then_uses_physical_pixels_and_restores_windowed_size() {
        for scale in [1., 2.] {
            let mut app = App::new();
            app.add_plugins(MinimalPlugins)
                .init_resource::<Preferences>()
                .add_systems(Update, apply_window_preferences);
            let entity = app
                .world_mut()
                .spawn(Window {
                    resolution: (1280, 720).into(),
                    ..default()
                })
                .id();
            app.update();
            assert_eq!(
                app.world().get::<Window>(entity).unwrap().physical_size(),
                UVec2::new(1280, 720)
            );
            app.world_mut().spawn((
                bevy::window::Monitor {
                    name: Some("4K".into()),
                    physical_width: 3840,
                    physical_height: 2160,
                    physical_position: IVec2::ZERO,
                    refresh_rate_millihertz: Some(60_000),
                    scale_factor: scale,
                    video_modes: Vec::new(),
                },
                bevy::window::PrimaryMonitor,
            ));
            app.update();
            let window = app.world().get::<Window>(entity).unwrap();
            assert_eq!(window.physical_size(), UVec2::new(3840, 2160));
            assert_eq!(
                window.mode,
                WindowMode::Windowed,
                "fullscreen requested before a native window exists"
            );
            assert_eq!(window.width(), 3840. / scale as f32);
            app.world_mut().resource_mut::<Preferences>().fullscreen = false;
            app.update();
            assert_eq!(
                app.world().get::<Window>(entity).unwrap().size(),
                Vec2::new(1280., 720.)
            );
        }
    }
    #[test]
    fn fade_updates_and_clears_without_a_menu_rebuild() {
        let game = crate::simulation::Game_World::new(
            crate::content::Room_Registry::load(std::path::Path::new("res")).unwrap(),
        )
        .unwrap();
        let mut app = App::new();
        app.add_plugins(MinimalPlugins)
            .insert_resource(*game.state)
            .add_systems(Update, update_transition_fade);
        let fade = app
            .world_mut()
            .spawn((BackgroundColor(Color::NONE), Transition_Fade))
            .id();
        for (elapsed, expected) in [(0.15, 0.5), (0.3, 1.), (0.45, 0.5)] {
            app.world_mut().resource_mut::<Game_State>().transition =
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
        app.world_mut().resource_mut::<Game_State>().transition = None;
        app.update();
        assert_eq!(
            app.world().get::<BackgroundColor>(fade).unwrap().0.alpha(),
            0.
        );
    }
}
