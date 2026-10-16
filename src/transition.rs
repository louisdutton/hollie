use crate::{
    app::Mode,
    rendering::{Main_Camera, Model},
    simulation::Game_Access,
};
use bevy::{
    asset::RenderAssetUsages,
    camera::{CameraOutputMode, ClearColorConfig, RenderTarget},
    prelude::*,
    render::{
        ExtractSchedule, MainWorld, RenderApp,
        mesh::RenderMesh,
        render_asset::RenderAssets,
        render_resource::{CachedPipelineState, PipelineCache},
        texture::GpuImage,
    },
    world_serialization::{WorldInstance, WorldInstanceSpawner},
};

const FADE_SECONDS: f32 = 0.35;
const READY_FRAMES: u32 = 5;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub(crate) enum Phase {
    #[default]
    Loading,
    Revealing,
    Visible,
    Covering,
}
#[derive(Clone, Copy)]
pub(crate) enum Destination {
    Title,
    New_Game,
    Tree_Study,
}
#[derive(Resource)]
pub(crate) struct Scene_Transition {
    pub phase: Phase,
    pub alpha: f32,
    pub confirmations: u32,
    scene: Option<(Mode, u64)>,
    destination: Option<Destination>,
    elapsed: f32,
    last_render: u64,
    signature: (usize, usize, usize),
}
impl Default for Scene_Transition {
    fn default() -> Self {
        Self {
            phase: Phase::Loading,
            alpha: 1.,
            confirmations: 0,
            scene: None,
            destination: None,
            elapsed: 0.,
            last_render: 0,
            signature: default(),
        }
    }
}
impl Scene_Transition {
    pub fn busy(&self) -> bool {
        self.phase != Phase::Visible
    }
    pub fn loading(&self) -> bool {
        self.phase == Phase::Loading
    }
    pub fn request(&mut self, destination: Destination) {
        if !self.busy() {
            self.destination = Some(destination);
            self.phase = Phase::Covering;
            self.elapsed = 0.;
        }
    }
    fn begin_loading(&mut self) {
        self.phase = Phase::Loading;
        self.alpha = 1.;
        self.elapsed = 0.;
        self.confirmations = 0;
    }
    fn confirm(&mut self, assets_ready: bool, render: &Render_Readiness) {
        if !assets_ready || !render.ready || self.signature != render.signature {
            self.confirmations = 0;
        } else if self.last_render != render.frame {
            self.confirmations += 1;
        }
        self.signature = render.signature;
        self.last_render = render.frame;
        if self.confirmations >= READY_FRAMES {
            self.phase = Phase::Revealing;
            self.elapsed = 0.;
        }
    }
}
#[derive(Resource, Default)]
pub(crate) struct Render_Readiness {
    frame: u64,
    pub ready: bool,
    signature: (usize, usize, usize),
}
#[derive(Component)]
pub(crate) struct Transition_Fade;
#[derive(Component)]
struct Fade_Camera;

