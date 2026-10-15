use super::*;

#[cfg(test)]
mod movement {
    use super::*;
    fn game() -> Game_World<'static> {
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
    fn game() -> Game_World<'static> {
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
        assert!(game.actors[plates[0].0].puzzle.active);
        assert!(game.actors[plates[1].0].puzzle.active);
        let gate = game
            .actors
            .iter()
            .position(|a| matches!(&a.properties,Entity_Properties::Gate(g) if !g.breakable))
            .unwrap();
        assert!(game.actors[gate].puzzle.open);
        game.actors[crate_index].held_by = Some(game.actors[player].entity);
        game.puzzles();
        assert!(!game.actors[plates[0].0].puzzle.active);
        assert!(!game.actors[gate].puzzle.open);
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
        assert_eq!(game.actors[player].carrying, Some(game.actors[item].entity));
        assert_eq!(game.actors[item].held_by, Some(game.actors[player].entity));
        game.sync_relationships();
        game.interact(player);
        assert!(game.actors[player].carrying.is_none());
        assert!(game.actors[item].held_by.is_none());
        assert_eq!(
            game.actors[item].release_player,
            Some(game.actors[player].entity)
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
        assert_eq!(
            game.actors[player].mounted,
            Some(game.actors[animal].entity)
        );
        for _ in 0..30 {
            game.step(default(), STEP).unwrap();
        }
        assert!(!game.actors[player].body.grounded);
        assert!(game.actors[player].body.height > game.actors[animal].body.height);
    }
    fn carrying_game() -> (Game_World<'static>, usize, usize) {
        let mut game = game();
        game.reset("demo", 1, 42).unwrap();
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
        game.actors[player].body.position = Vec2::new(146., 204.);
        game.actors[player].carrying = Some(game.actors[item].entity);
        game.actors[item].held_by = Some(game.actors[player].entity);
        (game, player, item)
    }
    #[test]
    fn release_adds_impulse_to_rising_and_falling_carrier_momentum() {
        for vertical in [140., -100.] {
            let (mut game, player, item) = carrying_game();
            game.actors[player].body.height = 40.;
            game.actors[player].body.grounded = false;
            game.actors[player].body.vertical_velocity = vertical;
            game.actors[player].body.velocity = Vec2::new(30., -50.);
            game.actors[player].locomotion.facing = -Vec2::Y;
            game.interact(player);
            assert!(game.actors[item].held_by.is_none());
            assert_eq!(game.actors[item].body.velocity, Vec2::new(30., -95.));
            assert_eq!(game.actors[item].body.vertical_velocity, vertical + 15.);
        }
    }
    #[test]
    fn simultaneous_jump_and_throw_inherits_the_jump() {
        let (mut game, player, item) = carrying_game();
        game.step(
            [
                Player_Input {
                    jump: true,
                    interact: true,
                    ..default()
                },
                default(),
            ],
            STEP,
        )
        .unwrap();
        assert!(game.actors[item].held_by.is_none());
        assert!(
            (game.actors[player].body.vertical_velocity - (JUMP_SPEED - GRAVITY * STEP)).abs()
                < 0.001
        );
        assert!(
            (game.actors[item].body.vertical_velocity
                - game.actors[player].body.vertical_velocity
                - 15.)
                .abs()
                < 0.001
        );
    }
    #[test]
    fn release_translates_the_last_pose_with_the_carrier() {
        let (mut game, player, item) = carrying_game();
        let old = Vec3::new(480., 0., 440.);
        let offset = Vec3::new(0., 35., 4.);
        game.actors[item].attachment.held_anchor = Some(old + offset);
        game.actors[item].attachment.held_origin = Some(old);
        game.actors[player].body.position += Vec2::new(8., 10.);
        game.actors[player].body.height = 20.;
        let current = Vec3::new(
            game.actors[player].body.position.x,
            20.,
            game.actors[player].body.position.y,
        );
        game.interact(player);
        assert!(game.actors[item].held_by.is_none());
        let released = Vec3::new(
            game.actors[item].body.position.x,
            game.actors[item].body.height,
            game.actors[item].body.position.y,
        );
        assert_eq!(released, current + offset);
    }
    fn mounted_game() -> (Game_World<'static>, usize, usize) {
        let mut game = game();
        game.reset("demo", 1, 42).unwrap();
        let player = game
            .actors
            .iter()
            .position(|a| a.player() == Some(0))
            .unwrap();
        let animal = game
            .actors
            .iter()
            .position(|a| a.kind() == Some(Character_Kind::Horse))
            .unwrap();
        let origin = Vec3::new(680., 0., 464.);
        game.actors[animal].body.position = Vec2::new(origin.x, origin.z);
        game.actors[animal].locomotion.facing = Vec2::Y;
        game.actors[animal].mounted = Some(game.actors[player].entity);
        game.actors[player].mounted = Some(game.actors[animal].entity);
        game.actors[player].attachment.mount_time = 0.4;
        game.actors[player].body.position = game.actors[animal].body.position;
        game.actors[player].body.height = 14.;
        game.actors[player].body.grounded = false;
        game.actors[player].attachment.riding_anchor = Some(origin + Vec3::new(1., 14., 2.));
        game.actors[player].attachment.riding_origin = Some(origin);
        (game, player, animal)
    }
    #[test]
    fn dismount_releases_from_the_animated_saddle_without_teleporting() {
        let (mut game, player, animal) = mounted_game();
        game.actors[animal].body.position += Vec2::new(2., 1.);
        game.interact(player);
        assert!(game.actors[player].mounted.is_none());
        assert_eq!(game.actors[player].body.position, Vec2::new(683., 467.));
        assert_eq!(game.actors[player].body.height, 14.);
        assert_eq!(game.actors[player].body.velocity, Vec2::X * 70.);
        assert_eq!(game.actors[player].body.vertical_velocity, JUMP_SPEED);
        assert!(game.actors[animal].locomotion.coasting);
    }
    #[test]
    fn airborne_dismount_preserves_mount_momentum_and_caps_sideways_boost() {
        let (mut game, player, animal) = mounted_game();
        game.actors[animal].body.height = 40.;
        game.actors[animal].body.grounded = false;
        game.actors[animal].body.velocity = Vec2::Y * 100.;
        game.actors[animal].body.vertical_velocity = 80.;
        game.actors[player].body.height = 54.;
        game.interact(player);
        assert!(game.actors[player].mounted.is_none());
        assert_eq!(game.actors[player].body.height, 54.);
        assert_eq!(game.actors[player].body.vertical_velocity, JUMP_SPEED + 80.);
        assert!((game.actors[player].body.velocity.length() - 100.).abs() < 0.001);
        assert!(
            game.actors[player].body.velocity.x > 0. && game.actors[player].body.velocity.y > 0.
        );
    }
    #[test]
    fn blocked_dismount_keeps_the_rider_attached() {
        let (mut game, player, _) = mounted_game();
        game.room.layers.collision.fill(1);
        let before = game.observation();
        game.interact(player);
        assert_eq!(game.observation(), before);
    }
    #[test]
    fn dismount_flight_keeps_speed_and_steers_until_landing() {
        let (mut game, player, _) = mounted_game();
        game.interact(player);
        for _ in 0..6 {
            game.step(default(), STEP).unwrap();
        }
        assert!((game.actors[player].body.velocity.length() - 70.).abs() < 0.001);
        let before = game.actors[player].body.velocity;
        game.update_motion(
            [
                Player_Input {
                    movement: Vec2::new(-1., 1.).normalize(),
                    ..default()
                },
                default(),
            ],
            STEP,
        );
        assert!((game.actors[player].body.velocity.length() - 70.).abs() < 0.001);
        assert_ne!(game.actors[player].body.velocity, before);
        game.actors[player].body.grounded = true;
        game.update_motion(default(), STEP);
        assert!(!game.actors[player].locomotion.dismount_air_control);
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
