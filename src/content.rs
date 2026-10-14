use anyhow::{Context, Result, ensure};
use bevy::prelude::Vec2;
use serde::{Deserialize, Serialize};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    io::Write,
    path::{Path, PathBuf},
};

#[derive(Clone, Copy, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Position {
    pub x: i32,
    pub y: i32,
}
impl Position {
    pub fn vector(self) -> Vec2 {
        Vec2::new(self.x as f32, self.y as f32)
    }
}
#[derive(Clone, Copy, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Size {
    pub width: usize,
    pub height: usize,
}
#[derive(Clone, Copy, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Bounds {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}
impl Bounds {
    pub fn contains(self, p: Vec2) -> bool {
        p.x >= self.x && p.y >= self.y && p.x <= self.x + self.width && p.y <= self.y + self.height
    }
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Grid {
    pub tile_size: usize,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Layers {
    pub base: Vec<u16>,
    pub decoration: Vec<u16>,
    #[serde(default)]
    pub collision: Vec<u8>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub grass: Vec<u8>,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum Character_Kind {
    Goblin,
    Skeleton,
    Human,
    Dog,
    Horse,
    Bison,
    Turtle,
}
impl Character_Kind {
    pub fn mountable(self) -> bool {
        matches!(self, Self::Dog | Self::Horse | Self::Bison | Self::Turtle)
    }
    pub fn model(self) -> &'static str {
        match self {
            Self::Dog => "world/props/animal-dog-raylib.glb",
            Self::Horse => "world/props/animal-horse-raylib.glb",
            Self::Bison => "world/props/animal-bison-raylib.glb",
            Self::Turtle => "world/props/animal-turtle-raylib.glb",
            _ => "world/props/figurine-raylib.glb",
        }
    }
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Player_Properties {
    pub player_index: usize,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Enemy_Properties {
    pub kind: Character_Kind,
}
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Empty_Properties {}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Door_Properties {
    pub size: Size,
    pub target_room_id: String,
    pub target_door_id: String,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Plate_Properties {
    pub trigger_id: u32,
    #[serde(default)]
    pub requires_both: bool,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Gate_Properties {
    pub gate_id: u32,
    pub size: Size,
    pub required_trigger_ids: Vec<u32>,
    #[serde(default)]
    pub inverted: bool,
    #[serde(default)]
    pub breakable: bool,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", content = "properties", rename_all = "snake_case")]
pub enum Entity_Properties {
    Player(Player_Properties),
    Enemy(Enemy_Properties),
    Npc(Empty_Properties),
    Holdable(Empty_Properties),
    Door(Door_Properties),
    #[serde(rename = "pressure_plate")]
    Pressure_Plate(Plate_Properties),
    Gate(Gate_Properties),
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Room_Entity {
    pub id: String,
    pub position: Position,
    #[serde(flatten)]
    pub properties: Entity_Properties,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Structure {
    pub id: String,
    pub position: Position,
    pub size: Size,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Room {
    pub id: String,
    pub name: String,
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub music_path: String,
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub ambience_path: String,
    #[serde(default)]
    pub interior: bool,
    pub size: Size,
    pub grid: Grid,
    pub camera_bounds: Bounds,
    pub collision_bounds: Bounds,
    pub layers: Layers,
    #[serde(default)]
    pub structures: Vec<Structure>,
    #[serde(default)]
    pub entities: Vec<Room_Entity>,
}
impl Room {
    pub fn decode(text: &str) -> Result<Self> {
        // Old maps omit the empty properties object for crates and NPCs.
        let mut wire: serde_json::Value = json5::from_str(text)?;
        if let Some(entities) = wire.get_mut("entities").and_then(|v| v.as_array_mut()) {
            for entity in entities {
                if matches!(entity["type"].as_str(), Some("npc" | "holdable"))
                    && entity.get("properties").is_none()
                {
                    entity["properties"] = serde_json::json!({});
                }
            }
        }
        let room: Self = serde_json::from_value(wire)?;
        room.validate()?;
        Ok(room)
    }
    pub fn load(path: &Path) -> Result<Self> {
        Self::decode(&fs::read_to_string(path)?)
            .with_context(|| format!("invalid room {}", path.display()))
    }
    pub fn tile_index(&self, p: Vec2) -> Option<usize> {
        let x = (p.x / self.grid.tile_size as f32).floor() as i32;
        let y = (p.y / self.grid.tile_size as f32).floor() as i32;
        (x >= 0 && y >= 0 && (x as usize) < self.size.width && (y as usize) < self.size.height)
            .then_some(y.max(0) as usize * self.size.width + x.max(0) as usize)
    }
    pub fn water_at(&self, p: Vec2) -> bool {
        self.water_value(p) > 0.
    }
    pub fn water_value(&self, p: Vec2) -> f32 {
        let q = p / self.grid.tile_size as f32 - Vec2::splat(0.5);
        let x = q.x.floor() as i32;
        let y = q.y.floor() as i32;
        let cell = |x: i32, y: i32| {
            if x < 0 || y < 0 || x as usize >= self.size.width || y as usize >= self.size.height {
                -1.
            } else if self.layers.base[y as usize * self.size.width + x as usize] == 500 {
                1.
            } else {
                -1.
            }
        };
        let fx = q.x - x as f32;
        let fy = q.y - y as f32;
        let north = cell(x, y) * (1. - fx) + cell(x + 1, y) * fx;
        let south = cell(x, y + 1) * (1. - fx) + cell(x + 1, y + 1) * fx;
        north * (1. - fy) + south * fy
    }
    pub fn validate(&self) -> Result<()> {
        ensure!(
            !self.id.is_empty() && !self.name.is_empty(),
            "room id and name must not be empty"
        );
        ensure!(
            self.size.width > 0 && self.size.height > 0 && self.grid.tile_size > 0,
            "room and grid size must be positive"
        );
        let n = self
            .size
            .width
            .checked_mul(self.size.height)
            .context("room dimensions overflow")?;
        ensure!(n <= 1_000_000, "room too large");
        ensure!(
            self.layers.base.len() == n && self.layers.decoration.len() == n,
            "incorrect base or decoration layer length"
        );
        ensure!(
            self.layers.collision.is_empty() || self.layers.collision.len() == n,
            "incorrect collision layer length"
        );
        ensure!(
            self.layers.grass.is_empty() || self.layers.grass.len() == n,
            "incorrect grass layer length"
        );
        ensure!(
            self.layers.collision.iter().all(|v| *v <= 1),
            "collision values must be 0 or 1"
        );
        for b in [self.camera_bounds, self.collision_bounds] {
            ensure!(
                [b.x, b.y, b.width, b.height].iter().all(|v| v.is_finite())
                    && b.width > 0.
                    && b.height > 0.,
                "invalid room bounds"
            );
        }
        let extent = Vec2::new(
            (self.size.width * self.grid.tile_size) as f32,
            (self.size.height * self.grid.tile_size) as f32,
        );
        let (mut ids, mut players, mut triggers, mut gates) = (
            BTreeSet::new(),
            BTreeSet::new(),
            BTreeSet::new(),
            BTreeSet::new(),
        );
        for s in &self.structures {
            ensure!(
                !s.id.is_empty()
                    && s.size.width > 0
                    && s.size.height > 0
                    && s.position.x >= 0
                    && s.position.y >= 0
                    && s.position.x as f32 + s.size.width as f32 <= extent.x
                    && s.position.y as f32 + s.size.height as f32 <= extent.y,
                "invalid structure {}",
                s.id
            );
        }
        for e in &self.entities {
            ensure!(
                !e.id.is_empty() && ids.insert(&e.id),
                "empty or duplicate entity id {}",
                e.id
            );
            let p = e.position.vector();
            ensure!(
                p.x >= 0. && p.y >= 0. && p.x < extent.x && p.y < extent.y,
                "entity {} outside room",
                e.id
            );
            match &e.properties {
                Entity_Properties::Player(p) => ensure!(
                    (1..=2).contains(&p.player_index) && players.insert(p.player_index),
                    "invalid or duplicate player"
                ),
                Entity_Properties::Pressure_Plate(p) => ensure!(
                    p.trigger_id > 0 && triggers.insert(p.trigger_id),
                    "invalid or duplicate trigger"
                ),
                Entity_Properties::Gate(g) => {
                    ensure!(
                        g.gate_id > 0
                            && gates.insert(g.gate_id)
                            && g.size.width > 0
                            && g.size.height > 0,
                        "invalid gate"
                    );
                    ensure!(
                        g.breakable || !g.required_trigger_ids.is_empty(),
                        "gate has no triggers"
                    );
                    let unique: BTreeSet<_> = g.required_trigger_ids.iter().collect();
                    ensure!(
                        unique.len() == g.required_trigger_ids.len(),
                        "duplicate gate trigger"
                    );
                }
                Entity_Properties::Door(d) => ensure!(
                    d.size.width > 0
                        && d.size.height > 0
                        && !d.target_room_id.is_empty()
                        && !d.target_door_id.is_empty(),
                    "invalid door"
                ),
                _ => {}
            }
        }
        for e in &self.entities {
            if let Entity_Properties::Gate(g) = &e.properties {
                ensure!(
                    g.required_trigger_ids
                        .iter()
                        .all(|id| triggers.contains(id)),
                    "gate references missing trigger"
                );
            }
        }
        Ok(())
    }
    pub fn save(&self, path: &Path) -> Result<()> {
        self.validate()?;
        let mut temp = tempfile::NamedTempFile::new_in(path.parent().context("missing parent")?)?;
        temp.write_all(serde_json::to_string_pretty(self)?.as_bytes())?;
        temp.write_all(b"\n")?;
        temp.as_file().sync_all()?;
        temp.persist(path)?;
        Ok(())
    }
}
#[derive(Clone, Debug)]
pub struct Room_Entry {
    pub path: PathBuf,
    pub room: Room,
}
#[derive(Clone, Debug, Default)]
pub struct Room_Registry {
    pub rooms: BTreeMap<String, Room_Entry>,
}
impl Room_Registry {
    pub fn load(root: &Path) -> Result<Self> {
        let mut registry = Self::default();
        let mut paths: Vec<_> = fs::read_dir(root.join("maps"))?
            .map(|entry| entry.map(|e| e.path()))
            .collect::<std::io::Result<_>>()?;
        paths.sort();
        for path in paths {
            if path.extension().is_some_and(|e| e == "json") {
                let room = Room::load(&path)?;
                for (kind, path) in [
                    ("music", &room.music_path),
                    ("ambience", &room.ambience_path),
                ] {
                    if !path.is_empty() {
                        ensure!(root.join(path).is_file(), "missing {kind} {path}");
                    }
                }

                ensure!(
                    registry
                        .rooms
                        .insert(room.id.clone(), Room_Entry { path, room })
                        .is_none(),
                    "duplicate room id"
                );
            }
        }
        ensure!(!registry.rooms.is_empty(), "no rooms found");
        for entry in registry.rooms.values() {
            for entity in &entry.room.entities {
                if let Entity_Properties::Door(d) = &entity.properties {
                    let target = registry
                        .rooms
                        .get(&d.target_room_id)
                        .context("door references missing room")?;
                    ensure!(target.room.entities.iter().any(|e|matches!(&e.properties,Entity_Properties::Door(arrival) if e.id==d.target_door_id || arrival.target_door_id==d.target_door_id)), "door references missing target door");
                }
            }
        }
        Ok(registry)
    }
    pub fn get(&self, id: &str) -> Result<&Room_Entry> {
        self.rooms
            .get(id)
            .with_context(|| format!("unknown room {id}"))
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn all_shipped_rooms_round_trip() {
        let registry = Room_Registry::load(Path::new("res")).unwrap();
        for entry in registry.rooms.values() {
            let encoded = serde_json::to_string(&entry.room).unwrap();
            assert_eq!(Room::decode(&encoded).unwrap(), entry.room);
        }
    }
    #[test]
    fn invalid_edit_preserves_file() {
        let mut room = Room_Registry::load(Path::new("res"))
            .unwrap()
            .get("demo")
            .unwrap()
            .room
            .clone();
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("room.json");
        room.save(&path).unwrap();
        let before = fs::read(&path).unwrap();
        room.layers.base.clear();
        assert!(room.save(&path).is_err());
        assert_eq!(fs::read(path).unwrap(), before);
    }
    #[test]
    fn unknown_entity_property_is_rejected() {
        let mut v: serde_json::Value =
            serde_json::from_str(&fs::read_to_string("res/maps/demo.json").unwrap()).unwrap();
        v["entities"][0]["properties"]["unknown"] = true.into();
        assert!(Room::decode(&v.to_string()).is_err());
    }
}
