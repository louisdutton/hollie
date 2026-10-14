use crate::{content::*, simulation::Actor};
use bevy::prelude::*;
use std::collections::HashMap;

#[derive(Clone, Debug, Default)]
pub struct Motion_Pose {
    pub phase: f32,
    pub lean: f32,
    pub head_turn: f32,
    pub ram: f32,
    previous_velocity: Vec2,
}
#[derive(Default)]
pub struct Pose_Input {
    pub velocity: Vec2,
    pub facing: Vec2,
    pub steering: Vec2,
    pub grounded: bool,
    pub swimming: bool,
    pub animal: bool,
    pub bison: bool,
    pub ram: bool,
}
impl Motion_Pose {
    pub fn advance(&mut self, input: Pose_Input, dt: f32) {
        let Pose_Input {
            velocity,
            facing,
            steering,
            grounded,
            swimming,
            animal,
            bison,
            ram,
        } = input;
        let speed = velocity.length();
        if grounded || swimming {
            let stride = if animal {
                (25. + 15. * ((speed - 50.) / 110.).clamp(0., 1.)) * if bison { 1.7 } else { 1. }
            } else {
                80. / 1.65
            };
            self.phase = (self.phase + speed / stride * dt).rem_euclid(1.);
        }
        let target = if animal && speed > 0. && dt > 0. {
            let lateral = self.previous_velocity.perp_dot(velocity) / (speed * dt);
            (lateral / 250.).clamp(-1., 1.)
                * ((speed / 200. - 0.35) / 0.65).clamp(0., 1.)
                * 18_f32.to_radians()
        } else if grounded {
            8_f32.to_radians() * (speed / 80.).clamp(0., 1.)
        } else {
            0.
        };
        self.lean += (target - self.lean) * (1. - (-20. * dt).exp());
        let head = if steering.length_squared() > 0. {
            (-facing.perp_dot(steering))
                .atan2(facing.dot(steering))
                .clamp(-35_f32.to_radians(), 35_f32.to_radians())
        } else {
            0.
        };
        self.head_turn += (head - self.head_turn) * (1. - (-16. * dt).exp());
        self.ram += ((ram as u8 as f32) - self.ram) * (1. - (-10. * dt).exp());
        self.previous_velocity = velocity;
    }
    pub fn bison_bob(&self, speed: f32) -> f32 {
        (self.phase * std::f32::consts::TAU).sin().powi(2) * 2.3 * (speed / 140.).clamp(0., 1.)
    }
}
pub fn animal_axis(kind: Option<Character_Kind>) -> f32 {
    if matches!(
        kind,
        Some(
            Character_Kind::Dog
                | Character_Kind::Horse
                | Character_Kind::Bison
                | Character_Kind::Turtle
        )
    ) {
        std::f32::consts::FRAC_PI_2
    } else {
        0.
    }
}
#[derive(Clone, Debug)]
pub struct Imprint {
    pub position: Vec2,
    pub direction: Vec2,
    pub radius: f32,
    pub strength: f32,
    pub age: f32,
}
#[derive(Clone, Debug)]
pub struct Water_Contact {
    pub position: Vec2,
    pub radii: Vec2,
    pub direction: Vec2,
    pub speed: f32,
}
#[derive(Clone, Debug)]
pub struct Wake {
    pub start: Vec2,
    pub end: Vec2,
    pub width: f32,
    pub strength: f32,
    pub age: f32,
}
#[derive(Clone, Debug, Default)]
pub struct Surface_State {
    pub grass: Vec<Imprint>,
    pub grass_trails: Vec<Imprint>,
    pub water: Vec<Water_Contact>,
    pub wakes: Vec<Wake>,
    previous_water: HashMap<u64, Vec2>,
    grass_timer: f32,
}
impl Surface_State {
    pub fn advance(&mut self, actors: &[Actor], room: &Room, dt: f32) {
        self.grass.clear();
        self.water.clear();
        for trail in &mut self.grass_trails {
            trail.age += dt;
        }
        self.grass_trails.retain(|trail| trail.age < 2.6);
        for wake in &mut self.wakes {
            wake.age += dt;
        }
        self.wakes.retain(|wake| wake.age < 1.3);
        self.grass_timer -= dt;
        let record_grass = self.grass_timer <= 0.;
        if record_grass {
            self.grass_timer = 0.1;
        }
        let mut wet_ids = Vec::new();
        for actor in actors {
            if !actor.movable()
                || actor.held_by.is_some()
                || actor.player().is_some() && actor.mounted.is_some()
            {
                continue;
            }
            let bounds = actor.body.bounds();
            let position = (bounds.min + bounds.max) / 2.;
            let center = Vec2::new(position.x, position.z);
            let speed = actor.body.velocity.length();
            let direction = actor.body.velocity.normalize_or(Vec2::Y);
            if bounds.min.y < -1.5 && bounds.max.y > -1.5 && room.water_at(center) {
                wet_ids.push(actor.id);
                let radii = Vec2::new(actor.body.size.x, actor.body.size.z) * 0.5;
                if self.water.len() < 16 {
                    self.water.push(Water_Contact {
                        position: center,
                        radii: radii.max(Vec2::splat(3.)),
                        direction,
                        speed: (speed / 60.).clamp(0., 1.),
                    });
                }
                let previous = self.previous_water.entry(actor.id).or_insert(center);
                let delta = center - *previous;
                let mut distance = delta.length();
                if distance > 40. {
                    *previous = center;
                    continue;
                }
                let width = radii.min_element().clamp(3., 14.);
                let spacing = (width * 0.4).max(2.);
                let travel = delta.normalize_or_zero();
                while distance >= spacing {
                    let end = *previous + travel * spacing;
                    self.wakes.push(Wake {
                        start: *previous,
                        end,
                        width,
                        strength: (speed / 60.).clamp(0.35, 1.),
                        age: 0.,
                    });
                    *previous = end;
                    distance -= spacing;
                }
            } else if bounds.min.y < 8.
                && bounds.max.y > 0.
                && !actor.body.swimming
                && speed > 3.
                && self.grass.len() < 32
            {
                let strength = ((speed - 3.) / 65.).clamp(0., 1.);
                let imprint = Imprint {
                    position: center,
                    direction,
                    radius: actor.body.size.x.max(actor.body.size.z) * 0.5 + 3.,
                    strength: strength
                        * strength
                        * (3. - 2. * strength)
                        * (1. - bounds.min.y.max(0.) / 8.),
                    age: 0.,
                };
                if record_grass {
                    let mut trail = imprint.clone();
                    trail.strength = (speed / 30.).clamp(0., 1.);
                    self.grass_trails.push(trail);
                }
                self.grass.push(imprint);
            }
        }
        self.previous_water.retain(|id, _| wet_ids.contains(id));
        if self.grass_trails.len() > 64 {
            self.grass_trails.drain(..self.grass_trails.len() - 64);
        }
        if self.wakes.len() > 64 {
            self.wakes.drain(..self.wakes.len() - 64);
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::simulation::{Game_World, Player_Input, STEP};
    fn game() -> Game_World {
        let mut g =
            Game_World::new(Room_Registry::load(std::path::Path::new("res")).unwrap()).unwrap();
        g.reset("demo", 1, 42).unwrap();
        g
    }
    #[test]
    fn imported_forward_axes_match_world_facing() {
        for facing in [Vec2::X, Vec2::Y, -Vec2::X, -Vec2::Y] {
            let yaw = facing.x.atan2(facing.y);
            let rotation = Quat::from_rotation_y(yaw + animal_axis(Some(Character_Kind::Horse)));
            let forward = rotation * -Vec3::X;
            assert!(Vec2::new(forward.x, forward.z).abs_diff_eq(facing, 0.00001));
            let forward = Quat::from_rotation_y(yaw) * Vec3::Z;
            assert!(Vec2::new(forward.x, forward.z).abs_diff_eq(facing, 0.00001));
        }
    }
    #[test]
    fn water_contact_wakes_and_reset_are_simulation_owned() {
        let mut g = game();
        let i = g.actors.iter().position(|a| a.player().is_some()).unwrap();
        let tile = g.room.layers.base.iter().position(|t| *t == 500).unwrap();
        let t = g.room.grid.tile_size as f32;
        let p = Vec2::new(
            (tile % g.room.size.width) as f32 * t + t / 2.,
            (tile / g.room.size.width) as f32 * t + t / 2.,
        );
        g.actors[i].body.position = p;
        g.actors[i].body.height = -8.;
        g.surfaces.advance(&g.actors, &g.room, STEP);
        g.actors[i].body.position.x += 6.;
        g.actors[i].body.velocity = Vec2::X * 50.;
        g.surfaces.advance(&g.actors, &g.room, STEP);
        assert!(!g.surfaces.water.is_empty());
        assert!(!g.surfaces.wakes.is_empty());
        g.surfaces.advance(&[], &g.room, 2.);
        assert!(g.surfaces.wakes.is_empty());
        assert!(g.surfaces.water.is_empty());
        g.reset("demo", 1, 42).unwrap();
        assert!(g.surfaces.wakes.is_empty());
    }
    #[test]
    fn grass_footprints_recover_and_airborne_bodies_do_not_flatten_it() {
        let g = game();
        let mut actor = g
            .actors
            .iter()
            .find(|a| a.player().is_some())
            .unwrap()
            .clone();
        actor.body.velocity = Vec2::X * 80.;
        let mut state = Surface_State::default();
        state.advance(std::slice::from_ref(&actor), &g.room, STEP);
        assert_eq!(state.grass.len(), 1);
        assert_eq!(state.grass_trails.len(), 1);
        actor.body.height = 12.;
        state.advance(std::slice::from_ref(&actor), &g.room, 3.);
        assert!(state.grass.is_empty());
        assert!(state.grass_trails.is_empty());
    }
    #[test]
    fn turn_banking_and_head_anticipation_blend_back_to_neutral() {
        let mut pose = Motion_Pose::default();
        pose.advance(
            Pose_Input {
                velocity: Vec2::X * 200.,
                facing: Vec2::X,
                animal: true,
                grounded: true,
                ..default()
            },
            STEP,
        );
        pose.advance(
            Pose_Input {
                velocity: Vec2::new(190., 60.),
                facing: Vec2::X,
                steering: Vec2::Y,
                animal: true,
                grounded: true,
                ..default()
            },
            STEP,
        );
        assert!(pose.lean.abs() > 0.);
        assert!(pose.head_turn.abs() > 0.);
        for _ in 0..120 {
            pose.advance(
                Pose_Input {
                    facing: Vec2::X,
                    animal: true,
                    grounded: true,
                    ..default()
                },
                STEP,
            );
        }
        assert!(pose.lean.abs() < 0.0001);
        assert!(pose.head_turn.abs() < 0.0001);
    }
    #[test]
    fn carried_crate_releases_from_the_evaluated_hands() {
        let mut g = game();
        let p = g.actors.iter().position(|a| a.player().is_some()).unwrap();
        let item = g
            .actors
            .iter()
            .position(|a| matches!(a.properties, Entity_Properties::Holdable(_)))
            .unwrap();
        let id = g.actors[item].id;
        let player_id = g.actors[p].id;
        g.actors[p].carrying = Some(id);
        g.actors[item].held_by = Some(player_id);
        let position = g.actors[p].body.position + Vec2::Y * 20.;
        let anchor = Vec3::new(position.x, 16., position.y);
        g.actors[item].held_anchor = Some(anchor);
        g.step(
            [
                Player_Input {
                    interact: true,
                    ..default()
                },
                default(),
            ],
            STEP,
        )
        .unwrap();
        assert_eq!(g.actors[item].held_by, None);
        assert!(
            g.actors[item].body.height < 17.,
            "release snapped to a fixed height"
        );
        assert!(g.actors[item].body.position.distance(position) < 2.);
    }
    #[test]
    fn stride_tracks_distance_and_stops_with_actor() {
        let mut g = game();
        for _ in 0..30 {
            g.step(
                [
                    Player_Input {
                        movement: Vec2::Y,
                        ..default()
                    },
                    default(),
                ],
                STEP,
            )
            .unwrap();
        }
        let pose = &g.actors.iter().find(|a| a.player().is_some()).unwrap().pose;
        assert!(pose.phase > 0.);
        assert!(pose.lean > 0.);
        let mut pose = Motion_Pose::default();
        pose.advance(
            Pose_Input {
                facing: Vec2::X,
                grounded: true,
                animal: true,
                ..default()
            },
            STEP,
        );
        assert_eq!(pose.phase, 0.);
    }
}
