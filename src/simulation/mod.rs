use crate::content::*;
use anyhow::Result;
use bevy::prelude::*;
use rand::{Rng, SeedableRng};
use rand_chacha::ChaCha8Rng;
use serde_json::{Value, json};
use std::{
    collections::BTreeMap,
    ops::{Deref, DerefMut},
};

mod ecs;
pub(crate) use ecs::Impact;
pub use ecs::{Game_Access, Game_View, Simulation_Plugin};

pub const INITIAL_ROOM: &str = "demo";
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
#[derive(Component, Clone, Debug)]
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
mod components;
pub use components::*;

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
fn steer_air(velocity: Vec2, direction: Vec2, dt: f32) -> Vec2 {
    let speed = velocity.length();
    if speed == 0. || direction == Vec2::ZERO {
        return velocity;
    }
    let angle = velocity.x.atan2(velocity.y);
    let target = direction.x.atan2(direction.y);
    let delta = (target - angle).sin().atan2((target - angle).cos());
    let turn = PLAYER_PROFILE.acceleration / speed * direction.length().min(1.) * dt.max(0.);
    let angle = angle + delta.clamp(-turn, turn);
    Vec2::new(angle.sin(), angle.cos()) * speed
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
pub struct Game_State {
    pub registry: Room_Registry,
    pub room: Room,
    pub frame: u64,
    pub seed: u64,
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
#[derive(Clone)]
pub struct Game_World<'w, S = Box<Game_State>> {
    pub(crate) state: S,
    pub actors: Vec<Actor<'w>>,
}
impl<S: Deref<Target = Game_State>> Deref for Game_World<'_, S> {
    type Target = Game_State;
    fn deref(&self) -> &Self::Target {
        &self.state
    }
}
impl<S: DerefMut<Target = Game_State>> DerefMut for Game_World<'_, S> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.state
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

mod collision;
mod interactions;
mod movement;
mod rooms;
#[cfg(test)]
mod tests;
mod tick;
