use super::*;
use crate::{app::Mode, input::Controls};
use bevy::ecs::system::SystemParam;

#[derive(Message, Clone, Copy, Debug)]
pub(crate) struct Impact {
    pub position: Vec3,
    pub burst: bool,
    pub generation: u64,
    pub born: f32,
}

#[derive(SystemParam)]
pub struct Game_View<'w, 's> {
    state: Res<'w, Game_State>,
    pub actors: Query<'w, 's, &'static Actor>,
}
impl Deref for Game_View<'_, '_> {
    type Target = Game_State;
    fn deref(&self) -> &Self::Target {
        &self.state
    }
}
impl Game_View<'_, '_> {
    pub fn observation(&self) -> Value {
        let mut actors: Vec<_> = self.actors.iter().cloned().collect();
        actors.sort_by_key(|actor| actor.id);
        Game_World {
            state: &*self.state,
            actors,
        }
        .observation()
    }
}

#[derive(SystemParam)]
pub struct Game_Access<'w, 's> {
    state: ResMut<'w, Game_State>,
    pub actors: Query<'w, 's, &'static mut Actor>,
    entities: Query<'w, 's, Entity, With<Actor>>,
    commands: Commands<'w, 's>,
    impacts: MessageWriter<'w, Impact>,
}
impl Deref for Game_Access<'_, '_> {
    type Target = Game_State;
    fn deref(&self) -> &Self::Target {
        &self.state
    }
}
impl DerefMut for Game_Access<'_, '_> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.state
    }
}
impl Game_Access<'_, '_> {
    // Contact resolution is ordered and couples bodies. Its temporary batch is sorted
    // by authored ID so entity allocation/archetype order cannot change seeded replays.
    // Actor components remain authoritative; no second persistent actor store exists.
    pub(crate) fn with_simulation<R>(
        &mut self,
        run: impl FnOnce(&mut Game_World<&mut Game_State>) -> R,
    ) -> R {
        let generation = self.state.generation;
        let mut actors: Vec<_> = self.actors.iter().cloned().collect();
        actors.sort_by_key(|actor| actor.id);
        let (result, actors) = {
            let mut simulation = Game_World {
                state: &mut *self.state,
                actors,
            };
            let result = run(&mut simulation);
            (result, simulation.actors)
        };
        if generation != self.state.generation {
            for entity in &self.entities {
                self.commands.entity(entity).despawn();
            }
            for actor in actors {
                self.commands.spawn(actor);
            }
        } else {
            let mut existing: BTreeMap<_, _> = self
                .entities
                .iter()
                .filter_map(|entity| self.actors.get(entity).ok().map(|actor| (actor.id, entity)))
                .collect();
            for actor in actors {
                if let Some(entity) = existing.remove(&actor.id) {
                    *self.actors.get_mut(entity).expect("live actor") = actor;
                } else {
                    self.commands.spawn(actor);
                }
            }
            for entity in existing.into_values() {
                self.commands.entity(entity).despawn();
            }
        }
        result
    }
    pub fn reset(&mut self, room: &str, players: usize, seed: u64) -> Result<()> {
        self.with_simulation(|game| game.reset(room, players, seed))
    }
    pub fn load_room(&mut self, room: Room, target: &str) -> Result<()> {
        self.with_simulation(|game| game.load_room(room, target))
    }
    pub(crate) fn step(&mut self, inputs: [Player_Input; 2], dt: f32) -> Result<()> {
        let result = self.with_simulation(|game| game.step(inputs, dt));
        if result.is_ok() {
            self.impacts
                .write_batch(self.state.effects.iter().map(|(position, burst)| Impact {
                    position: *position,
                    burst: *burst,
                    generation: self.state.generation,
                    born: self.state.elapsed,
                }));
        }
        result
    }
}

