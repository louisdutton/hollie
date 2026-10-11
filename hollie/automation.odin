package hollie

import "asset"
import "audio"
import "core:encoding/json"
import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strings"
import "graphics"
import "input"
import "tilemap"
import "tween"
import "window"

when ODIN_DEBUG {
	AUTOMATION_DELTA :: f32(1.0 / 60.0)
	AUTOMATION_MAX_FRAMES :: 600

	Automation_Command :: struct {
		id:       u64,
		op:       string,
		room:     string,
		players:  int,
		seed:     u64,
		frames:   int,
		keys:     []input.Key,
		gamepads: []input.Automation_Gamepad,
		capture:  string,
	}

	Automation_Body :: struct {
		id:       Entity_Id,
		position: Vec2,
		velocity: Vec2,
		height:   f32,
		grounded: bool,
	}

	Automation_Player :: struct {
		body:     Automation_Body,
		player:   input.Player_Index,
		mounted:  Entity_Id,
		carrying: Entity_Id,
	}

	Automation_Enemy :: struct {
		body:           Automation_Body,
		move_direction: Vec2,
		move_timer:     f32,
		wait_timer:     f32,
	}

	Automation_Observation :: struct {
		frame:        u64,
		seed:         u64,
		scene:        Scene,
		room:         string,
		entity_count: int,
		players:      [dynamic]Automation_Player,
		enemies:      [dynamic]Automation_Enemy,
	}

	Automation_Response :: struct {
		id:      u64,
		error:   string,
		state:   Automation_Observation,
		capture: string,
	}

	@(private)
	automation := struct {
		enabled:       bool,
		request_path:  string,
		response_path: string,
		capture_path:  string,
		last_id:       u64,
		remaining:     int,
		frame:         u64,
		seed:          u64,
		respond:       bool,
		error:         string,
	}{}

	automation_init :: proc() {
		directory := os.get_env("HOLLIE_CONTROL_DIR", context.allocator)
		defer delete(directory)
		if directory == "" do return
		assert(os.is_dir(directory), "HOLLIE_CONTROL_DIR must be an existing private directory")
		automation.enabled = true
		automation.request_path = fmt.aprintf("%s/request.json", directory)
		automation.response_path = fmt.aprintf("%s/response.json", directory)
		automation.respond = true // Initial ready response, id 0, after the first draw.
		input.automation_enable()
	}

	automation_fini :: proc() {
		delete(automation.request_path)
		delete(automation.response_path)
		delete(automation.capture_path)
	}

	automation_update :: proc() {
		// Keep the window responsive while all simulation/UI time is paused.
		if window.should_close() {
			game.state = .Exiting
			return
		}
		if window.is_resized() {
			design_width = window.get_design_width()
			design_height = window.get_design_height()
		}
		if automation.remaining == 0 && !automation.respond {
			data, read_error := os.read_entire_file(
				automation.request_path,
				context.temp_allocator,
			)
			if read_error == nil {
				command := Automation_Command {
					room    = INITIAL_ROOM_ID,
					players = 1,
					seed    = 42,
				}
				parse_error := json.unmarshal(data, &command, allocator = context.temp_allocator)
				if command.id > automation.last_id {
					automation.last_id = command.id
					automation.respond = true
					automation.error = ""
					if parse_error != nil {
						automation.error = "invalid command JSON"
					} else if command.capture != "" &&
					   (os.base(command.capture) != command.capture ||
							   !strings.has_suffix(command.capture, ".png") ||
							   strings.contains(command.capture, "\x00")) {
						automation.error = "capture must be a plain PNG filename"
					} else {
						automation_apply(command)
						if automation.error == "" && command.capture != "" {
							automation.capture_path = fmt.aprintf(
								"%s/%d-%s",
								os.dir(automation.response_path),
								command.id,
								command.capture,
							)
						}
					}
				}
			}
		}
		if automation.remaining > 0 {
			game.state = .Active
			tween.update(AUTOMATION_DELTA)
			scene_update(&game, AUTOMATION_DELTA)
			if game.state == .Exiting do automation.remaining = 1
			input.automation_end_frame()
			automation.frame += 1
			automation.remaining -= 1
		}
	}

	automation_apply :: proc(command: Automation_Command) {
		switch command.op {
		case "observe":
		case "stop": game.state = .Exiting
		case "step":
			if command.frames < 1 || command.frames > AUTOMATION_MAX_FRAMES {
				automation.error = "frames must be between 1 and 600"
				return
			}
			if !input.automation_set(command.keys, command.gamepads) {
				automation.error = "invalid input state"
				return
			}
			automation.remaining = command.frames
		case "reset":
			if command.players < 1 || command.players > 2 {
				automation.error = "players must be 1 or 2"
				return
			}
			// Reject unknown rooms before tearing down the working session.
			maps := asset.path(tilemap.ROOM_FILE_RESOURCE_DIRECTORY)
			defer delete(maps)
			root := asset.path("")
			defer delete(root)
			registry, registry_error := room_registry_load(maps, root)
			defer destroy_room_registry(&registry)
			defer destroy_room_registry_error(&registry_error)
			if registry_error.kind != .None {
				automation.error = "could not load room registry"
				return
			}
			if _, found := room_registry_find(&registry, command.room); !found {
				automation.error = "unknown room"
				return
			}
			switch game.scene {
			case .Title: unload_title_screen()
			case .Gameplay: gameplay_fini()
			}
			tween.clear()
			audio.music_stop(game.music)
			rand.reset(command.seed)
			input.automation_reset()
			world.next_entity_id = 0 // A reset begins a fresh world lifetime.
			camera_base_zoom = ZOOM_DEFAULT
			camera = {
				zoom = ZOOM_DEFAULT,
			}
			camera_height, camera_grounded_time = 0, 0
			water_time = 0
			game.state = .Active
			game.scene = .Gameplay
			game.pending_scene = nil
			game.player_count = command.players
			gameplay_init(command.room)
			camera_snap_to_target()
			automation.frame = 0
			automation.seed = command.seed
		case: automation.error = "unknown operation"
		}
	}

	automation_observe :: proc() -> Automation_Observation {
		result := Automation_Observation {
			frame   = automation.frame,
			seed    = automation.seed,
			scene   = game.scene,
			players = make([dynamic]Automation_Player, context.temp_allocator),
			enemies = make([dynamic]Automation_Enemy, context.temp_allocator),
		}
		if game.scene != .Gameplay do return result
		result.room = gameplay_get_current_room()
		result.entity_count = len(world.entities)
		for entity in world.entities {
			#partial switch e in entity {
			case Player:
				mounted: Entity_Id
				if animal := riding_animal_for_player(e.index); animal != nil do mounted = animal.entity_id
				append(
					&result.players,
					Automation_Player {
						body = {e.entity_id, e.position, e.velocity, e.height, e.grounded},
						player = e.index,
						mounted = mounted,
						carrying = e.carrying,
					},
				)
			case Enemy:
				append(
						&result.enemies,
						Automation_Enemy {
							body = {e.entity_id, e.position, e.velocity, e.height, e.grounded},
							move_direction = e.move_direction,
							move_timer = e.move_timer,
							wait_timer = e.wait_timer,
						},
					)
			}
		}
		return result
	}

	automation_capture :: proc() {
		if !automation.enabled || automation.remaining != 0 || automation.capture_path == "" do return
		if !graphics.capture_screenshot(
			strings.clone_to_cstring(automation.capture_path, context.temp_allocator),
		) {
			automation.error = "could not write screenshot"
		}
	}

	// Acknowledgements follow EndDrawing and any requested back-buffer capture.
	automation_after_draw :: proc() {
		if !automation.enabled || !automation.respond || automation.remaining != 0 do return
		defer free_all(context.temp_allocator)
		response := Automation_Response {
			id      = automation.last_id,
			error   = automation.error,
			state   = automation_observe(),
			capture = automation.capture_path,
		}
		data, encode_error := json.marshal(
			response,
			{use_enum_names = true},
			context.temp_allocator,
		)
		assert(encode_error == nil, "could not encode automation response")
		temp_path := fmt.tprintf("%s.tmp", automation.response_path)
		assert(os.write_entire_file(temp_path, data) == nil, "could not write automation response")
		assert(
			os.rename(temp_path, automation.response_path) == nil,
			"could not publish automation response",
		)
		automation.respond = false
		delete(automation.capture_path)
		automation.capture_path = ""
	}
}
