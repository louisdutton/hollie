use crate::{
    content::Room_Registry,
    editor::Editor_Plugin,
    input::{Controls, Key_Bindings, collect_input},
    rendering::Rendering_Plugin,
    simulation::{Game_World, STEP},
    ui::Ui_Plugin,
};
use bevy::{
    asset::AssetPlugin,
    prelude::*,
    render::{
        RenderPlugin,
        settings::{RenderCreation, WgpuSettings},
    },
    window::WindowPlugin,
};
use std::path::Path;

#[derive(States, Default, Clone, Debug, PartialEq, Eq, Hash)]
pub enum Mode {
    #[default]
    Title,
    Gameplay,
    Paused,
    Editor,
}
#[derive(Resource)]
pub struct Preferences {
    pub master: f32,
    pub music: f32,
    pub effects: f32,
    pub fullscreen: bool,
}
impl Default for Preferences {
    fn default() -> Self {
        Self {
            master: 1.,
            music: 0.65,
            effects: 0.8,
            fullscreen: true,
        }
    }
}
pub struct Hollie_Plugin;
impl Plugin for Hollie_Plugin {
    fn build(&self, app: &mut App) {
        let root = std::env::var("RES_ROOT").unwrap_or_else(|_| "res".into());
        let registry = Room_Registry::load(Path::new(&root)).expect("room content must validate");
        app.insert_resource(Game_World::new(registry).expect("initial room"))
            .insert_resource(Time::<Fixed>::from_seconds(STEP as f64))
            .init_resource::<Controls>()
            .init_resource::<Key_Bindings>()
            .init_resource::<Preferences>()
            .init_state::<Mode>()
            .add_systems(PreUpdate, collect_input.after(bevy::input::InputSystems))
            .add_systems(FixedUpdate, simulate.run_if(in_state(Mode::Gameplay)))
            .add_plugins((Rendering_Plugin, Ui_Plugin, Editor_Plugin));
        #[cfg(debug_assertions)]
        app.add_plugins((
            crate::debug::Debug_Plugin,
            crate::automation::Automation_Plugin,
        ))
        .add_systems(Startup, report_renderer);
    }
}
#[cfg(debug_assertions)]
fn report_renderer(adapter: Option<Res<bevy::render::renderer::RenderAdapterInfo>>) {
    let Some(adapter) = adapter else {
        return;
    };
    if let Some(path) = std::env::var_os("HOLLIE_RENDERER_REPORT") {
        let info = serde_json::json!({"name":adapter.name,"device_type":format!("{:?}",adapter.device_type),"backend":format!("{:?}",adapter.backend)});
        let path = std::path::PathBuf::from(path);
        let temp = path.with_extension("json.tmp");
        std::fs::write(&temp, info.to_string()).expect("write renderer report");
        std::fs::rename(temp, path).expect("publish renderer report");
    }
}
fn simulate(mut game: ResMut<Game_World>, mut controls: ResMut<Controls>, window: Query<&Window>) {
    #[cfg(debug_assertions)]
    if std::env::var_os("HOLLIE_CONTROL_DIR").is_some() {
        return;
    }
    if window.iter().any(|w| !w.focused) {
        controls.players.iter_mut().for_each(|p| {
            p.jump = false;
            p.interact = false;
        });
        return;
    }
    if let Err(error) = game.step(controls.players, STEP) {
        error!("Simulation error: {error}");
    }
    // Edges survive until one simulation tick, not every FixedUpdate in a slow frame.
    for p in &mut controls.players {
        p.jump = false;
        p.interact = false;
    }
}
pub fn run() {
    let root = std::env::var("RES_ROOT").unwrap_or_else(|_| "res".into());
    let settings = WgpuSettings {
        force_fallback_adapter: std::env::var("WGPU_FORCE_FALLBACK_ADAPTER")
            .is_ok_and(|v| v == "true"),
        adapter_name: std::env::var("WGPU_ADAPTER_NAME").ok(),
        ..default()
    };
    let offscreen =
        cfg!(debug_assertions) && std::env::var("HOLLIE_OFFSCREEN").is_ok_and(|v| v == "1");
    let mut plugins = DefaultPlugins
        .build()
        .set(AssetPlugin {
            file_path: root,
            ..default()
        })
        .set(RenderPlugin {
            render_creation: RenderCreation::Automatic(Box::new(settings)),
            synchronous_pipeline_compilation: offscreen,
            ..default()
        })
        .set(WindowPlugin {
            primary_window: if offscreen {
                None
            } else {
                // Enter fullscreen through the UI after Winit creates the sized window;
                // MonitorSelection::Current has no monitor during window creation.
                Some(Window {
                    title: "hollie".into(),
                    resolution: (1280, 720).into(),
                    ..default()
                })
            },
            exit_condition: if offscreen {
                bevy::window::ExitCondition::DontExit
            } else {
                bevy::window::ExitCondition::OnAllClosed
            },
            ..default()
        });
    if offscreen {
        plugins = plugins
            .disable::<bevy::winit::WinitPlugin>()
            .disable::<bevy::gilrs::GilrsPlugin>();
    }
    let mut app = App::new();
    app.add_plugins(plugins).add_plugins(Hollie_Plugin);
    if offscreen {
        app.add_plugins(bevy::app::ScheduleRunnerPlugin::run_loop(
            std::time::Duration::from_secs_f64(1. / 60.),
        ));
    }
    app.run();
}

#[cfg(test)]
mod tests {
    use super::*;
    use bevy::asset::AssetApp;
    struct Headless_Shader_Assets;
    impl Plugin for Headless_Shader_Assets {
        fn build(&self, app: &mut App) {
            app.init_asset::<bevy::shader::Shader>()
                .init_asset_loader::<bevy::shader::ShaderLoader>();
        }
    }
    #[test]
    fn bevy_schedules_initialize_without_display_or_gpu() {
        // Winit and the renderer are disabled before plugin initialization.
        let mut app = App::new();
        app.add_plugins(
            DefaultPlugins
                .build()
                .add_before::<bevy::image::ImagePlugin>(Headless_Shader_Assets)
                .set(AssetPlugin {
                    file_path: "res".into(),
                    ..default()
                })
                .disable::<bevy::render::RenderPlugin>()
                .disable::<bevy::winit::WinitPlugin>()
                .disable::<bevy::audio::AudioPlugin>()
                .disable::<bevy::gilrs::GilrsPlugin>(),
        )
        .init_asset::<AudioSource>()
        .init_asset_loader::<bevy::audio::AudioLoader>()
        .add_plugins(Hollie_Plugin);
        app.finish();
        app.cleanup();
        app.update();
        app.world_mut()
            .resource_mut::<Game_World>()
            .reset("demo", 2, 42)
            .unwrap();
        app.world_mut()
            .resource_mut::<NextState<Mode>>()
            .set(Mode::Gameplay);
        app.update();
        app.update();
        assert_eq!(app.world().resource::<State<Mode>>().get(), &Mode::Gameplay);
        app.world_mut()
            .resource_mut::<NextState<Mode>>()
            .set(Mode::Paused);
        app.update();
        let frame = app.world().resource::<Game_World>().frame;
        app.update();
        assert_eq!(app.world().resource::<Game_World>().frame, frame);
    }
}
