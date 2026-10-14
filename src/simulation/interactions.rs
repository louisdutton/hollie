use super::*;

impl<S: DerefMut<Target = Game_State>> Game_World<S> {
    pub(super) fn dismount_direction(&self, player: usize, animal: usize) -> Option<Vec2> {
        let rider = &self.actors[player].body;
        let mount = &self.actors[animal];
        let forward = if mount.facing.length_squared() > 0. {
            mount.facing.normalize()
        } else {
            Vec2::Y
        };
        let right = Vec2::new(forward.y, -forward.x);
        let height = if mount.body.grounded || mount.body.swimming {
            mount.body.height
        } else {
            rider.height
        };
        let mut start = rider.clone();
        start.position = mount.body.position;
        start.height = height;
        let start_bounds = start.bounds();
        let animal_bounds = mount.body.bounds();
        let obstacles = self.obstacles(player);
        let room = self.state.room.collision_bounds;
        for direction in [
            right,
            -right,
            -forward,
            forward,
            right - forward,
            -right - forward,
            right + forward,
            -right + forward,
        ] {
            let direction = direction.normalize();
            let mut distance = f32::INFINITY;
            for (axis, component) in [(0, direction.x), (2, direction.y)] {
                if component > 0. {
                    distance = distance.min(
                        (mount.body.offset[axis] + mount.body.size[axis] - rider.offset[axis])
                            / component,
                    );
                } else if component < 0. {
                    distance = distance.min(
                        (mount.body.offset[axis] - rider.offset[axis] - rider.size[axis])
                            / component,
                    );
                }
            }
            let mut destination = start.clone();
            destination.position += direction * (distance + 1.);
            let bounds = destination.bounds();
            if bounds.min.x < room.x
                || bounds.max.x > room.x + room.width
                || bounds.min.z < room.y
                || bounds.max.z > room.y + room.height
                || bounds.intersects(animal_bounds)
                || self.blocked(bounds, &obstacles)
            {
                continue;
            }
            let swept = Aabb {
                min: start_bounds.min.min(bounds.min),
                max: start_bounds.max.max(bounds.max),
            };
            if !self.blocked(swept, &obstacles) {
                return Some(direction);
            }
        }
        None
    }
    pub(super) fn interact(&mut self, player: usize) {
        if let Some(mount) = self.actors[player].mounted {
            if let Some(animal) = self.actors.iter().position(|a| a.id == mount) {
                let Some(direction) = self.dismount_direction(player, animal) else {
                    return;
                };
                let mount = &self.actors[animal];
                let origin = Vec3::new(
                    mount.body.position.x,
                    mount.body.height,
                    mount.body.position.y,
                );
                let rider = &self.actors[player];
                let anchor = rider
                    .riding_anchor
                    .map(|p| p + origin - rider.riding_origin.unwrap_or(origin))
                    .unwrap_or(Vec3::new(
                        rider.body.position.x,
                        rider.body.height,
                        rider.body.position.y,
                    ));
                let mut body = rider.body.clone();
                body.position = Vec2::new(anchor.x, anchor.z);
                // The collision box top is not the saddle height of the animated model.
                body.height = anchor.y;
                if self.blocked(body.bounds(), &self.obstacles(player)) {
                    return;
                }
                body.velocity = (mount.body.velocity + direction * 70.)
                    .clamp_length_max(mount.body.velocity.length().max(70.));
                body.vertical_velocity = JUMP_SPEED + mount.body.vertical_velocity.max(0.);
                body.grounded = false;
                body.swimming = false;
                self.actors[player].body = body;
                self.actors[player].mounted = None;
                self.actors[player].riding_anchor = None;
                self.actors[player].riding_origin = None;
                self.actors[player].dismount_air_control = true;
                self.actors[animal].mounted = None;
                self.actors[animal].coasting = true;
            }
            return;
        }
        if let Some(item) = self.actors[player].carrying {
            if let Some(index) = self.actors.iter().position(|a| a.id == item) {
                let mut body = self.actors[index].body.clone();
                // Release from the last evaluated hand pose, as in the original renderer.
                let carrier_origin = Vec3::new(
                    self.actors[player].body.position.x,
                    self.actors[player].body.height,
                    self.actors[player].body.position.y,
                );
                let cached = self.actors[index].held_anchor.map(|anchor| {
                    anchor + carrier_origin
                        - self.actors[index].held_origin.unwrap_or(carrier_origin)
                });
                let anchor = cached.unwrap_or(Vec3::new(
                    self.actors[player].body.position.x + self.actors[player].facing.x * 8.,
                    self.actors[player].body.height + 28.,
                    self.actors[player].body.position.y + self.actors[player].facing.y * 8.,
                ));
                body.position = Vec2::new(anchor.x, anchor.z);
                body.height = anchor.y;
                if !self.blocked(body.bounds(), &self.obstacles(index)) {
                    body.velocity =
                        self.actors[player].body.velocity + self.actors[player].facing * 45.;
                    body.vertical_velocity = self.actors[player].body.vertical_velocity + 15.;
                    body.grounded = false;
                    self.actors[index].body = body;
                    self.actors[index].held_by = None;
                    self.actors[index].held_anchor = None;
                    self.actors[index].held_origin = None;
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
            self.state.dialog = Some(0);
            self.state.dialog_characters = 0.;
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
                self.actors[player].riding_anchor = None;
                self.actors[player].riding_origin = None;
                self.actors[player].dismount_air_control = false;
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
    pub(super) fn update_ram(&mut self, dt: f32) {
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
                    self.state.effects.push(((wall.min + wall.max) * 0.5, true));
                }
            }
        }
    }
    pub(super) fn puzzles(&mut self) {
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
                    self.state
                        .effects
                        .push(((plate.min + plate.max) * 0.5, false));
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
    pub(super) fn close_gate(&mut self, index: usize) {
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
                self.state
                    .room
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
}