pub struct Simulation_Plugin;
impl Plugin for Simulation_Plugin {
    fn build(&self, app: &mut App) {
        let root = std::env::var("RES_ROOT").unwrap_or_else(|_| "res".into());
        let registry =
            Room_Registry::load(std::path::Path::new(&root)).expect("room content must validate");
        let game = Game_World::new(registry).expect("initial room");
        app.add_message::<Impact>()
            .insert_resource(*game.state)
            .insert_resource(Time::<Fixed>::from_seconds(STEP as f64))
            .add_systems(FixedUpdate, simulate.run_if(in_state(Mode::Gameplay)));
    }
}
fn simulate(
    mut game: Game_Access,
    mut controls: ResMut<Controls>,
    windows: Query<&Window>,
    #[cfg(debug_assertions)] controller: Res<crate::automation::Controller>,
) {
    #[cfg(debug_assertions)]
    if controller.enabled() {
        return;
    }
    if windows.iter().all(|window| window.focused) {
        if let Err(error) = game.step(controls.players, STEP) {
            error!("Simulation error: {error}");
        }
    }
    // Input edges are consumed once, even if a render frame contains several fixed ticks.
    for input in &mut controls.players {
        input.jump = false;
        input.interact = false;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use bevy::ecs::system::RunSystemOnce;

    fn app() -> App {
        let mut app = App::new();
        app.add_plugins((MinimalPlugins, bevy::state::app::StatesPlugin))
            .init_state::<Mode>()
            .init_resource::<Controls>()
            .add_plugins(Simulation_Plugin);
        #[cfg(debug_assertions)]
        app.init_resource::<crate::automation::Controller>();
        app
    }
    fn reset(app: &mut App) {
        app.world_mut()
            .run_system_once(|mut game: Game_Access| {
                game.reset("demo", 2, 42).unwrap();
            })
            .unwrap();
    }
    fn observe(app: &mut App) -> Value {
        app.world_mut()
            .run_system_once(|game: Game_View| game.observation())
            .unwrap()
    }
    #[test]
    fn impacts_survive_multiple_simulation_ticks_for_independent_consumers() {
        use bevy::ecs::message::MessageCursor;
        let mut app = app();
        reset(&mut app);
        app.world_mut()
            .run_system_once(|mut actors: Query<&mut Actor>| {
                let mut player = actors.iter_mut().find(|a| a.player() == Some(0)).unwrap();
                player.body.height = 1.;
                player.body.vertical_velocity = -200.;
                player.body.grounded = false;
            })
            .unwrap();
        app.world_mut()
            .run_system_once(|mut game: Game_Access| {
                game.step([default(); 2], STEP).unwrap();
                game.step([default(); 2], STEP).unwrap();
                assert!(game.effects.is_empty());
            })
            .unwrap();
        let messages = app.world().resource::<Messages<Impact>>();
        let mut visuals = MessageCursor::<Impact>::default();
        let mut audio = MessageCursor::<Impact>::default();
        assert_eq!(visuals.read(messages).count(), 1);
        assert_eq!(audio.read(messages).count(), 1);
        assert_eq!(visuals.read(messages).count(), 0);
    }
    #[test]
    fn actor_components_are_authoritative_and_reset_is_atomic() {
        let mut app = app();
        reset(&mut app);
        app.world_mut()
            .run_system_once(|mut actors: Query<&mut Actor>| {
                let mut player = actors
                    .iter_mut()
                    .find(|actor| actor.player() == Some(0))
                    .unwrap();
                player.body.height = 17.;
            })
            .unwrap();
        let before = observe(&mut app);
        assert_eq!(before["players"][0]["body"]["height"], 17.);
        app.world_mut()
            .run_system_once(|mut game: Game_Access| {
                assert!(game.reset("missing-room", 2, 99).is_err());
            })
            .unwrap();
        assert_eq!(observe(&mut app), before);
        reset(&mut app);
        assert_eq!(observe(&mut app)["players"][0]["body"]["height"], 0.);
    }
    #[test]
    fn ecs_ticks_match_the_solver_after_entity_allocation_changes() {
        let mut app = app();
        let mut expected =
            Game_World::new(Room_Registry::load(std::path::Path::new("res")).unwrap()).unwrap();
        for _ in 0..2 {
            // Alter entity allocation and archetype layout between identical seeded runs.
            app.world_mut()
                .spawn((Name::new("unrelated"), Transform::default()));
            reset(&mut app);
            expected.reset("demo", 2, 42).unwrap();
            for frame in 0..90 {
                let inputs = [
                    Player_Input {
                        movement: Vec2::Y,
                        jump: frame == 20,
                        interact: false,
                    },
                    default(),
                ];
                expected.step(inputs, STEP).unwrap();
                app.world_mut()
                    .run_system_once(move |mut game: Game_Access| game.step(inputs, STEP).unwrap())
                    .unwrap();
            }
            assert_eq!(observe(&mut app), expected.observation());
        }
    }
}
