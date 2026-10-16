use serde::Serialize;

#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
pub(crate) enum Crown_Layout {
    Rounded_Tiers,
    Leafy_Tiers,
    Joined_Crown,
}
impl Crown_Layout {
    pub fn label(self) -> &'static str {
        match self {
            Self::Rounded_Tiers => "Rounded tiers",
            Self::Leafy_Tiers => "Leafy tiers",
            Self::Joined_Crown => "Joined crown",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
pub(crate) struct Tree_Parameters {
    pub layout: Crown_Layout,
    pub width: f32,
    pub depth: f32,
    pub height: f32,
    pub irregularity: f32,
    pub lobes: f32,
    pub leaf_size: f32,
    pub leaf_density: f32,
    pub local_shading: f32,
    pub seed: u32,
}
impl Default for Tree_Parameters {
    fn default() -> Self {
        Self {
            layout: Crown_Layout::Joined_Crown,
            width: 1.,
            depth: 1.,
            height: 1.,
            irregularity: 0.65,
            lobes: 0.65,
            leaf_size: 1.,
            leaf_density: 1.,
            local_shading: 0.32,
            seed: 1723,
        }
    }
}
impl Tree_Parameters {
    pub const ROWS: usize = 10;

    pub fn adjust(&mut self, row: usize, direction: i32) {
        if row == 0 {
            const LAYOUTS: [Crown_Layout; 3] = [
                Crown_Layout::Rounded_Tiers,
                Crown_Layout::Leafy_Tiers,
                Crown_Layout::Joined_Crown,
            ];
            self.layout = LAYOUTS[(self.layout as i32 + direction).rem_euclid(3) as usize];
        } else if row == 9 {
            self.seed = self.seed.saturating_add_signed(direction).clamp(1, 9999);
        } else {
            let (value, step, low, high) = match row {
                1 => (&mut self.width, 0.05, 0.65, 1.5),
                2 => (&mut self.depth, 0.05, 0.65, 1.5),
                3 => (&mut self.height, 0.05, 0.7, 1.4),
                4 => (&mut self.irregularity, 0.05, 0., 1.),
                5 => (&mut self.lobes, 0.05, 0., 1.),
                6 => (&mut self.leaf_size, 0.1, 0.6, 1.6),
                7 => (&mut self.leaf_density, 0.1, 0.4, 1.4),
                _ => (&mut self.local_shading, 0.05, 0., 1.),
            };
            *value = (*value + direction as f32 * step).clamp(low, high);
        }
    }

    pub fn reset(&mut self, row: usize) {
        let defaults = Self::default();
        match row {
            0 => self.layout = defaults.layout,
            1 => self.width = defaults.width,
            2 => self.depth = defaults.depth,
            3 => self.height = defaults.height,
            4 => self.irregularity = defaults.irregularity,
            5 => self.lobes = defaults.lobes,
            6 => self.leaf_size = defaults.leaf_size,
            7 => self.leaf_density = defaults.leaf_density,
            8 => self.local_shading = defaults.local_shading,
            _ => self.seed = defaults.seed,
        }
    }

    pub fn rows(self) -> [String; Self::ROWS] {
        [
            format!("Layout: {}", self.layout.label()),
            format!("Width: {:.2}", self.width),
            format!("Depth: {:.2}", self.depth),
            format!("Height: {:.2}", self.height),
            format!("Irregularity: {:.2}", self.irregularity),
            format!("Crown lobes: {:.2}", self.lobes),
            format!("Leaf size: {:.1}", self.leaf_size),
            format!("Leaf density: {:.1}", self.leaf_density),
            format!("Local shading: {:.2}", self.local_shading),
            format!("Seed: {}", self.seed),
        ]
    }
}
