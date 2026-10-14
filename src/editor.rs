use crate::{app::Mode, content::*, simulation::Game_World};
use bevy::{prelude::*, window::PrimaryWindow};
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum Layer {
    #[default]
    Base,
    Decoration,
    Collision,
    Grass,
    Entity,
    Structure,
}
#[derive(Resource, Default)]
pub struct Editor_State {
    pub layer: Layer,
    pub cursor: IVec2,
    pub selected: usize,
    pub field: usize,
    pub properties: bool,
    pub grid: bool,
    pub message: String,
    pub camera_offset: Vec2,
    pub zoom: f32,
    last_mouse: Option<Vec2>,
    history: Vec<Room>,
    pub(crate) dirty: bool,
    repeat: f32,
}
impl Editor_State {
    pub fn status(&self, game: &Game_World) -> String {
        format!(
            "Editor · {}{}\n{:?} · brush {} · ({}, {})\nTab layer · Left/Right brush · click paint · right click erase\nE properties · Up/Down field · Left/Right value · G grid\nCtrl+S save · Ctrl+Z undo · F1 exit\n{}",
            game.room.name,
            if self.dirty { " *" } else { "" },
            self.layer,
            self.selected,
            self.cursor.x,
            self.cursor.y,
            self.message
        )
    }
    fn checkpoint(&mut self, room: &Room) {
        if self.history.len() >= 64 {
            self.history.remove(0);
        }
        self.history.push(room.clone());
        self.dirty = true;
    }
}
pub struct Editor_Plugin;
impl Plugin for Editor_Plugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<Editor_State>()
            .add_systems(OnEnter(Mode::Editor), enter_editor)
            .add_systems(OnExit(Mode::Editor), exit_editor)
            .add_systems(Update, (edit, draw_grid).run_if(in_state(Mode::Editor)));
    }
}
fn enter_editor(mut editor: ResMut<Editor_State>) {
    editor.message.clear();
    editor.grid = true;
    editor.history.clear();
    editor.dirty = false;
    editor.camera_offset = Vec2::ZERO;
    editor.zoom = 0.55;
    editor.last_mouse = None;
}
fn exit_editor(mut game: ResMut<Game_World>, mut editor: ResMut<Editor_State>) {
    let path = game.registry.get(&game.room.id).unwrap().path.clone();
    match Room::load(&path) {
        Ok(room) => {
            let _ = game.load_room(room, "");
        }
        Err(error) => editor.message = error.to_string(),
    }
}
const TILES: &[u16] = &[1, 2, 3, 33, 34, 35, 65, 66, 4, 5, 6, 500, 0];
const DECORATIONS: &[u16] = &[
    257, 258, 259, 260, 289, 290, 291, 292, 321, 322, 323, 324, 353, 354, 355, 356, 385, 386, 387,
    388, 0,
];
pub(crate) fn edit(
    #[cfg(debug_assertions)] controller: Res<crate::automation::Controller>,
    keys: Res<ButtonInput<KeyCode>>,
    mouse: Res<ButtonInput<MouseButton>>,
    window: Query<&Window, With<PrimaryWindow>>,
    cameras: Query<(&Camera, &GlobalTransform), With<Camera3d>>,
    pads: Query<&Gamepad>,
    time: Res<Time>,
    mut editor: ResMut<Editor_State>,
    mut game: ResMut<Game_World>,
) {
    #[cfg(debug_assertions)]
    if crate::automation::waiting(&controller) {
        return;
    }
    let dt = time.delta_secs();
    #[cfg(debug_assertions)]
    let dt = if controller.stepping {
        crate::simulation::STEP
    } else {
        dt
    };
    editor.repeat -= dt;
    let direction = Vec2::new(
        keys.pressed(KeyCode::KeyD) as u8 as f32 - keys.pressed(KeyCode::KeyA) as u8 as f32,
        keys.pressed(KeyCode::KeyS) as u8 as f32 - keys.pressed(KeyCode::KeyW) as u8 as f32,
    );
    editor.camera_offset += crate::simulation::camera_relative(direction) * dt * 220.;
    if keys.pressed(KeyCode::Minus) {
        editor.zoom = (editor.zoom + dt).min(2.);
    }
    if keys.pressed(KeyCode::Equal) {
        editor.zoom = (editor.zoom - dt).max(0.1);
    }
    if let (Ok(window), Ok((camera, transform))) = (window.single(), cameras.single()) {
        if let Some(cursor) = window.cursor_position() {
            if editor.last_mouse != Some(cursor) {
                editor.last_mouse = Some(cursor);
                if let Ok(ray) = camera.viewport_to_world(transform, cursor) {
                    if let Some(distance) =
                        ray.intersect_plane(Vec3::ZERO, InfinitePlane3d::new(Vec3::Y))
                    {
                        let p = ray.get_point(distance);
                        editor.cursor = IVec2::new(
                            (p.x / game.room.grid.tile_size as f32).floor() as i32,
                            (p.z / game.room.grid.tile_size as f32).floor() as i32,
                        );
                    }
                }
            }
        }
    }
    if keys.just_pressed(KeyCode::Tab) || pads.iter().any(|p| p.just_pressed(GamepadButton::North))
    {
        editor.layer = match editor.layer {
            Layer::Base => Layer::Decoration,
            Layer::Decoration => Layer::Collision,
            Layer::Collision => Layer::Grass,
            Layer::Grass => Layer::Entity,
            Layer::Entity => Layer::Structure,
            Layer::Structure => Layer::Base,
        };
        editor.selected = 0;
        editor.properties = false;
    }
    if keys.just_pressed(KeyCode::KeyG) {
        editor.grid = !editor.grid;
    }
    let control = keys.pressed(KeyCode::ControlLeft) || keys.pressed(KeyCode::ControlRight);
    if control && keys.just_pressed(KeyCode::KeyZ) {
        if let Some(room) = editor.history.pop() {
            game.room = room;
            game.generation += 1;
            editor.dirty = true;
        }
        return;
    }
    if control && keys.just_pressed(KeyCode::KeyS)
        || pads
            .iter()
            .any(|p| p.just_pressed(GamepadButton::RightThumb))
    {
        let path = game.registry.get(&game.room.id).unwrap().path.clone();
        match game.room.save(&path) {
            Ok(()) => {
                let room = game.room.clone();
                let id = room.id.clone();
                game.registry.rooms.get_mut(&id).unwrap().room = room;
                editor.message = "Saved".into();
                editor.dirty = false;
            }
            Err(error) => editor.message = format!("Save rejected: {error}"),
        }
        return;
    }
    let position = Position {
        x: editor.cursor.x * game.room.grid.tile_size as i32,
        y: editor.cursor.y * game.room.grid.tile_size as i32,
    };
    let hovered = game
        .room
        .entities
        .iter()
        .position(|e| e.position == position);
    if keys.just_pressed(KeyCode::KeyE) || pads.iter().any(|p| p.just_pressed(GamepadButton::West))
    {
        editor.properties = !editor.properties;
        editor.field = 0;
    }
    let delta = if keys.just_pressed(KeyCode::ArrowLeft)
        || pads
            .iter()
            .any(|p| p.just_pressed(GamepadButton::LeftTrigger))
    {
        -1
    } else if keys.just_pressed(KeyCode::ArrowRight)
        || pads
            .iter()
            .any(|p| p.just_pressed(GamepadButton::RightTrigger))
    {
        1
    } else {
        0
    };
    if editor.properties {
        if keys.just_pressed(KeyCode::ArrowUp) {
            editor.field = editor.field.saturating_sub(1);
        }
        if keys.just_pressed(KeyCode::ArrowDown) {
            editor.field += 1;
        }
        if let Some(index) = hovered {
            editor.message = format!(
                "{} · field {} · {:?}",
                game.room.entities[index].id, editor.field, game.room.entities[index].properties
            );
            if delta != 0 {
                editor.checkpoint(&game.room);
                let registry = game.registry.clone();
                edit_properties(&mut game.room, index, editor.field, delta, &registry);
                game.generation += 1;
            }
        }
        return;
    }
    if delta != 0 {
        let count = match editor.layer {
            Layer::Base => TILES.len(),
            Layer::Decoration => DECORATIONS.len(),
            Layer::Entity => 7,
            Layer::Structure => 1,
            _ => 2,
        };
        editor.selected = (editor.selected as i32 + delta).rem_euclid(count as i32) as usize;
    }
    if let Some(pad) = pads.iter().next() {
        let d = pad.left_stick();
        if d.length() > 0.5 && editor.repeat <= 0. {
            editor.cursor += IVec2::new(d.x.round() as i32, -d.y.round() as i32);
            editor.repeat = 0.15;
        }
    }
    let index = game.room.tile_index(position.vector());
    let Some(index) = index else {
        return;
    };
    let paint = mouse.pressed(MouseButton::Left)
        || keys.just_pressed(KeyCode::Space)
        || pads.iter().any(|p| p.just_pressed(GamepadButton::South));
    let erase = mouse.pressed(MouseButton::Right)
        || keys.just_pressed(KeyCode::Delete)
        || pads.iter().any(|p| p.just_pressed(GamepadButton::East));
    if (!paint && !erase) || editor.repeat > 0. {
        return;
    }
    editor.checkpoint(&game.room);
    editor.repeat = 0.1;
    let n = game.room.layers.base.len();
    let selected = editor.selected;
    match editor.layer {
        Layer::Base => {
            game.room.layers.base[index] = if erase {
                0
            } else {
                TILES[selected % TILES.len()]
            }
        }
        Layer::Decoration => {
            game.room.layers.decoration[index] = if erase {
                0
            } else {
                DECORATIONS[selected % DECORATIONS.len()]
            }
        }
        Layer::Collision => {
            game.room.layers.collision.resize(n, 0);
            game.room.layers.collision[index] = if erase { 0 } else { 1 };
        }
        Layer::Grass => {
            game.room.layers.grass.resize(n, 0);
            game.room.layers.grass[index] = if erase { 0 } else { 255 };
        }
        Layer::Entity => {
            if erase {
                game.room.entities.retain(|e| e.position != position);
            } else if hovered.is_none() {
                let mut id = 1;
                while game
                    .room
                    .entities
                    .iter()
                    .any(|e| e.id == format!("editor_entity_{id}"))
                {
                    id += 1;
                }
                let triggers: Vec<_> = game
                    .room
                    .entities
                    .iter()
                    .filter_map(|e| {
                        if let Entity_Properties::Pressure_Plate(p) = &e.properties {
                            Some(p.trigger_id)
                        } else {
                            None
                        }
                    })
                    .collect();
                let properties = match selected {
                    0 => Entity_Properties::Player(Player_Properties { player_index: 1 }),
                    1 => Entity_Properties::Enemy(Enemy_Properties {
                        kind: Character_Kind::Horse,
                    }),
                    2 => Entity_Properties::Pressure_Plate(Plate_Properties {
                        trigger_id: triggers.iter().max().copied().unwrap_or(0) + 1,
                        requires_both: false,
                    }),
                    3 => Entity_Properties::Gate(Gate_Properties {
                        gate_id: game
                            .room
                            .entities
                            .iter()
                            .filter_map(|e| {
                                if let Entity_Properties::Gate(g) = &e.properties {
                                    Some(g.gate_id)
                                } else {
                                    None
                                }
                            })
                            .max()
                            .unwrap_or(0)
                            + 1,
                        size: Size {
                            width: 32,
                            height: 16,
                        },
                        required_trigger_ids: triggers.first().copied().into_iter().collect(),
                        inverted: false,
                        breakable: triggers.is_empty(),
                    }),
                    4 => Entity_Properties::Holdable(default()),
                    5 => Entity_Properties::Npc(default()),
                    _ => Entity_Properties::Door(Door_Properties {
                        size: Size {
                            width: 32,
                            height: 16,
                        },
                        target_room_id: game
                            .registry
                            .rooms
                            .keys()
                            .find(|id| **id != game.room.id)
                            .cloned()
                            .unwrap_or_else(|| game.room.id.clone()),
                        target_door_id: "from_small_room".into(),
                    }),
                };
                game.room.entities.push(Room_Entity {
                    id: format!("editor_entity_{id}"),
                    position,
                    properties,
                });
            }
        }
        Layer::Structure => {
            if erase {
                game.room.structures.retain(|s| s.position != position);
            } else {
                let id = format!("house_{}", game.room.structures.len() + 1);
                game.room.structures.push(Structure {
                    id,
                    position,
                    size: Size {
                        width: 96,
                        height: 96,
                    },
                });
            }
        }
    }
    game.generation += 1;
}
fn edit_properties(
    room: &mut Room,
    index: usize,
    field: usize,
    delta: i32,
    registry: &Room_Registry,
) {
    let inc = |v: usize| (v as i32 + delta).max(1) as usize;
    let kinds = [
        Character_Kind::Goblin,
        Character_Kind::Skeleton,
        Character_Kind::Human,
        Character_Kind::Dog,
        Character_Kind::Horse,
        Character_Kind::Bison,
        Character_Kind::Turtle,
    ];
    let triggers: Vec<_> = room
        .entities
        .iter()
        .filter_map(|e| {
            if let Entity_Properties::Pressure_Plate(p) = &e.properties {
                Some(p.trigger_id)
            } else {
                None
            }
        })
        .collect();
    match &mut room.entities[index].properties {
        Entity_Properties::Player(p) => p.player_index = if p.player_index == 1 { 2 } else { 1 },
        Entity_Properties::Enemy(e) => {
            let i = kinds.iter().position(|k| *k == e.kind).unwrap();
            e.kind = kinds[(i as i32 + delta).rem_euclid(kinds.len() as i32) as usize];
        }
        Entity_Properties::Pressure_Plate(p) => {
            if field % 2 == 0 {
                p.trigger_id = (p.trigger_id as i32 + delta).max(1) as u32;
            } else {
                p.requires_both = !p.requires_both;
            }
        }
        Entity_Properties::Gate(g) => match field % 6 {
            0 => g.gate_id = (g.gate_id as i32 + delta).max(1) as u32,
            1 => g.size.width = inc(g.size.width),
            2 => g.size.height = inc(g.size.height),
            3 => {
                if delta < 0 {
                    g.required_trigger_ids.pop();
                } else if let Some(id) = triggers
                    .iter()
                    .find(|id| !g.required_trigger_ids.contains(id))
                {
                    g.required_trigger_ids.push(*id);
                }
            }
            4 => g.inverted = !g.inverted,
            _ => g.breakable = !g.breakable,
        },
        Entity_Properties::Door(d) => match field % 4 {
            0 => d.size.width = inc(d.size.width),
            1 => d.size.height = inc(d.size.height),
            2 => {
                let rooms: Vec<_> = registry.rooms.keys().collect();
                let i = rooms
                    .iter()
                    .position(|id| *id == &d.target_room_id)
                    .unwrap_or(0);
                d.target_room_id =
                    rooms[(i as i32 + delta).rem_euclid(rooms.len() as i32) as usize].to_string();
            }
            _ => {
                if let Ok(entry) = registry.get(&d.target_room_id) {
                    let doors: Vec<_> = entry
                        .room
                        .entities
                        .iter()
                        .filter_map(|e| {
                            if let Entity_Properties::Door(door) = &e.properties {
                                Some(door.target_door_id.clone())
                            } else {
                                None
                            }
                        })
                        .collect();
                    if !doors.is_empty() {
                        let i = doors
                            .iter()
                            .position(|id| *id == d.target_door_id)
                            .unwrap_or(0);
                        d.target_door_id = doors
                            [(i as i32 + delta).rem_euclid(doors.len() as i32) as usize]
                            .clone();
                    }
                }
            }
        },
        _ => {}
    }
}
fn draw_grid(game: Res<Game_World>, editor: Res<Editor_State>, mut gizmos: Gizmos) {
    let t = game.room.grid.tile_size as f32;
    let p = Vec3::new(
        editor.cursor.x as f32 * t + t / 2.,
        1.,
        editor.cursor.y as f32 * t + t / 2.,
    );
    gizmos.cube(
        Transform::from_translation(p).with_scale(Vec3::new(t, 2., t)),
        Color::srgb(1., 0.87, 0.32),
    );
    for entity in &game.room.entities {
        let (size, color) = match &entity.properties {
            Entity_Properties::Door(d) => (
                Vec3::new(d.size.width as f32, 4., d.size.height as f32),
                Color::srgb(0.2, 0.7, 1.),
            ),
            Entity_Properties::Gate(g) => (
                Vec3::new(g.size.width as f32, 32., g.size.height as f32),
                Color::srgb(0.9, 0.4, 0.2),
            ),
            Entity_Properties::Pressure_Plate(_) => {
                (Vec3::new(28., 4., 28.), Color::srgb(0.9, 0.85, 0.2))
            }
            _ => (Vec3::splat(16.), Color::srgb(0.65, 0.95, 0.55)),
        };
        let position = entity.position.vector();
        gizmos.cube(
            Transform::from_xyz(position.x, size.y / 2., position.y).with_scale(size),
            color,
        );
    }
    if editor.layer == Layer::Collision {
        for (i, value) in game.room.layers.collision.iter().enumerate() {
            if *value == 1 {
                let x = (i % game.room.size.width) as f32 * t;
                let z = (i / game.room.size.width) as f32 * t;
                gizmos.cube(
                    Transform::from_xyz(x + t / 2., 1., z + t / 2.).with_scale(Vec3::new(t, 2., t)),
                    Color::srgb(1., 0.2, 0.2),
                );
            }
        }
    }
    if editor.grid {
        for x in 0..=game.room.size.width {
            gizmos.line(
                Vec3::new(x as f32 * t, 0.2, 0.),
                Vec3::new(x as f32 * t, 0.2, game.room.size.height as f32 * t),
                Color::srgba(1., 1., 0.8, 0.2),
            );
        }
        for y in 0..=game.room.size.height {
            gizmos.line(
                Vec3::new(0., 0.2, y as f32 * t),
                Vec3::new(game.room.size.width as f32 * t, 0.2, y as f32 * t),
                Color::srgba(1., 1., 0.8, 0.2),
            );
        }
    }
}
