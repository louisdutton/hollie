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
    pub actors: Query<'w, 's, Actor_QueryReadOnly>,
}
impl Deref for Game_View<'_, '_> {
    type Target = Game_State;
    fn deref(&self) -> &Self::Target {
        &self.state
    }
}
impl Game_View<'_, '_> {
    pub fn observation(&self) -> Value {
        let mut actors: Vec<_> = self.actors.iter().map(Actor::snapshot).collect();
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
    pub actors: Query<'w, 's, Actor_Query>,
    entities: Query<'w, 's, Entity, With<Actor_Identity>>,
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
    // The batch contains borrows of component storage, sorted by authored ID.
    // Contact order must not depend on ECS allocation or archetype layout.
    pub(crate) fn with_simulation<R>(
        &mut self,
        run: impl FnOnce(&mut Game_World<'_, &mut Game_State>) -> R,
    ) -> R {
        let generation = self.state.generation;
        let mut actors: Vec<_> = self.actors.iter_mut().map(Actor::borrowed).collect();
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
                self.commands.spawn(actor.into_bundle());
            }
        } else {
            // Body/state writes above already reached ECS. Only structural changes
            // (death and relationship edits) require deferred commands.
            let links: Vec<_> = actors
                .iter()
                .map(|a| {
                    (
                        a.entity,
                        a.is_player(),
                        a.mounted,
                        a.held_by,
                        a.release_player,
                    )
                })
                .collect();
            drop(actors);
            for entity in &self.entities {
                if !links.iter().any(|link| link.0 == entity) {
                    self.commands.entity(entity).despawn();
                }
            }
            for (entity, player, mount, carrier, released) in links {
                let actor = self.actors.get(entity).expect("live solver actor");
                let mut commands = self.commands.entity(entity);
                if player && actor.mounted() != mount {
                    if let Some(target) = mount {
                        commands.insert(Mounted_On(target));
                    } else {
                        commands.remove::<Mounted_On>();
                    }
                }
                if actor.held_by() != carrier {
                    if let Some(target) = carrier {
                        commands.insert(Carried_By(target));
                    } else {
                        commands.remove::<Carried_By>();
                    }
                }
                if actor.release_player() != released {
                    if let Some(target) = released {
                        commands.insert(Released_By(target));
                    } else {
                        commands.remove::<Released_By>();
                    }
                }
            }
        }
        result
    }
    pub fn reset(&mut self, room: &str, seed: u64) -> Result<()> {
        self.with_simulation(|game| game.reset(room, seed))
    }
    pub fn load_room(&mut self, room: Room, target: &str) -> Result<()> {
        self.with_simulation(|game| game.load_room(room, target))
    }
    pub(crate) fn step(&mut self, inputs: Player_Input, dt: f32) -> Result<()> {
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
        if let Err(error) = game.step(controls.player, STEP) {
            error!("Simulation error: {error}");
        }
    }
    // Input edges are consumed once, even if a render frame contains several fixed ticks.
    controls.player.jump = false;
    controls.player.interact = false;
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
                game.reset("demo", 42).unwrap();
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
            .run_system_once(|mut actors: Query<Actor_Query>| {
                let mut player = actors.iter_mut().find(|a| a.is_player()).unwrap();
                player.body.height = 1.;
                player.body.vertical_velocity = -200.;
                player.body.grounded = false;
            })
            .unwrap();
        app.world_mut()
            .run_system_once(|mut game: Game_Access| {
                game.step(default(), STEP).unwrap();
                game.step(default(), STEP).unwrap();
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
    fn solver_writes_borrowed_components_without_a_copy_back_pass() {
        let mut app = app();
        reset(&mut app);
        app.world_mut()
            .run_system_once(|mut game: Game_Access| {
                game.with_simulation(|solver| {
                    assert!(
                        solver
                            .actors
                            .iter()
                            .all(|actor| matches!(actor.body, Component_Data::Borrowed(_)))
                    );
                    solver
                        .actors
                        .iter_mut()
                        .find(|a| a.is_player())
                        .unwrap()
                        .body
                        .height = 23.;
                });
            })
            .unwrap();
        app.world_mut()
            .run_system_once(|bodies: Query<(&Actor_Identity, &Body)>| {
                assert_eq!(
                    bodies
                        .iter()
                        .find(|(id, _)| id.is_player())
                        .unwrap()
                        .1
                        .height,
                    23.
                );
            })
            .unwrap();
    }
    #[test]
    fn relationships_enforce_exclusivity_and_clean_up_on_despawn() {
        let mut app = app();
        reset(&mut app);
        let mut actors: Vec<_> = app
            .world_mut()
            .query::<(Entity, &Actor_Identity)>()
            .iter(app.world())
            .map(|(entity, identity)| (identity.id, entity))
            .collect();
        actors.sort_by_key(|a| a.0);
        let [(_, first), (_, second), (_, target), ..] = actors[..] else {
            panic!("fixture actors")
        };
        app.world_mut().entity_mut(first).insert(Mounted_On(target));
        assert_eq!(app.world().get::<Riders>(target).unwrap().rider(), first);
        app.world_mut()
            .entity_mut(second)
            .insert(Mounted_On(target));
        assert!(app.world().get::<Mounted_On>(first).is_none());
        assert_eq!(app.world().get::<Riders>(target).unwrap().rider(), second);
        app.world_mut().entity_mut(first).insert(Carried_By(target));
        app.world_mut()
            .entity_mut(second)
            .insert(Carried_By(target));
        assert!(app.world().get::<Carried_By>(first).is_none());
        assert_eq!(
            app.world().get::<Carried_Items>(target).unwrap().item(),
            second
        );
        let visual = app
            .world_mut()
            .spawn(crate::rendering::Actor_Visual(target))
            .id();
        let child = app.world_mut().spawn(ChildOf(visual)).id();
        app.world_mut().despawn(target);
        assert!(app.world().get::<Mounted_On>(second).is_none());
        assert!(app.world().get::<Carried_By>(second).is_none());
        assert!(app.world().get_entity(visual).is_err());
        assert!(app.world().get_entity(child).is_err());
    }
    #[test]
    fn actor_components_are_authoritative_and_reset_is_atomic() {
        let mut app = app();
        reset(&mut app);
        app.world_mut()
            .run_system_once(|mut actors: Query<Actor_Query>| {
                let mut player = actors.iter_mut().find(|actor| actor.is_player()).unwrap();
                player.body.height = 17.;
            })
            .unwrap();
        let before = observe(&mut app);
        assert_eq!(before["players"][0]["body"]["height"], 17.);
        app.world_mut()
            .run_system_once(|mut game: Game_Access| {
                assert!(game.reset("missing-room", 99).is_err());
            })
            .unwrap();
        assert_eq!(observe(&mut app), before);
        reset(&mut app);
        assert_eq!(observe(&mut app)["players"][0]["body"]["height"], 0.);
    }
    #[test]
    fn failed_spawn_keeps_live_entities_components_and_relationships() {
        let mut app = app();
        reset(&mut app);
        let (player, item) = app
            .world_mut()
            .run_system_once(|actors: Query<(Entity, &Actor_Identity)>| {
                (
                    actors
                        .iter()
                        .find(|(_, identity)| identity.is_player())
                        .unwrap()
                        .0,
                    actors
                        .iter()
                        .find(|(_, identity)| {
                            matches!(identity.properties, Entity_Properties::Holdable(_))
                        })
                        .unwrap()
                        .0,
                )
            })
            .unwrap();
        app.world_mut().entity_mut(item).insert(Carried_By(player));
        let before = observe(&mut app);
        let generation = app.world().resource::<Game_State>().generation;
        app.world_mut()
            .run_system_once(|mut game: Game_Access| {
                game.registry
                    .rooms
                    .get_mut("demo")
                    .unwrap()
                    .room
                    .layers
                    .collision
                    .fill(1);
                assert!(game.reset("demo", 777).is_err());
            })
            .unwrap();
        assert_eq!(observe(&mut app), before);
        assert_eq!(app.world().resource::<Game_State>().generation, generation);
        assert!(app.world().get::<Body>(player).is_some());
        assert_eq!(app.world().get::<Carried_By>(item).unwrap().0, player);
        assert_eq!(
            app.world().get::<Carried_Items>(player).unwrap().item(),
            item
        );
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
            expected.reset("demo", 42).unwrap();
            for frame in 0..90 {
                let inputs = Player_Input {
                    movement: Vec2::Y,
                    jump: frame == 20,
                    interact: false,
                };
                expected.step(inputs, STEP).unwrap();
                app.world_mut()
                    .run_system_once(move |mut game: Game_Access| game.step(inputs, STEP).unwrap())
                    .unwrap();
            }
            assert_eq!(observe(&mut app), expected.observation());
        }
    }
}
