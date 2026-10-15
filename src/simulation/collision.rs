use super::*;

impl<S: DerefMut<Target = Game_State>> Game_World<'_, S> {
    pub(super) fn obstacles(&self, index: usize) -> Vec<Aabb> {
        let mut obstacles = self.static_obstacles();
        obstacles.extend(
            self.actors
                .iter()
                .enumerate()
                .filter(|(i, a)| {
                    *i != index && a.solid() && a.release_player != Some(self.actors[index].entity)
                })
                .map(|(_, a)| a.body.bounds()),
        );
        obstacles
    }
    pub(super) fn blocked(&self, b: Aabb, obstacles: &[Aabb]) -> bool {
        self.tile_blocked(b) || obstacles.iter().any(|o| b.intersects(*o))
    }
}

impl Game_State {
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
}
