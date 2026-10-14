use super::*;

impl<S: DerefMut<Target = Game_State>> Game_World<S> {
    pub fn step(&mut self, inputs: [Player_Input; 2], dt: f32) -> Result<()> {
        let dt = dt.clamp(0., 0.1);
        self.state.elapsed += dt;
        self.state.frame += 1;
        self.state.effects.clear();
        if let Some(page) = self.state.dialog {
            let text = DIALOG[page];
            self.state.dialog_characters += dt / 0.025;
            if inputs.iter().any(|i| i.interact) {
                if self.state.dialog_characters < (text.chars().count() as f32) {
                    self.state.dialog_characters = text.chars().count() as f32;
                } else if page + 1 == DIALOG.len() {
                    self.state.dialog = None;
                } else {
                    self.state.dialog = Some(page + 1);
                    self.state.dialog_characters = 0.;
                }
            }
            return Ok(());
        }
        if let Some(mut transition) = self.state.transition.take() {
            transition.elapsed += dt;
            if transition.elapsed >= 0.3 && !transition.loaded {
                let next = self.state.registry.get(&transition.room)?.room.clone();
                self.load_room(next, &transition.door)?;
                transition.loaded = true;
            }
            if transition.elapsed < 0.6 {
                self.state.transition = Some(transition);
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
            if self.state.doors_enabled {
                if let Entity_Properties::Door(d) = &door.properties {
                    self.state.transition = Some(Transition {
                        room: d.target_room_id.clone(),
                        door: d.target_door_id.clone(),
                        elapsed: 0.,
                        loaded: false,
                    });
                    self.state.doors_enabled = false;
                }
            }
        } else {
            self.state.doors_enabled = true;
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
        let state = &mut *self.state;
        state.surfaces.advance(&self.actors, &state.room, dt);
        self.actors
            .retain(|a| a.player().is_some() || a.health > 0 || a.death_timer < 26. / 60.);
        Ok(())
    }
}
impl<S: Deref<Target = Game_State>> Game_World<S> {
    pub fn observation(&self) -> Value {
        let body = |a: &Actor| json!({"ram_ready":a.ram_ready,"ram":a.pose.ram,"head_turn":a.pose.head_turn,"vertical_velocity":a.body.vertical_velocity,"swimming":a.body.swimming,"stride":a.pose.phase,"lean":a.pose.lean,"id":a.id,"position":{"x":a.body.position.x,"y":a.body.position.y},"velocity":{"x":a.body.velocity.x,"y":a.body.velocity.y},"height":a.body.height,"grounded":a.body.grounded});
        json!({"visual":{"water_contacts":self.state.surfaces.water.len(),"wakes":self.state.surfaces.wakes.len(),"grass_contacts":self.state.surfaces.grass.len(),"grass_trails":self.state.surfaces.grass_trails.len()},"frame":self.state.frame,"seed":self.state.seed,"scene":"Gameplay","room":self.state.room.id,"entity_count":self.actors.len(),"players":self.actors.iter().filter_map(|a|a.player().map(|i|json!({"body":body(a),"player":format!("Player_{}",i+1),"riding_anchor":a.riding_anchor.map(|p|json!({"x":p.x,"y":p.y,"z":p.z})),"dismount_air_control":a.dismount_air_control,"mounted":a.mounted.unwrap_or(0),"carrying":a.carrying.unwrap_or(0)}))).collect::<Vec<_>>(),"holdables":self.actors.iter().filter(|a|matches!(a.properties,Entity_Properties::Holdable(_))).map(|a|json!({"body":body(a),"held_anchor":a.held_anchor.map(|p|json!({"x":p.x,"y":p.y,"z":p.z}))})).collect::<Vec<_>>(),"enemies":self.actors.iter().filter(|a|a.kind().is_some()).map(|a|json!({"body":body(a),"move_direction":{"x":a.move_direction.x,"y":a.move_direction.y},"move_timer":a.move_timer,"wait_timer":a.wait_timer})).collect::<Vec<_>>()})
    }
}