pub(crate) struct Transition_Plugin;
impl Plugin for Transition_Plugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Scene_Transition>()
            .init_resource::<Render_Readiness>()
            .insert_resource(ClearColor(Color::BLACK))
            .add_systems(PostStartup, setup)
            .add_systems(PostUpdate, (advance, display).chain());
        // Match Bevy's loading-screen pattern: render-world readiness is
        // published through MainWorld during extraction, never by blocking.
        if let Some(render) = app.get_sub_app_mut(RenderApp) {
            render.add_systems(ExtractSchedule, report_readiness);
        }
    }
}
fn setup(mut commands: Commands, target: Single<&RenderTarget, With<Main_Camera>>) {
    let overlay = commands
        .spawn((
            Camera2d,
            Msaa::Off,
            Camera {
                order: 100,
                clear_color: ClearColorConfig::Custom(Color::BLACK),
                ..default()
            },
            (*target).clone(),
            Fade_Camera,
        ))
        .id();
    commands.spawn((
        Node {
            position_type: PositionType::Absolute,
            width: percent(100),
            height: percent(100),
            ..default()
        },
        UiTargetCamera(overlay),
        GlobalZIndex(100),
        BackgroundColor(Color::BLACK),
        Pickable::IGNORE,
        Transition_Fade,
    ));
}
// Count completed rendered frames, not Update iterations: pipelined rendering
// can lag the main world. Newly queued pipelines/uploads restart confirmation.
fn report_readiness(
    mut main: ResMut<MainWorld>,
    pipelines: Res<PipelineCache>,
    meshes: Res<RenderAssets<RenderMesh>>,
    images: Res<RenderAssets<GpuImage>>,
) {
    let mesh_assets = main.resource::<Assets<Mesh>>();
    let image_assets = main.resource::<Assets<Image>>();
    let ready = pipelines
        .pipelines()
        .all(|pipeline| matches!(pipeline.state, CachedPipelineState::Ok(_)))
        && mesh_assets.iter().all(|(id, mesh)| {
            !mesh.asset_usage.contains(RenderAssetUsages::RENDER_WORLD) || meshes.get(id).is_some()
        })
        && image_assets.iter().all(|(id, image)| {
            !image.asset_usage.contains(RenderAssetUsages::RENDER_WORLD) || images.get(id).is_some()
        });
    let signature = (
        pipelines.pipelines().count(),
        mesh_assets.len(),
        image_assets.len(),
    );
    let mut report = main.resource_mut::<Render_Readiness>();
    report.frame += 1;
    report.ready = ready;
    report.signature = signature;
}
#[derive(bevy::ecs::system::SystemParam)]
struct Scene_Assets<'w, 's> {
    server: Res<'w, AssetServer>,
    models: Query<'w, 's, &'static Model>,
    roots: Query<'w, 's, Option<&'static WorldInstance>, With<WorldAssetRoot>>,
    spawner: Res<'w, WorldInstanceSpawner>,
    fonts: Query<'w, 's, &'static TextFont>,
    font_assets: Res<'w, Assets<Font>>,
    logos: Res<'w, Assets<crate::ui::Logo_Material>>,
}
impl Scene_Assets<'_, '_> {
    fn ready(&self) -> bool {
        self.models
            .iter()
            .all(|model| self.server.is_loaded_with_dependencies(model.gltf.id()))
            && self
                .roots
                .iter()
                .all(|instance| instance.is_some_and(|id| self.spawner.instance_is_ready(**id)))
            && self.fonts.iter().all(|font| {
                font.font.flatten().iter().all(|source| match source {
                    bevy::text::FontSource::Handle(handle) => {
                        self.font_assets.contains(handle.id())
                    }
                    _ => true,
                })
            })
            && self
                .logos
                .iter()
                .all(|(_, logo)| self.server.are_dependencies_loaded(logo))
    }
}
fn advance(
    mut transition: ResMut<Scene_Transition>,
    render: Res<Render_Readiness>,
    mode: Res<State<Mode>>,
    time: Res<Time>,
    mut game: Game_Access,
    mut next: ResMut<NextState<Mode>>,
    assets: Scene_Assets,
) {
    let scene = match mode.get() {
        Mode::Title => (Mode::Title, 0),
        Mode::Tree_Study => (Mode::Tree_Study, 0),
        Mode::Gameplay => (Mode::Gameplay, game.generation),
        Mode::Paused | Mode::Editor => transition
            .scene
            .clone()
            .unwrap_or((Mode::Gameplay, game.generation)),
    };
    if transition.scene.as_ref() != Some(&scene) {
        transition.scene = Some(scene);
        transition.begin_loading();
    }
    match transition.phase {
        Phase::Loading => transition.confirm(assets.ready(), &render),
        Phase::Covering | Phase::Revealing => {
            transition.elapsed += time.delta_secs().min(0.1);
            let progress = (transition.elapsed / FADE_SECONDS).clamp(0., 1.);
            let smooth = progress * progress * (3. - 2. * progress);
            transition.alpha = if transition.phase == Phase::Covering {
                smooth
            } else {
                1. - smooth
            };
            if progress >= 1. {
                if let Some(destination) = transition.destination.take() {
                    match destination {
                        Destination::Title => next.set(Mode::Title),
                        Destination::Tree_Study => next.set(Mode::Tree_Study),
                        Destination::New_Game => {
                            match game.reset(crate::simulation::INITIAL_ROOM, 42) {
                                Ok(()) => next.set(Mode::Gameplay),
                                Err(error) => error!("Cannot start game: {error}"),
                            }
                        }
                    }
                    transition.begin_loading();
                } else {
                    transition.phase = Phase::Visible;
                }
            }
        }
        Phase::Visible => {}
    }
}
fn display(
    transition: Res<Scene_Transition>,
    game: Res<crate::simulation::Game_State>,
    mut main: Single<&mut Camera, (With<Main_Camera>, Without<Fade_Camera>)>,
    mut overlay: Single<&mut Camera, (With<Fade_Camera>, Without<Main_Camera>)>,
    mut fade: Single<&mut BackgroundColor, With<Transition_Fade>>,
) {
    let door_alpha = game
        .transition
        .as_ref()
        .filter(|door| !door.loaded)
        .map_or(0., |door| (door.elapsed / 0.3).clamp(0., 1.));
    let alpha = transition.alpha.max(door_alpha);
    // Skip only the final output, keeping the scene's render graph running
    // behind a shader-independent black camera clear while pipelines warm up.
    main.output_mode = if transition.loading() && transition.confirmations == 0 {
        CameraOutputMode::Skip
    } else {
        CameraOutputMode::default()
    };
    overlay.is_active = (main.is_active || transition.busy()) && alpha > 0.;
    overlay.clear_color = if alpha >= 1. {
        ClearColorConfig::Custom(Color::BLACK)
    } else {
        ClearColorConfig::None
    };
    fade.0 = Color::srgba(0., 0., 0., alpha);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reveal_requires_assets_and_consecutive_completed_render_frames() {
        let mut transition = Scene_Transition::default();
        let mut render = Render_Readiness {
            ready: true,
            ..default()
        };
        for frame in 1..=READY_FRAMES {
            render.frame = frame as u64;
            transition.confirm(false, &render);
        }
        assert_eq!(transition.phase, Phase::Loading);
        for frame in 10..10 + READY_FRAMES - 1 {
            render.frame = frame as u64;
            transition.confirm(true, &render);
            transition.confirm(true, &render);
        }
        assert_eq!(
            transition.phase,
            Phase::Loading,
            "Update iterations cannot stand in for rendered frames"
        );
        render.ready = false;
        transition.confirm(true, &render);
        assert_eq!(transition.confirmations, 0);
        render.ready = true;
        render.signature.0 += 1;
        transition.confirm(true, &render);
        assert_eq!(transition.confirmations, 0, "new pipelines must settle too");
        for frame in 20..20 + READY_FRAMES {
            render.frame = frame as u64;
            transition.confirm(true, &render);
        }
        assert_eq!(transition.phase, Phase::Revealing);
        assert_eq!(transition.alpha, 1., "start revealing from opaque black");
    }

    #[test]
    fn black_cover_survives_scene_rebuild_and_composes_with_door_fades() {
        let game = crate::simulation::Game_World::new(
            crate::content::Room_Registry::load(std::path::Path::new("res")).unwrap(),
        )
        .unwrap();
        let mut app = App::new();
        app.add_plugins(MinimalPlugins)
            .insert_resource(*game.state)
            .init_resource::<Scene_Transition>()
            .add_systems(Update, display);
        let main = app.world_mut().spawn((Camera::default(), Main_Camera)).id();
        let overlay = app.world_mut().spawn((Camera::default(), Fade_Camera)).id();
        let fade = app
            .world_mut()
            .spawn((BackgroundColor(Color::NONE), Transition_Fade))
            .id();
        app.update();
        assert!(matches!(
            app.world().get::<Camera>(main).unwrap().output_mode,
            CameraOutputMode::Skip
        ));
        assert!(matches!(
            app.world().get::<Camera>(overlay).unwrap().clear_color,
            ClearColorConfig::Custom(color) if color == Color::BLACK
        ));
        assert_eq!(
            app.world().get::<BackgroundColor>(fade).unwrap().0.alpha(),
            1.
        );
        {
            let mut transition = app.world_mut().resource_mut::<Scene_Transition>();
            transition.phase = Phase::Visible;
            transition.alpha = 0.;
        }
        app.world_mut()
            .resource_mut::<crate::simulation::Game_State>()
            .transition = Some(crate::simulation::Transition {
            room: "demo".into(),
            door: String::new(),
            loaded: false,
            elapsed: 0.15,
        });
        app.update();
        assert_eq!(
            app.world().get::<BackgroundColor>(fade).unwrap().0.alpha(),
            0.5
        );
        app.world_mut()
            .resource_mut::<Scene_Transition>()
            .begin_loading();
        app.world_mut()
            .resource_mut::<crate::simulation::Game_State>()
            .transition = None;
        app.update();
        assert_eq!(
            app.world().get::<BackgroundColor>(fade).unwrap().0.alpha(),
            1.
        );
    }
}
