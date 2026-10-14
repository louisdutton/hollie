use crate::content::*;
use anyhow::{Result, ensure};
use bevy::prelude::*;
use rand::{Rng, SeedableRng};
use rand_chacha::ChaCha8Rng;
use serde_json::{Value, json};
use std::collections::BTreeMap;

pub const STEP: f32 = 1. / 60.;
pub const GRAVITY: f32 = 800.;
pub const JUMP_SPEED: f32 = 220.;
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Aabb {
    pub min: Vec3,
    pub max: Vec3,
}
impl Aabb {
    pub fn intersects(self, other: Self) -> bool {
        self.min.cmplt(other.max).all() && self.max.cmpgt(other.min).all()
    }
    pub fn horizontal(self, other: Self) -> bool {
        self.min.x < other.max.x
            && self.max.x > other.min.x
            && self.min.z < other.max.z
            && self.max.z > other.min.z
    }
    pub fn shifted(self, offset: Vec3) -> Self {
        Self {
            min: self.min + offset,
            max: self.max + offset,
        }
    }
}
#[derive(Clone, Debug)]
pub struct Body {
    pub position: Vec2,
    pub velocity: Vec2,
    pub height: f32,
    pub vertical_velocity: f32,
    pub grounded: bool,
    pub swimming: bool,
    pub size: Vec3,
    pub offset: Vec3,
}
impl Body {
    pub fn new(position: Vec2, size: Vec3, centered: bool) -> Self {
        Self {
            position,
            velocity: Vec2::ZERO,
            height: 0.,
            vertical_velocity: 0.,
            grounded: true,
            swimming: false,
            size,
            offset: if centered {
                Vec3::new(-size.x / 2., 0., -size.z / 2.)
            } else {
                Vec3::ZERO
            },
        }
    }
    pub fn bounds(&self) -> Aabb {
        let min = Vec3::new(self.position.x, self.height, self.position.y) + self.offset;
        Aabb {
            min,
            max: min + self.size,
        }
    }
    pub fn jump(&mut self, speed: f32) {
        if self.grounded || self.swimming {
            self.vertical_velocity = speed;
            self.grounded = false;
        }
    }
}
#[derive(Clone, Debug)]
pub struct Actor {
    pub id: u64,
    pub source_id: String,
    pub properties: Entity_Properties,
    pub body: Body,
    pub facing: Vec2,
    pub mounted: Option<u64>,
    pub carrying: Option<u64>,
    pub held_by: Option<u64>,
    pub held_anchor: Option<Vec3>,
    pub release_player: Option<u64>,
    pub active: bool,
    pub open: bool,
    pub ram_charge: f32,
    pub ram_ready: bool,
    pub move_direction: Vec2,
    pub move_timer: f32,
    pub wait_timer: f32,
    pub coasting: bool,
    pub health: i32,
    pub death_timer: f32,
    pub mount_time: f32,
    pub mount_start: Vec3,
    pub pose: crate::visuals::Motion_Pose,
}
impl Actor {
    pub fn player(&self) -> Option<usize> {
        if let Entity_Properties::Player(p) = &self.properties {
            Some(p.player_index - 1)
        } else {
            None
        }
    }
    pub fn kind(&self) -> Option<Character_Kind> {
        if let Entity_Properties::Enemy(p) = &self.properties {
            Some(p.kind)
        } else {
            None
        }
    }
    pub fn movable(&self) -> bool {
        matches!(
            self.properties,
            Entity_Properties::Player(_)
                | Entity_Properties::Enemy(_)
                | Entity_Properties::Npc(_)
                | Entity_Properties::Holdable(_)
        )
    }
    pub fn solid(&self) -> bool {
        matches!(self.properties, Entity_Properties::Pressure_Plate(_))
            || matches!(self.properties, Entity_Properties::Gate(_)) && !self.open
            || matches!(self.properties, Entity_Properties::Holdable(_)) && self.held_by.is_none()
    }
}
#[derive(Clone, Copy, Debug, Default)]
pub struct Player_Input {
    pub movement: Vec2,
    pub jump: bool,
    pub interact: bool,
}
#[derive(Clone, Copy, Debug)]
pub struct Movement_Profile {
    pub min_speed: f32,
    pub max_speed: f32,
    pub acceleration: f32,
    pub deceleration: f32,
}
pub const PLAYER_PROFILE: Movement_Profile = Movement_Profile {
    min_speed: 20.,
    max_speed: 80.,
    acceleration: 640.,
    deceleration: 960.,
};
pub const RIDING_PROFILE: Movement_Profile = Movement_Profile {
    min_speed: 40.,
    max_speed: 160.,
    acceleration: 240.,
    deceleration: 360.,
};
pub fn accelerate(velocity: Vec2, direction: Vec2, profile: Movement_Profile, dt: f32) -> Vec2 {
    let magnitude = direction.length();
    let target = if magnitude > 0. {
        direction / magnitude
            * (profile.min_speed + (profile.max_speed - profile.min_speed) * magnitude.min(1.))
    } else {
        Vec2::ZERO
    };
    let delta = target - velocity;
    let distance = delta.length();
    if distance == 0. {
        return target;
    }
    let rate = if target.length_squared() < velocity.length_squared() || velocity.dot(target) < 0. {
        profile.deceleration
    } else {
        profile.acceleration
    };
    velocity + delta / distance * (rate * dt.max(0.)).min(distance)
}
pub fn camera_relative(direction: Vec2) -> Vec2 {
    Vec2::new(direction.x + direction.y, direction.y - direction.x)
        * std::f32::consts::FRAC_1_SQRT_2
}
#[derive(Clone, Debug)]
pub struct Transition {
    pub room: String,
    pub door: String,
    pub elapsed: f32,
    pub loaded: bool,
}
#[derive(Resource, Clone)]
pub struct Game_World {
    pub registry: Room_Registry,
    pub room: Room,
    pub actors: Vec<Actor>,
    pub frame: u64,
    pub seed: u64,
    pub player_count: usize,
    pub generation: u64,
    pub elapsed: f32,
    pub night: bool,
    pub doors_enabled: bool,
    pub transition: Option<Transition>,
    pub dialog: Option<usize>,
    pub dialog_characters: f32,
    pub effects: Vec<(Vec3, bool)>,
    pub surfaces: crate::visuals::Surface_State,
    rng: ChaCha8Rng,
}
impl Game_World {
    pub fn new(registry: Room_Registry) -> Result<Self> {
        let room = registry
            .get("demo")
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
            registry,
            room,
            actors: Vec::new(),
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
        })
    }
    pub fn reset(&mut self, room: &str, players: usize, seed: u64) -> Result<()> {
        ensure!((1..=2).contains(&players), "players must be 1 or 2");
        let next = self.registry.get(room)?.room.clone();
        let mut pending = self.clone();
        pending.seed = seed;
        pending.rng = ChaCha8Rng::seed_from_u64(seed);
        pending.player_count = players;
        pending.frame = 0;
        pending.elapsed = 0.;
        pending.night = false;
        pending.effects.clear();
        pending.transition = None;
        pending.load_room(next, "")?;
        *self = pending;
        Ok(())
    }
    pub fn load_room(&mut self, room: Room, target: &str) -> Result<()> {
        let mut pending = self.clone();
        pending.load_room_inner(room, target)?;
        *self = pending;
        Ok(())
    }
    fn load_room_inner(&mut self, room: Room, target: &str) -> Result<()> {
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
            actors.push(Actor {
                id: actors.len() as u64 + 1,
                source_id: entity.id.clone(),
                properties: entity.properties.clone(),
                body: Body::new(entity.position.vector(), size, centered),
                facing: Vec2::X,
                mounted: None,
                carrying: None,
                held_by: None,
                held_anchor: None,
                release_player: None,
                active: false,
                open: false,
                ram_charge: 0.,
                ram_ready: false,
                move_direction: Vec2::ZERO,
                move_timer: 0.,
                wait_timer: 0.,
                coasting: false,
                health: 100,
                death_timer: 0.,
                mount_time: 0.,
                mount_start: Vec3::ZERO,
                pose: default(),
            });
        }
        let door=actors.iter().find(|a|matches!(&a.properties,Entity_Properties::Door(d) if a.source_id==target || d.target_door_id==target)).or_else(||actors.iter().find(|a|matches!(a.properties,Entity_Properties::Door(_)))).cloned();
        self.surfaces = default();
        self.room = room;
        self.actors = actors;
        self.dialog = None;
        self.dialog_characters = 0.;
        self.doors_enabled = false;
        for index in 0..self.player_count {
            let marker = self.room.entities.iter().find(
                |e| matches!(&e.properties,Entity_Properties::Player(p) if p.player_index==index+1),
            );
            let fallback = marker.map(|e| e.position.vector()).unwrap_or_else(|| {
                Vec2::new(
                    self.room.collision_bounds.x + 32.,
                    self.room.collision_bounds.y + 32.,
                )
            });
            let position = if let Some(d) = &door {
                self.door_spawn(d, index)?
            } else {
                fallback
            };
            let id = self.actors.len() as u64 + 1;
            self.actors.push(Actor {
                id,
                source_id: format!("player_{}", index + 1),
                properties: Entity_Properties::Player(Player_Properties {
                    player_index: index + 1,
                }),
                body: Body::new(position, Vec3::new(12., 24., 12.), true),
                facing: Vec2::X,
                mounted: None,
                carrying: None,
                held_by: None,
                held_anchor: None,
                release_player: None,
                active: false,
                open: false,
                ram_charge: 0.,
                ram_ready: false,
                move_direction: Vec2::ZERO,
                move_timer: 0.,
                wait_timer: 0.,
                coasting: false,
                health: 100,
                death_timer: 0.,
                mount_time: 0.,
                mount_start: Vec3::ZERO,
                pose: default(),
            });
        }
        self.generation += 1;
        Ok(())
    }
    fn door_spawn(&self, door: &Actor, index: usize) -> Result<Vec2> {
        let bounds = door.body.bounds();
        let center = (bounds.min + bounds.max) / 2.;
        let side = if self.room.interior { -1. } else { 1. };
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
        let t = self.room.grid.tile_size as f32;
        for y in 0..self.room.size.height {
            for x in 0..self.room.size.width {
                candidates.push(Vec2::new((x as f32 + 0.5) * t, (y as f32 + 0.5) * t));
            }
        }
        let solids = self.static_obstacles();
        candidates
            .into_iter()
            .filter(|p| self.room.collision_bounds.contains(*p))
            .filter(|p| {
                let b = Body::new(*p, Vec3::new(12., 24., 12.), true).bounds();
                !self.tile_blocked(b)
                    && !self.room.water_at(*p)
                    && !solids.iter().any(|s| s.intersects(b))
                    && !self.actors.iter().any(|a| {
                        (a.solid()
                            || a.player().is_some()
                            || matches!(a.properties, Entity_Properties::Door(_)))
                            && a.body.bounds().intersects(b)
                    })
                    && !self.room.structures.iter().any(|s| {
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
    pub fn static_obstacles(&self) -> Vec<Aabb> {
        let mut result = Vec::new();
        for s in &self.room.structures {
            let x = s.position.x as f32;
            let z = s.position.y as f32;
            let w = s.size.width as f32;
            let d = s.size.height as f32;
            let opening = w * 0.3;
            let c = x + w / 2.;
            for (min, max) in [
                (Vec3::new(x, 0., z - 0.8), Vec3::new(x + w, 44., z + 0.8)),
                (Vec3::new(x - 0.8, 0., z), Vec3::new(x + 0.8, 44., z + d)),
                (
                    Vec3::new(x + w - 0.8, 0., z),
                    Vec3::new(x + w + 0.8, 44., z + d),
                ),
                (
                    Vec3::new(x, 0., z + d - 1.2),
                    Vec3::new(c - opening, 44., z + d + 1.2),
                ),
                (
                    Vec3::new(c + opening, 0., z + d - 1.2),
                    Vec3::new(x + w, 44., z + d + 1.2),
                ),
                (
                    Vec3::new(c - opening, 35.2, z + d - 1.2),
                    Vec3::new(c + opening, 44., z + d + 1.2),
                ),
                (
                    Vec3::new(x - 4., 44., z - 4.),
                    Vec3::new(x + w + 4., 51., z + d + 4.),
                ),
            ] {
                result.push(Aabb { min, max });
            }
        }
        result
    }
    pub fn tile_blocked(&self, b: Aabb) -> bool {
        if b.max.y <= -32. {
            return false;
        }
        let t = self.room.grid.tile_size as f32;
        for y in (b.min.z / t).floor() as i32..=((b.max.z - 0.001) / t).floor() as i32 {
            for x in (b.min.x / t).floor() as i32..=((b.max.x - 0.001) / t).floor() as i32 {
                if x < 0
                    || y < 0
                    || x as usize >= self.room.size.width
                    || y as usize >= self.room.size.height
                {
                    return true;
                }
                let i = y as usize * self.room.size.width + x as usize;
                if self.room.layers.collision.get(i) == Some(&1)
                    || self.room.interior && self.room.layers.base[i] == 0
                {
                    return true;
                }
            }
        }
        false
    }
    fn obstacles(&self, index: usize) -> Vec<Aabb> {
        let mut obstacles = self.static_obstacles();
        obstacles.extend(
            self.actors
                .iter()
                .enumerate()
                .filter(|(i, a)| {
                    *i != index && a.solid() && a.release_player != Some(self.actors[index].id)
                })
                .map(|(_, a)| a.body.bounds()),
        );
        obstacles
    }
    fn blocked(&self, b: Aabb, obstacles: &[Aabb]) -> bool {
        self.tile_blocked(b) || obstacles.iter().any(|o| b.intersects(*o))
    }
    fn interact(&mut self, player: usize) {
        if let Some(mount) = self.actors[player].mounted {
            if let Some(animal) = self.actors.iter().position(|a| a.id == mount) {
                let mut body = self.actors[player].body.clone();
                let direction = self.actors[animal].facing;
                let right = Vec2::new(direction.y, -direction.x);
                let obstacles = self.obstacles(player);
                for side in [right, -right, -direction, direction] {
                    body.position = self.actors[animal].body.position + side * 30.;
                    body.height = self.actors[animal].body.height + 12.;
                    if !self.blocked(body.bounds(), &obstacles) {
                        body.velocity = self.actors[animal].body.velocity;
                        body.vertical_velocity = 160.;
                        body.grounded = false;
                        self.actors[player].body = body;
                        self.actors[player].mounted = None;
                        self.actors[animal].mounted = None;
                        self.actors[animal].coasting = true;
                        break;
                    }
                }
            }
            return;
        }
        if let Some(item) = self.actors[player].carrying {
            if let Some(index) = self.actors.iter().position(|a| a.id == item) {
                let mut body = self.actors[index].body.clone();
                // Release from the last evaluated hand pose, as in the original renderer.
                let anchor = self.actors[index].held_anchor.unwrap_or(Vec3::new(
                    self.actors[player].body.position.x + self.actors[player].facing.x * 8.,
                    self.actors[player].body.height + 28.,
                    self.actors[player].body.position.y + self.actors[player].facing.y * 8.,
                ));
                body.position = Vec2::new(anchor.x, anchor.z);
                body.height = anchor.y;
                if !self.blocked(body.bounds(), &self.obstacles(index)) {
                    body.velocity =
                        self.actors[player].body.velocity + self.actors[player].facing * 45.;
                    body.vertical_velocity = 15.;
                    body.grounded = false;
                    self.actors[index].body = body;
                    self.actors[index].held_by = None;
                    self.actors[index].held_anchor = None;
                    self.actors[index].release_player = Some(self.actors[player].id);
                    self.actors[player].carrying = None;
                }
            }
            return;
        }
        let pos = self.actors[player].body.position;
        if self.actors.iter().any(|a| {
            matches!(a.properties, Entity_Properties::Npc(_))
                && a.body.position.distance(pos) <= 24.
        }) {
            self.dialog = Some(0);
            self.dialog_characters = 0.;
            return;
        }
        let nearest = self
            .actors
            .iter()
            .enumerate()
            .filter(|(_, a)| {
                matches!(
                    a.kind(),
                    Some(Character_Kind::Horse | Character_Kind::Bison | Character_Kind::Turtle)
                ) && a.mounted.is_none()
                    && a.health > 0
                    && (a.body.height - self.actors[player].body.height).abs() < 6.
                    && (a.body.grounded || a.body.swimming)
            })
            .filter(|(_, a)| a.body.position.distance(pos) <= 40.)
            .min_by(|(_, a), (_, b)| {
                a.body
                    .position
                    .distance_squared(pos)
                    .total_cmp(&b.body.position.distance_squared(pos))
            })
            .map(|(i, _)| i);
        if let Some(animal) = nearest {
            if self.actors[player].body.grounded || self.actors[player].body.swimming {
                self.actors[player].mounted = Some(self.actors[animal].id);
                self.actors[animal].mounted = Some(self.actors[player].id);
                self.actors[player].mount_time = 0.;
                self.actors[player].mount_start =
                    Vec3::new(pos.x, self.actors[player].body.height, pos.y);
            }
        } else if let Some(item) = self.actors.iter().position(|a| {
            matches!(a.properties, Entity_Properties::Holdable(_))
                && a.held_by.is_none()
                && a.body.position.distance(pos) <= 24.
                && (a.body.height - self.actors[player].body.height).abs() <= 24.
        }) {
            self.actors[item].held_by = Some(self.actors[player].id);
            self.actors[player].carrying = Some(self.actors[item].id);
        }
    }
    fn animal_movement(actor: &mut Actor, direction: Vec2, mut profile: Movement_Profile, dt: f32) {
        let kind = actor.kind().unwrap_or(Character_Kind::Human);
        if actor.body.swimming && kind != Character_Kind::Turtle {
            profile.max_speed = profile.max_speed.min(60.);
        }
        if !actor.body.swimming && kind == Character_Kind::Turtle {
            profile.max_speed = profile.max_speed.min(50.);
        }
        let charging = actor.ram_ready && actor.mounted.is_some();
        if charging {
            profile.max_speed = 180.;
            profile.acceleration = 75.;
        }
        let mut magnitude = direction.length().min(1.);
        if magnitude > 0. {
            let angle = actor.facing.x.atan2(actor.facing.y);
            let target = direction.x.atan2(direction.y);
            let delta = (target - angle).sin().atan2((target - angle).cos());
            let turn = if charging {
                1.1
            } else if actor.mounted.is_some() {
                2.8
            } else {
                1.5
            };
            let angle = angle + delta.clamp(-turn * dt, turn * dt);
            actor.facing = Vec2::new(angle.sin(), angle.cos());
            magnitude *= delta.cos().max(0.25);
        }
        let speed = accelerate(
            Vec2::new(actor.body.velocity.length(), 0.),
            Vec2::new(magnitude, 0.),
            profile,
            dt,
        )
        .x;
        actor.body.velocity = actor.facing * speed;
    }
    fn update_motion(&mut self, inputs: [Player_Input; 2], dt: f32) {
        for i in 0..self.actors.len() {
            if let Some(player) = self.actors[i].player() {
                if inputs[player].interact && self.actors[i].mount_time >= 0.4 {
                    self.interact(i);
                } else if inputs[player].interact && self.actors[i].mounted.is_none() {
                    self.interact(i);
                }
                let direction = camera_relative(inputs[player].movement);
                if let Some(mount) = self.actors[i].mounted {
                    self.actors[i].mount_time += dt;
                    if self.actors[i].mount_time < 0.4 {
                        continue;
                    }
                    if let Some(index) = self.actors.iter().position(|a| a.id == mount) {
                        let kind = self.actors[index].kind().unwrap();
                        let mut profile = RIDING_PROFILE;
                        match kind {
                            Character_Kind::Horse => profile.max_speed = 200.,
                            Character_Kind::Bison => {
                                profile.max_speed = 140.;
                                profile.acceleration = 110.;
                            }
                            Character_Kind::Turtle => profile.max_speed = 120.,
                            _ => {}
                        }
                        Self::animal_movement(&mut self.actors[index], direction, profile, dt);
                        if inputs[player].jump
                            && kind != Character_Kind::Turtle
                            && !self.actors[index].ram_ready
                        {
                            self.actors[index]
                                .body
                                .jump(if kind == Character_Kind::Bison {
                                    176.
                                } else {
                                    220.
                                });
                        }
                    }
                } else {
                    let mut profile = PLAYER_PROFILE;
                    if self.actors[i].body.swimming {
                        profile.max_speed = 60.;
                    }
                    self.actors[i].body.velocity =
                        accelerate(self.actors[i].body.velocity, direction, profile, dt);
                    if self.actors[i].body.velocity.length_squared() > 0.01 {
                        self.actors[i].facing = self.actors[i].body.velocity.normalize();
                    }
                    if inputs[player].jump {
                        self.actors[i].body.jump(JUMP_SPEED);
                    }
                }
            }
        }
        for i in 0..self.actors.len() {
            if self.actors[i].kind().is_none()
                && !matches!(self.actors[i].properties, Entity_Properties::Npc(_))
            {
                continue;
            }
            if self.actors[i].mounted.is_some() {
                continue;
            }
            if self.actors[i].coasting {
                Self::animal_movement(&mut self.actors[i], Vec2::ZERO, RIDING_PROFILE, dt);
                if self.actors[i].body.velocity == Vec2::ZERO {
                    self.actors[i].coasting = false;
                    self.actors[i].wait_timer = 0.5;
                }
                continue;
            }
            self.actors[i].move_timer -= dt;
            self.actors[i].wait_timer = (self.actors[i].wait_timer - dt).max(0.);
            if self.actors[i].move_timer <= 0. {
                self.actors[i].move_direction = Vec2::new(
                    self.rng.random_range(-1.0..1.),
                    self.rng.random_range(-1.0..1.),
                );
                self.actors[i].move_timer = self.rng.random_range(1.0..3.);
                if self.rng.random::<f32>() < 0.25 {
                    self.actors[i].wait_timer = self.rng.random_range(0.5..1.5);
                }
            }
            let mut direction = if self.actors[i].wait_timer > 0. {
                Vec2::ZERO
            } else {
                self.actors[i].move_direction
            };
            if self.actors[i].kind().is_some_and(|k| k.mountable()) {
                let wants_water = self.actors[i].kind() == Some(Character_Kind::Turtle);
                let start = self.actors[i].body.position;
                let obstacles = self.obstacles(i);
                let ahead = 24. + self.actors[i].body.velocity.length() / 1.5;
                let clear = |side: Vec2| {
                    let mut body = self.actors[i].body.clone();
                    body.position = start + side * 18.;
                    body.height += 6.;
                    !self.blocked(body.bounds(), &obstacles)
                        && (1..=(ahead / 4.).ceil() as i32).all(|s| {
                            self.room.water_at(start + side * s as f32 * 4.) == wants_water
                                || self.room.water_at(start) != wants_water
                        })
                };
                if !clear(direction.normalize_or_zero()) || !clear(self.actors[i].facing) {
                    let right = Vec2::new(self.actors[i].facing.y, -self.actors[i].facing.x);
                    direction = [right, -right, -self.actors[i].facing]
                        .into_iter()
                        .find(|side| clear(*side))
                        .unwrap_or_default();
                    self.actors[i].move_direction = direction;
                    self.actors[i].move_timer = 1.;
                }
                Self::animal_movement(
                    &mut self.actors[i],
                    direction,
                    Movement_Profile {
                        min_speed: 20.,
                        max_speed: 50.,
                        ..RIDING_PROFILE
                    },
                    dt,
                );
            } else {
                self.actors[i].body.velocity = direction * 30.;
                if direction != Vec2::ZERO {
                    self.actors[i].facing = direction.normalize();
                }
            }
        }
    }
    fn sync_relationships(&mut self) {
        for i in 0..self.actors.len() {
            if let Some(id) = self.actors[i]
                .mounted
                .filter(|_| self.actors[i].player().is_some())
            {
                if let Some(animal) = self.actors.iter().find(|a| a.id == id).cloned() {
                    let t = (self.actors[i].mount_time / 0.4).min(1.);
                    let end = Vec3::new(
                        animal.body.position.x,
                        animal.body.height + animal.body.size.y * 0.75,
                        animal.body.position.y,
                    );
                    let p =
                        self.actors[i].mount_start.lerp(end, t) + Vec3::Y * (64. * t * (1. - t));
                    self.actors[i].body.position = Vec2::new(p.x, p.z);
                    self.actors[i].body.height = p.y;
                    self.actors[i].body.velocity = animal.body.velocity;
                    self.actors[i].body.grounded = false;
                    self.actors[i].facing = animal.facing;
                }
            }
            if let Some(id) = self.actors[i].held_by {
                if let Some(player) = self.actors.iter().find(|a| a.id == id).cloned() {
                    self.actors[i].body.position = player.body.position;
                    self.actors[i].body.height = player.body.height + 28.;
                    self.actors[i].body.velocity = player.body.velocity;
                    self.actors[i].body.grounded = false;
                } else {
                    self.actors[i].held_by = None;
                }
            }
        }
    }
    fn move_body(&mut self, i: usize, dt: f32) {
        let obstacles = self.obstacles(i);
        let mut body = self.actors[i].body.clone();
        for axis in 0..2 {
            let mut next = body.clone();
            next.position[axis] += body.velocity[axis] * dt;
            if !self.blocked(next.bounds(), &obstacles) {
                body.position = next.position;
            } else if body.grounded && body.vertical_velocity <= 0. {
                let top = obstacles
                    .iter()
                    .filter(|o| o.intersects(next.bounds()))
                    .map(|o| o.max.y - body.offset.y)
                    .fold(body.height, f32::max);
                next.height = top;
                let mut clearance = body.clone();
                clearance.height = top;
                if top - body.height <= 6.
                    && !self.blocked(next.bounds(), &obstacles)
                    && !self.blocked(clearance.bounds(), &obstacles)
                {
                    body = next;
                }
            }
        }
        let previous = body.bounds();
        body.vertical_velocity -= GRAVITY * dt;
        body.swimming = false;
        let wet = self.room.water_at(body.position);
        if wet {
            let bottom = body.height + body.offset.y;
            let submerged = (-1.5 - bottom).clamp(0., body.size.y);
            if submerged > 0. && bottom + body.size.y > -32. {
                body.swimming = true;
                let draft = 8f32.min(body.size.y * 0.55).max(0.1);
                body.vertical_velocity = (body.vertical_velocity
                    + GRAVITY * submerged / draft * dt)
                    / (1. + 10. * (submerged / draft).min(1.) * dt);
            }
        }
        body.height += body.vertical_velocity * dt;
        let next = body.bounds();
        body.grounded = false;
        if body.vertical_velocity <= 0. {
            let mut floor: f32 = if wet { -32. } else { 0. };
            for obstacle in &obstacles {
                if next.horizontal(*obstacle)
                    && previous.min.y >= obstacle.max.y - 0.01
                    && next.min.y <= obstacle.max.y
                {
                    floor = floor.max(obstacle.max.y);
                }
            }
            if next.min.y <= floor {
                if body.vertical_velocity < -120. {
                    self.effects
                        .push((Vec3::new(body.position.x, floor, body.position.y), false));
                }
                body.height = floor - body.offset.y;
                body.vertical_velocity = 0.;
                body.grounded = true;
            }
        } else {
            for obstacle in &obstacles {
                if next.horizontal(*obstacle)
                    && previous.max.y <= obstacle.min.y + 0.01
                    && next.max.y >= obstacle.min.y
                {
                    body.height = body
                        .height
                        .min(obstacle.min.y - body.offset.y - body.size.y);
                    body.vertical_velocity = 0.;
                }
            }
        }
        if matches!(self.actors[i].properties, Entity_Properties::Holdable(_))
            && (body.grounded || body.swimming)
        {
            let speed = body.velocity.length();
            if speed > 0. {
                body.velocity *=
                    ((speed - if body.grounded { 180. } else { 72. } * dt).max(0.)) / speed;
            }
        }
        let bounds = self.room.collision_bounds;
        body.position.x = body.position.x.clamp(
            bounds.x - body.offset.x,
            bounds.x + bounds.width - body.offset.x - body.size.x,
        );
        body.position.y = body.position.y.clamp(
            bounds.y - body.offset.z,
            bounds.y + bounds.height - body.offset.z - body.size.z,
        );
        if let Some(id) = self.actors[i].release_player {
            if !self
                .actors
                .iter()
                .any(|p| p.id == id && p.body.bounds().horizontal(body.bounds()))
            {
                self.actors[i].release_player = None;
            }
        }
        self.actors[i].body = body;
    }
    fn update_ram(&mut self, dt: f32) {
        for i in 0..self.actors.len() {
            if self.actors[i].kind() != Some(Character_Kind::Bison) {
                continue;
            }
            let threshold = if self.actors[i].ram_ready {
                105.
            } else if self.actors[i].ram_charge > 0. {
                126.
            } else {
                133.
            };
            if self.actors[i].mounted.is_none()
                || !self.actors[i].body.grounded
                || self.actors[i].body.velocity.length() < threshold
            {
                self.actors[i].ram_charge = 0.;
                self.actors[i].ram_ready = false;
                continue;
            }
            self.actors[i].ram_charge += dt;
            self.actors[i].ram_ready = self.actors[i].ram_charge >= 0.75;
            if !self.actors[i].ram_ready {
                continue;
            }
            let body = self.actors[i].body.bounds();
            let velocity = self.actors[i].body.velocity;
            let solids = self.obstacles(i);
            let nearest = solids
                .iter()
                .filter_map(|wall| {
                    ram_contact(body, *wall, velocity, dt).map(|(time, speed)| (*wall, time, speed))
                })
                .min_by(|a, b| a.1.total_cmp(&b.1));
            if let Some((wall, _, _speed)) = nearest.filter(|v| v.2 >= 100.) {
                if let Some(gate) = self.actors.iter().position(|a| {
                    matches!(&a.properties,Entity_Properties::Gate(g) if g.breakable)
                        && !a.open
                        && a.body.bounds() == wall
                }) {
                    self.actors[gate].open = true;
                    self.effects.push(((wall.min + wall.max) * 0.5, true));
                }
            }
        }
    }
    fn puzzles(&mut self) {
        let mut triggers = BTreeMap::new();
        for i in 0..self.actors.len() {
            if let Entity_Properties::Pressure_Plate(p) = self.actors[i].properties.clone() {
                let plate = self.actors[i].body.bounds();
                let weight = self
                    .actors
                    .iter()
                    .filter(|a| {
                        a.id != self.actors[i].id
                            && a.body.grounded
                            && a.held_by.is_none()
                            && a.body.bounds().horizontal(plate)
                            && (a.body.bounds().min.y - plate.max.y).abs() <= 0.02
                    })
                    .count();
                let active = weight >= if p.requires_both { 2 } else { 1 };
                if active != self.actors[i].active {
                    self.effects.push(((plate.min + plate.max) * 0.5, false));
                }
                self.actors[i].active = active;
                triggers.insert(p.trigger_id, active);
            }
        }
        for i in 0..self.actors.len() {
            if let Entity_Properties::Gate(g) = self.actors[i].properties.clone() {
                if g.breakable {
                    continue;
                }
                let active = g
                    .required_trigger_ids
                    .iter()
                    .all(|id| triggers.get(id) == Some(&true));
                let open = if g.inverted { !active } else { active };
                if open {
                    self.actors[i].open = true;
                } else if self.actors[i].open {
                    self.close_gate(i);
                }
            }
        }
    }
    fn close_gate(&mut self, index: usize) {
        let before = self.actors.clone();
        self.actors[index].open = false;
        let wall = self.actors[index].body.bounds();
        for i in 0..self.actors.len() {
            if !self.actors[i].movable()
                || self.actors[i].held_by.is_some()
                || self.actors[i].player().is_some() && self.actors[i].mounted.is_some()
            {
                continue;
            }
            let b = self.actors[i].body.bounds();
            if !b.intersects(wall) {
                continue;
            }
            let mut options = vec![
                Vec3::new(wall.min.x - b.max.x - 0.01, 0., 0.),
                Vec3::new(wall.max.x - b.min.x + 0.01, 0., 0.),
                Vec3::new(0., 0., wall.min.z - b.max.z - 0.01),
                Vec3::new(0., 0., wall.max.z - b.min.z + 0.01),
            ];
            options.sort_by(|a, b| a.length_squared().total_cmp(&b.length_squared()));
            options.push(Vec3::new(0., wall.max.y - b.min.y + 0.01, 0.));
            let obstacles = self.obstacles(i);
            let offset = options.into_iter().find(|o| {
                let candidate = b.shifted(*o);
                self.room
                    .collision_bounds
                    .contains(Vec2::new(candidate.min.x, candidate.min.z))
                    && self
                        .room
                        .collision_bounds
                        .contains(Vec2::new(candidate.max.x, candidate.max.z))
                    && !self.blocked(candidate, &obstacles)
            });
            if let Some(o) = offset {
                self.actors[i].body.position += Vec2::new(o.x, o.z);
                self.actors[i].body.height += o.y;
                self.actors[i].body.velocity = Vec2::ZERO;
                self.actors[i].body.vertical_velocity = 0.;
                self.actors[i].body.grounded = false;
            } else {
                self.actors = before;
                return;
            }
        }
    }
    pub fn step(&mut self, inputs: [Player_Input; 2], dt: f32) -> Result<()> {
        let dt = dt.clamp(0., 0.1);
        self.elapsed += dt;
        self.frame += 1;
        self.effects.clear();
        if let Some(page) = self.dialog {
            let text = DIALOG[page];
            self.dialog_characters += dt / 0.025;
            if inputs.iter().any(|i| i.interact) {
                if self.dialog_characters < (text.chars().count() as f32) {
                    self.dialog_characters = text.chars().count() as f32;
                } else if page + 1 == DIALOG.len() {
                    self.dialog = None;
                } else {
                    self.dialog = Some(page + 1);
                    self.dialog_characters = 0.;
                }
            }
            return Ok(());
        }
        if let Some(mut transition) = self.transition.take() {
            transition.elapsed += dt;
            if transition.elapsed >= 0.3 && !transition.loaded {
                let next = self.registry.get(&transition.room)?.room.clone();
                self.load_room(next, &transition.door)?;
                transition.loaded = true;
            }
            if transition.elapsed < 0.6 {
                self.transition = Some(transition);
            }
            return Ok(());
        }
        self.update_motion(inputs, dt);
        for _ in 0..2 {
            self.update_ram(dt / 2.);
            for crates in [true, false] {
                for i in 0..self.actors.len() {
                    if !self.actors[i].movable()
                        || matches!(self.actors[i].properties, Entity_Properties::Holdable(_))
                            != crates
                        || self.actors[i].held_by.is_some()
                        || self.actors[i].player().is_some() && self.actors[i].mounted.is_some()
                    {
                        continue;
                    }
                    self.move_body(i, dt / 2.);
                }
            }
        }
        self.sync_relationships();
        self.puzzles();
        self.sync_relationships();
        let contact = self
            .actors
            .iter()
            .filter(|p| p.player().is_some())
            .find_map(|p| {
                self.actors.iter().find(|d| {
                    matches!(d.properties, Entity_Properties::Door(_))
                        && d.body.bounds().intersects(p.body.bounds())
                })
            });
        if let Some(door) = contact {
            if self.doors_enabled {
                if let Entity_Properties::Door(d) = &door.properties {
                    self.transition = Some(Transition {
                        room: d.target_room_id.clone(),
                        door: d.target_door_id.clone(),
                        elapsed: 0.,
                        loaded: false,
                    });
                    self.doors_enabled = false;
                }
            }
        } else {
            self.doors_enabled = true;
        }
        for a in &mut self.actors {
            if a.health <= 0 {
                a.death_timer += dt;
            }
        }
        let steering_by_actor: std::collections::HashMap<_, _> = self
            .actors
            .iter()
            .filter_map(|actor| {
                actor.player().map(|p| {
                    (
                        actor.mounted.unwrap_or(actor.id),
                        camera_relative(inputs[p].movement),
                    )
                })
            })
            .collect();
        for actor in &mut self.actors {
            let animal = crate::visuals::animal_axis(actor.kind()) != 0.;
            let bison = actor.kind() == Some(Character_Kind::Bison);
            let steering = steering_by_actor
                .get(&actor.id)
                .copied()
                .unwrap_or(actor.move_direction);
            actor.pose.advance(
                crate::visuals::Pose_Input {
                    velocity: actor.body.velocity,
                    facing: actor.facing,
                    steering,
                    grounded: actor.body.grounded,
                    swimming: actor.body.swimming,
                    animal,
                    bison,
                    ram: actor.ram_ready,
                },
                dt,
            );
        }
        self.surfaces.advance(&self.actors, &self.room, dt);
        self.actors
            .retain(|a| a.player().is_some() || a.health > 0 || a.death_timer < 26. / 60.);
        Ok(())
    }
    pub fn observation(&self) -> Value {
        let body = |a: &Actor| json!({"ram_ready":a.ram_ready,"ram":a.pose.ram,"head_turn":a.pose.head_turn,"swimming":a.body.swimming,"stride":a.pose.phase,"lean":a.pose.lean,"id":a.id,"position":{"x":a.body.position.x,"y":a.body.position.y},"velocity":{"x":a.body.velocity.x,"y":a.body.velocity.y},"height":a.body.height,"grounded":a.body.grounded});
        json!({"visual":{"water_contacts":self.surfaces.water.len(),"wakes":self.surfaces.wakes.len(),"grass_contacts":self.surfaces.grass.len(),"grass_trails":self.surfaces.grass_trails.len()},"frame":self.frame,"seed":self.seed,"scene":"Gameplay","room":self.room.id,"entity_count":self.actors.len(),"players":self.actors.iter().filter_map(|a|a.player().map(|i|json!({"body":body(a),"player":format!("Player_{}",i+1),"mounted":a.mounted.unwrap_or(0),"carrying":a.carrying.unwrap_or(0)}))).collect::<Vec<_>>(),"holdables":self.actors.iter().filter(|a|matches!(a.properties,Entity_Properties::Holdable(_))).map(|a|json!({"body":body(a),"held_anchor":a.held_anchor.map(|p|json!({"x":p.x,"y":p.y,"z":p.z}))})).collect::<Vec<_>>(),"enemies":self.actors.iter().filter(|a|a.kind().is_some()).map(|a|json!({"body":body(a),"move_direction":{"x":a.move_direction.x,"y":a.move_direction.y},"move_timer":a.move_timer,"wait_timer":a.wait_timer})).collect::<Vec<_>>()})
    }
}
pub const DIALOG: [&str; 3] = [
    "Hello there, traveler!",
    "Welcome to our peaceful village.",
    "Feel free to explore around.",
];
pub fn ram_contact(body: Aabb, wall: Aabb, velocity: Vec2, dt: f32) -> Option<(f32, f32)> {
    if body.max.y <= wall.min.y || body.min.y >= wall.max.y || body.intersects(wall) {
        return None;
    }
    let (mut entry, mut leave, mut impact) = (-1e9f32, 1e9f32, 0.);
    for axis in [0, 2] {
        let speed = velocity[if axis == 0 { 0 } else { 1 }];
        if speed.abs() < 0.0001 {
            if body.max[axis] <= wall.min[axis] || body.min[axis] >= wall.max[axis] {
                return None;
            }
            continue;
        }
        let a = (wall.min[axis] - body.max[axis]) / speed;
        let b = (wall.max[axis] - body.min[axis]) / speed;
        let near = a.min(b);
        if near > entry {
            entry = near;
            impact = speed.abs();
        }
        leave = leave.min(a.max(b));
    }
    (entry >= 0. && entry <= dt && entry <= leave).then_some((entry, impact))
}
#[cfg(test)]
mod tests {
    use super::*;
    fn game() -> Game_World {
        Game_World::new(Room_Registry::load(std::path::Path::new("res")).unwrap()).unwrap()
    }
    #[test]
    fn seeded_reset_replays_both_players() {
        let mut world = game();
        world.reset("demo", 2, 84).unwrap();
        let initial = world.observation();
        let input = [
            Player_Input {
                movement: Vec2::Y,
                ..default()
            },
            Player_Input {
                movement: Vec2::Y * 0.5,
                ..default()
            },
        ];
        for _ in 0..30 {
            world.step(input, STEP).unwrap();
        }
        let moved = world.observation();
        assert_eq!(world.frame, 30);
        assert_ne!(
            moved["players"][0]["body"]["position"],
            initial["players"][0]["body"]["position"]
        );
        assert_ne!(
            moved["players"][1]["body"]["position"],
            initial["players"][1]["body"]["position"]
        );
        world.reset("demo", 2, 84).unwrap();
        assert_eq!(world.observation(), initial);
        for _ in 0..30 {
            world.step(input, STEP).unwrap();
        }
        assert_eq!(world.observation(), moved);
    }
    #[test]
    fn invalid_reset_does_not_mutate_world() {
        let mut world = game();
        world.reset("demo", 1, 42).unwrap();
        let before = world.observation();
        assert!(world.reset("missing", 2, 4).is_err());
        assert_eq!(before, world.observation());
        assert!(world.reset("demo", 3, 4).is_err());
        assert_eq!(before, world.observation());
    }
    #[test]
    fn analog_movement_and_braking() {
        let full = accelerate(Vec2::ZERO, Vec2::Y, PLAYER_PROFILE, 1.);
        let half = accelerate(Vec2::ZERO, Vec2::Y * 0.5, PLAYER_PROFILE, 1.);
        assert_eq!(full.length(), 80.);
        assert_eq!(half.length(), 50.);
        assert_eq!(accelerate(full, Vec2::ZERO, PLAYER_PROFILE, 1.), Vec2::ZERO);
    }
    #[test]
    fn jump_and_buoyancy() {
        let mut world = game();
        world.reset("demo", 1, 42).unwrap();
        let i = world
            .actors
            .iter()
            .position(|a| a.player() == Some(0))
            .unwrap();
        world.actors[i].body.jump(220.);
        world.move_body(i, STEP);
        assert!(world.actors[i].body.height > 0.);
        for _ in 0..120 {
            world.move_body(i, STEP);
        }
        assert!(world.actors[i].body.grounded);
        let water = world
            .room
            .layers
            .base
            .iter()
            .position(|t| *t == 500)
            .unwrap();
        let tile = world.room.grid.tile_size as f32;
        world.actors[i].body.position = Vec2::new(
            (water % world.room.size.width) as f32 * tile + tile / 2.,
            (water / world.room.size.width) as f32 * tile + tile / 2.,
        );
        world.actors[i].body.height = -8.;
        for _ in 0..120 {
            world.move_body(i, STEP);
        }
        assert!(world.actors[i].body.swimming);
        assert!(world.actors[i].body.height > -32.);
    }
    #[test]
    fn ram_requires_speed_into_face() {
        let body = Aabb {
            min: Vec3::ZERO,
            max: Vec3::splat(1.),
        };
        let wall = Aabb {
            min: Vec3::new(2., 0., 0.),
            max: Vec3::new(3., 1., 1.),
        };
        assert_eq!(
            ram_contact(body, wall, Vec2::new(100., 0.), 0.02),
            Some((0.01, 100.))
        );
        assert!(ram_contact(body, wall, Vec2::Y * 200., 0.1).is_none());
    }
}

#[cfg(test)]
mod interaction_tests {
    use super::*;
    fn game() -> Game_World {
        let mut game =
            Game_World::new(Room_Registry::load(std::path::Path::new("res")).unwrap()).unwrap();
        game.reset("demo", 2, 42).unwrap();
        game
    }
    #[test]
    fn crate_and_player_weight_open_linked_gate() {
        let mut game = game();
        let plates: Vec<_> = game
            .actors
            .iter()
            .enumerate()
            .filter(|(_, a)| matches!(a.properties, Entity_Properties::Pressure_Plate(_)))
            .map(|(i, a)| (i, a.body.position, a.body.size.y))
            .collect();
        let crate_index = game
            .actors
            .iter()
            .position(|a| matches!(a.properties, Entity_Properties::Holdable(_)))
            .unwrap();
        let player = game
            .actors
            .iter()
            .position(|a| a.player() == Some(0))
            .unwrap();
        game.actors[crate_index].body.position = plates[0].1;
        game.actors[crate_index].body.height = plates[0].2;
        game.actors[player].body.position = plates[1].1;
        game.actors[player].body.height = plates[1].2;
        game.puzzles();
        assert!(game.actors[plates[0].0].active);
        assert!(game.actors[plates[1].0].active);
        let gate = game
            .actors
            .iter()
            .position(|a| matches!(&a.properties,Entity_Properties::Gate(g) if !g.breakable))
            .unwrap();
        assert!(game.actors[gate].open);
        game.actors[crate_index].held_by = Some(game.actors[player].id);
        game.puzzles();
        assert!(!game.actors[plates[0].0].active);
        assert!(!game.actors[gate].open);
    }
    #[test]
    fn carry_drop_and_contact_exemption() {
        let mut game = game();
        let player = game
            .actors
            .iter()
            .position(|a| a.player() == Some(0))
            .unwrap();
        let item = game
            .actors
            .iter()
            .position(|a| matches!(a.properties, Entity_Properties::Holdable(_)))
            .unwrap();
        game.actors[player].body.position = game.actors[item].body.position + Vec2::X * 15.;
        game.interact(player);
        assert_eq!(game.actors[player].carrying, Some(game.actors[item].id));
        assert_eq!(game.actors[item].held_by, Some(game.actors[player].id));
        game.sync_relationships();
        game.interact(player);
        assert!(game.actors[player].carrying.is_none());
        assert!(game.actors[item].held_by.is_none());
        assert_eq!(
            game.actors[item].release_player,
            Some(game.actors[player].id)
        );
        game.actors[item].body.position += Vec2::X * 100.;
        game.move_body(item, STEP);
        assert!(game.actors[item].release_player.is_none());
    }
    #[test]
    fn riders_follow_mount_without_bearing_ground_weight() {
        let mut game = game();
        let player = game
            .actors
            .iter()
            .position(|a| a.player() == Some(0))
            .unwrap();
        let animal = game
            .actors
            .iter()
            .position(|a| a.kind() == Some(Character_Kind::Bison))
            .unwrap();
        game.actors[player].body.position = game.actors[animal].body.position + Vec2::X * 30.;
        game.interact(player);
        assert_eq!(game.actors[player].mounted, Some(game.actors[animal].id));
        for _ in 0..30 {
            game.step(default(), STEP).unwrap();
        }
        assert!(!game.actors[player].body.grounded);
        assert!(game.actors[player].body.height > game.actors[animal].body.height);
    }
    #[test]
    fn failed_spawn_does_not_publish_partial_reset() {
        let mut game = game();
        let before = game.observation();
        game.registry
            .rooms
            .get_mut("demo")
            .unwrap()
            .room
            .layers
            .collision
            .fill(1);
        assert!(game.reset("demo", 1, 7).is_err());
        assert_eq!(game.observation(), before);
    }
}
