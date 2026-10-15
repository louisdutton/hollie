use super::*;

impl Game_World<'_> {
    pub fn new(registry: Room_Registry) -> Result<Self> {
        let room = registry
            .get(INITIAL_ROOM)
            .or_else(|_| {
                registry
                    .rooms
                    .values()
                    .next()
                    .ok_or_else(|| anyhow::anyhow!("no rooms"))
            })?
            .room
            .clone();
        Ok(Self {
            actors: Vec::new(),
            state: Box::new(Game_State {
                registry,
                room,
                frame: 0,
                seed: 42,
                player_count: 1,
                generation: 0,
                elapsed: 0.,
                night: false,
                doors_enabled: false,
                transition: None,
                dialog: None,
                dialog_characters: 0.,
                effects: Vec::new(),
                surfaces: default(),
                rng: ChaCha8Rng::seed_from_u64(42),
            }),
        })
    }
}
impl<S: DerefMut<Target = Game_State>> Game_World<'_, S> {
    pub fn reset(&mut self, room: &str, players: usize, seed: u64) -> Result<()> {
        ensure!((1..=2).contains(&players), "players must be 1 or 2");
        let next = self.state.registry.get(room)?.room.clone();
        let mut pending = Game_World {
            state: Box::new((*self.state).clone()),
            actors: Vec::new(),
        };
        pending.seed = seed;
        pending.rng = ChaCha8Rng::seed_from_u64(seed);
        pending.player_count = players;
        pending.frame = 0;
        pending.elapsed = 0.;
        pending.night = false;
        pending.effects.clear();
        pending.transition = None;
        pending.load_room_inner(next, "")?;
        *self.state = *pending.state;
        self.actors = pending.actors;
        Ok(())
    }
    pub fn load_room(&mut self, room: Room, target: &str) -> Result<()> {
        let mut pending = Game_World {
            state: Box::new((*self.state).clone()),
            actors: Vec::new(),
        };
        pending.load_room_inner(room, target)?;
        *self.state = *pending.state;
        self.actors = pending.actors;
        Ok(())
    }
    pub(super) fn load_room_inner(&mut self, room: Room, target: &str) -> Result<()> {
        let mut actors = Vec::new();
        for entity in &room.entities {
            if matches!(entity.properties, Entity_Properties::Player(_)) {
                continue;
            }
            let size = match &entity.properties {
                Entity_Properties::Gate(p) => {
                    Vec3::new(p.size.width as f32, 32., p.size.height as f32)
                }
                Entity_Properties::Door(p) => {
                    Vec3::new(p.size.width as f32, 32., p.size.height as f32)
                }
                Entity_Properties::Pressure_Plate(_) => Vec3::new(28., 4., 28.),
                Entity_Properties::Holdable(_) => Vec3::splat(16.),
                Entity_Properties::Enemy(p) => match p.kind {
                    Character_Kind::Horse => Vec3::new(16., 30., 36.),
                    Character_Kind::Bison => Vec3::new(22., 30., 38.),
                    Character_Kind::Turtle => Vec3::new(24., 12., 30.),
                    _ => Vec3::new(12., 20., 20.),
                },
                _ => Vec3::new(12., 24., 12.),
            };
            let centered = !matches!(
                entity.properties,
                Entity_Properties::Gate(_) | Entity_Properties::Door(_)
            );
            actors.push(Actor::new(
                Actor_Identity {
                    id: actors.len() as u64 + 1,
                    source_id: entity.id.clone(),
                    properties: entity.properties.clone(),
                },
                Body::new(entity.position.vector(), size, centered),
            ));
        }
        let door = actors
            .iter()
            .position(|actor| {
                matches!(&actor.properties, Entity_Properties::Door(properties)
                if actor.source_id == target || properties.target_door_id == target)
            })
            .or_else(|| {
                actors
                    .iter()
                    .position(|actor| matches!(actor.properties, Entity_Properties::Door(_)))
            });

        self.state.surfaces = default();
        self.state.room = room;
        self.actors = actors;
        self.state.dialog = None;
        self.state.dialog_characters = 0.;
        self.state.doors_enabled = false;
        for index in 0..self.state.player_count {
            let marker = self.state.room.entities.iter().find(
                |e| matches!(&e.properties,Entity_Properties::Player(p) if p.player_index==index+1),
            );
            let fallback = marker.map(|e| e.position.vector()).unwrap_or_else(|| {
                Vec2::new(
                    self.state.room.collision_bounds.x + 32.,
                    self.state.room.collision_bounds.y + 32.,
                )
            });
            let position = if let Some(door) = door {
                self.door_spawn(&self.actors[door], index)?
            } else {
                fallback
            };
            let id = self.actors.len() as u64 + 1;
            self.actors.push(Actor::new(
                Actor_Identity {
                    id,
                    source_id: format!("player_{}", index + 1),
                    properties: Entity_Properties::Player(Player_Properties {
                        player_index: index + 1,
                    }),
                },
                Body::new(position, Vec3::new(12., 24., 12.), true),
            ));
        }
        self.state.generation += 1;
        Ok(())
    }
    pub(super) fn door_spawn(&self, door: &Actor, index: usize) -> Result<Vec2> {
        let bounds = door.body.bounds();
        let center = (bounds.min + bounds.max) / 2.;
        let side = if self.state.room.interior { -1. } else { 1. };
        let first = Vec2::new(
            center.x + (index as f32) * 16.,
            if side < 0. {
                bounds.min.z - 8.
            } else {
                bounds.max.z + 8.
            },
        );
        let mut candidates = vec![
            first,
            Vec2::new(
                first.x,
                if side < 0. {
                    bounds.max.z + 8.
                } else {
                    bounds.min.z - 8.
                },
            ),
        ];
        let t = self.state.room.grid.tile_size as f32;
        for y in 0..self.state.room.size.height {
            for x in 0..self.state.room.size.width {
                candidates.push(Vec2::new((x as f32 + 0.5) * t, (y as f32 + 0.5) * t));
            }
        }
        let solids = self.static_obstacles();
        candidates
            .into_iter()
            .filter(|p| self.state.room.collision_bounds.contains(*p))
            .filter(|p| {
                let b = Body::new(*p, Vec3::new(12., 24., 12.), true).bounds();
                !self.tile_blocked(b)
                    && !self.state.room.water_at(*p)
                    && !solids.iter().any(|s| s.intersects(b))
                    && !self.actors.iter().any(|a| {
                        (a.solid()
                            || a.player().is_some()
                            || matches!(a.properties, Entity_Properties::Door(_)))
                            && a.body.bounds().intersects(b)
                    })
                    && !self.state.room.structures.iter().any(|s| {
                        let q = s.position.vector();
                        p.x > q.x
                            && p.y > q.y
                            && p.x < q.x + s.size.width as f32
                            && p.y < q.y + s.size.height as f32
                    })
            })
            .min_by(|a, b| {
                a.distance_squared(first)
                    .total_cmp(&b.distance_squared(first))
            })
            .ok_or_else(|| anyhow::anyhow!("no safe door spawn"))
    }
}
