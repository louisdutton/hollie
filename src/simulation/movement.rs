use super::*;

impl<S: DerefMut<Target = Game_State>> Game_World<'_, S> {
    pub(super) fn animal_movement(
        actor: &mut Actor,
        direction: Vec2,
        mut profile: Movement_Profile,
        dt: f32,
    ) {
        let kind = actor.kind().unwrap_or(Character_Kind::Human);
        if actor.body.swimming && kind != Character_Kind::Turtle {
            profile.max_speed = profile.max_speed.min(60.);
        }
        if !actor.body.swimming && kind == Character_Kind::Turtle {
            profile.max_speed = profile.max_speed.min(50.);
        }
        let charging = actor.ram.ready && actor.mounted.is_some();
        if charging {
            profile.max_speed = 180.;
            profile.acceleration = 75.;
        }
        let mut magnitude = direction.length().min(1.);
        if magnitude > 0. {
            let angle = actor.locomotion.facing.x.atan2(actor.locomotion.facing.y);
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
            actor.locomotion.facing = Vec2::new(angle.sin(), angle.cos());
            magnitude *= delta.cos().max(0.25);
        }
        let speed = accelerate(
            Vec2::new(actor.body.velocity.length(), 0.),
            Vec2::new(magnitude, 0.),
            profile,
            dt,
        )
        .x;
        actor.body.velocity = actor.locomotion.facing * speed;
    }
    pub(super) fn update_motion(&mut self, inputs: [Player_Input; 2], dt: f32) {
        for i in 0..self.actors.len() {
            if let Some(player) = self.actors[i].player() {
                if self.actors[i].body.grounded || self.actors[i].body.swimming {
                    self.actors[i].locomotion.dismount_air_control = false;
                }
                if inputs[player].jump
                    && self.actors[i].mounted.is_none()
                    && self.actors[i].carrying.is_some()
                {
                    self.actors[i].body.jump(JUMP_SPEED);
                }
                if inputs[player].interact && self.actors[i].attachment.mount_time >= 0.4 {
                    self.interact(i);
                } else if inputs[player].interact && self.actors[i].mounted.is_none() {
                    self.interact(i);
                }
                let direction = camera_relative(inputs[player].movement);
                if let Some(mount) = self.actors[i].mounted {
                    self.actors[i].attachment.mount_time += dt;
                    if self.actors[i].attachment.mount_time < 0.4 {
                        continue;
                    }
                    if let Some(index) = self.actors.iter().position(|a| a.entity == mount) {
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
                            && !self.actors[index].ram.ready
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
                    self.actors[i].body.velocity = if self.actors[i].locomotion.dismount_air_control
                    {
                        steer_air(self.actors[i].body.velocity, direction, dt)
                    } else {
                        accelerate(self.actors[i].body.velocity, direction, profile, dt)
                    };
                    if self.actors[i].body.velocity.length_squared() > 0.01 {
                        self.actors[i].locomotion.facing = self.actors[i].body.velocity.normalize();
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
            if self.actors[i].locomotion.coasting {
                Self::animal_movement(&mut self.actors[i], Vec2::ZERO, RIDING_PROFILE, dt);
                if self.actors[i].body.velocity == Vec2::ZERO {
                    self.actors[i].locomotion.coasting = false;
                    self.actors[i].wander.wait_timer = 0.5;
                }
                continue;
            }
            self.actors[i].wander.move_timer -= dt;
            self.actors[i].wander.wait_timer = (self.actors[i].wander.wait_timer - dt).max(0.);
            if self.actors[i].wander.move_timer <= 0. {
                self.actors[i].wander.direction = Vec2::new(
                    self.state.rng.random_range(-1.0..1.),
                    self.state.rng.random_range(-1.0..1.),
                );
                self.actors[i].wander.move_timer = self.state.rng.random_range(1.0..3.);
                if self.state.rng.random::<f32>() < 0.25 {
                    self.actors[i].wander.wait_timer = self.state.rng.random_range(0.5..1.5);
                }
            }
            let mut direction = if self.actors[i].wander.wait_timer > 0. {
                Vec2::ZERO
            } else {
                self.actors[i].wander.direction
            };
            if self.actors[i].kind().is_some_and(|k| k.mountable()) {
                let wants_water = self.actors[i].kind() == Some(Character_Kind::Turtle);
                let start = self.actors[i].body.position;
                let obstacles = self.obstacles(i);
                let ahead = 24. + self.actors[i].body.velocity.length() / 1.5;
                let clear = |side: Vec2| {
                    let mut body = (*self.actors[i].body).clone();
                    body.position = start + side * 18.;
                    body.height += 6.;
                    !self.blocked(body.bounds(), &obstacles)
                        && (1..=(ahead / 4.).ceil() as i32).all(|s| {
                            self.state.room.water_at(start + side * s as f32 * 4.) == wants_water
                                || self.state.room.water_at(start) != wants_water
                        })
                };
                if !clear(direction.normalize_or_zero()) || !clear(self.actors[i].locomotion.facing)
                {
                    let right = Vec2::new(
                        self.actors[i].locomotion.facing.y,
                        -self.actors[i].locomotion.facing.x,
                    );
                    direction = [right, -right, -self.actors[i].locomotion.facing]
                        .into_iter()
                        .find(|side| clear(*side))
                        .unwrap_or_default();
                    self.actors[i].wander.direction = direction;
                    self.actors[i].wander.move_timer = 1.;
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
                    self.actors[i].locomotion.facing = direction.normalize();
                }
            }
        }
    }
    pub(super) fn sync_relationships(&mut self) {
        for i in 0..self.actors.len() {
            if let Some(id) = self.actors[i]
                .mounted
                .filter(|_| self.actors[i].player().is_some())
            {
                if let Some((animal, facing)) = self
                    .actors
                    .iter()
                    .find(|a| a.entity == id)
                    .map(|a| ((*a.body).clone(), a.locomotion.facing))
                {
                    let t = (self.actors[i].attachment.mount_time / 0.4).min(1.);
                    let end = Vec3::new(
                        animal.position.x,
                        animal.height + animal.size.y * 0.75,
                        animal.position.y,
                    );
                    let p = self.actors[i].attachment.mount_start.lerp(end, t)
                        + Vec3::Y * (64. * t * (1. - t));
                    self.actors[i].body.position = Vec2::new(p.x, p.z);
                    self.actors[i].body.height = p.y;
                    self.actors[i].body.velocity = animal.velocity;
                    self.actors[i].body.vertical_velocity = animal.vertical_velocity;
                    self.actors[i].body.grounded = false;
                    self.actors[i].locomotion.facing = facing;
                }
            }
            if let Some(id) = self.actors[i].held_by {
                if let Some(player) = self
                    .actors
                    .iter()
                    .find(|a| a.entity == id)
                    .map(|a| (*a.body).clone())
                {
                    self.actors[i].body.position = player.position;
                    self.actors[i].body.height = player.height + 28.;
                    self.actors[i].body.velocity = player.velocity;
                    self.actors[i].body.vertical_velocity = player.vertical_velocity;
                    self.actors[i].body.grounded = false;
                } else {
                    self.actors[i].held_by = None;
                }
            }
        }
    }
    pub(super) fn move_body(&mut self, i: usize, dt: f32) {
        let obstacles = self.obstacles(i);
        let mut body = (*self.actors[i].body).clone();
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
        let wet = self.state.room.water_at(body.position);
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
                    self.state
                        .effects
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
        let bounds = self.state.room.collision_bounds;
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
                .any(|p| p.entity == id && p.body.bounds().horizontal(body.bounds()))
            {
                self.actors[i].release_player = None;
            }
        }
        *self.actors[i].body = body;
    }
}
