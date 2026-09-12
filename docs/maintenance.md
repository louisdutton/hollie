# Maintenance conventions

## Naming and boundaries

Use Ada_Case for owned types and enum members, snake_case for procedures and
variables, and SCREAMING_SNAKE_CASE for true constants. Mutable lookup tables
use snake_case even when application code currently only reads them. Imported
raylib symbols retain the vendor's spelling; owned wrapper aliases follow the
project convention. Resource paths, bone names, clip names, and room wire values
are content contracts, not candidates for mechanical symbol renaming.

Keep storage and reference management in `entity.odin`, pure steering in
`movement.odin`, and the integration of gameplay abilities and effects in
`simulation_movement.odin`. Rendering helpers belong in `rendering*.odin`.
Prefer explicit world arguments for new storage and query APIs. Existing
application systems still share the active world, room, and renderer; a new
package should have a clear responsibility before code is moved into it.

## Entity identity

`World_State` owns its dynamic entity array. Add through `entity_add` and remove
through `entity_remove_at`; direct array mutation bypasses identity assignment
and relationship cleanup. Each entity gets a nonzero `Entity_Id`. IDs are never
reused within a world's lifetime, including after room clearing. Zero is the
empty reference. IDs are scoped to their world and are not persistent map IDs.

Use IDs for relationships retained across updates. `Player.carrying` and
`Holdable.held_by` refer to each other by ID. Removing either participant clears
the remaining relationship. Resolution returns nil for missing entities or the
wrong type.

Pointers returned by entity creation or resolution are borrowed until the next
add, removal, or room teardown. Resolve again after an operation that can change
storage. Saving capacity or an array index does not provide stable identity.
Tests that exercise storage should create their own `World_State` and defer
`world_fini`, avoiding mutation of the application's global world.

## Scene and editor lifetimes

Input handlers request scene changes with `scene_request`. The scene dispatcher
applies the pending change only after the outgoing updater returns. Gameplay
stops processing after a menu requests a change or quit. Quitting cancels a
pending scene load; final application teardown releases the current scene.

Editor entry and teardown both reset to `EDITOR_DEFAULT_STATE`, releasing owned
buffers and clearing borrowed entity pointers. Repeated teardown is safe, and a
new session does not inherit editing flags or references from the previous one.

## Resource ownership

| Owner | Owned resources | Release point |
| --- | --- | --- |
| Application | Font, title music, sound collection | `fini`, before audio/window shutdown |
| UI assets | Textures and fade shader | `ui_assets_fini` |
| Gameplay scene | Registry, loaded source tilemap, models, shaders, render targets | `gameplay_fini` |
| Tilemap package | Deep copy of the active tilemap used by collision and the editor | `tilemap.fini` |
| Room | Room music and active entities/effects | `room_fini` |
| World | Entity array and each gate's trigger list | Entity removal, world clearing, `world_fini` |
| Dialog | Current message rune buffer | Page advancement and `dialog_fini` |

`asset.path` allocates a path string: the caller must delete it after loading the
resource. Resource loaders borrow path arguments; loading a resource does not
transfer ownership of the path. Use a local binding followed by `defer delete`.

`run_frame` reclaims `context.temp_allocator` after update and drawing have both
returned, including any renderer flush at the end of drawing. `fmt.tprintf`
results remain valid during that frame only. Anything retained in world, scene,
or UI state must be copied with the regular allocator. Suspended frames and
frames that request scene changes use the same cleanup boundary.

The gameplay scene owns the source tilemap. `room_state.current_tilemap` borrows
its address. `tilemap.load_tilemap` makes a deep working copy; the editor saves
that copy. Loading another room releases both copies through their respective
owners. Room reload reconstructs gameplay from the loaded source; editor exit
reloads the saved room from disk. Unsaved editor changes are discarded on exit.

Door target strings and dialog messages borrow content. Registry lookup results
and pending room IDs borrow the registry. Release borrowers before their
owners. Scene tweens retain addresses in scene state, so clear them before scene
teardown or reuse. Reset released handles to prevent later teardown from
releasing them again. Animation clips belong to model assets; actors only store
playback state and do not allocate their own frame tables.

## Time and update order

The application reads frame time once. UI and scene tweens receive nonnegative
elapsed seconds. Gameplay clamps this once to `MAX_SIMULATION_DELTA` (0.1 s),
discarding excess time after a stall. All simulation updaters receive that same
`dt`. Physics subdivides body movement into steps of at most `PHYSICS_STEP`
(1/120 s); it is not a separate global fixed-tick simulation.

Gameplay timers use seconds. Imported animation clips use their sampling rate
only when converting elapsed playback time into a pose. Camera smoothing and
knockback damping are exponential so their response is consistent across frame
rates. Keep tests that compare elapsed behavior at multiple frame rates.

`simulation_update` preserves this order:

1. Advance water time and pressure-pad surfaces, then align riders with mounts.
2. Read player intent, advance health timers, and compute player/AI velocities.
3. Update colliders, settle crates before characters, and integrate body motion.
   Ability interactions such as bison ramming happen at physics substeps.
4. End crate drop exemptions after separation and update wakes.
5. Align riders before pressure-plate evaluation; update puzzles and gate
   ejections; align riders again after mounts may have been displaced.
6. Advance animation and remove expired dying entities.

The gameplay scene then updates particles, camera, and dialog. Pausing or editing
skips simulation. UI and scene tweens continue outside that simulation gate;
losing window focus suspends application updates entirely.

Obstacle collection is a read-only query. It returns caller-owned storage that
must be deleted. Drop-exemption state changes happen in
`holdable_update_release_contacts`, so calling a collision query cannot change
subsequent gameplay decisions.

## Coordinates and content

Gameplay `Vec2` positions represent horizontal X/Z coordinates: `position.y`
becomes world Z. Body height is world Y. `geometry_position` performs that
conversion. Colliders are 3D `Aabb` volumes with offsets relative to a body;
footprint-only checks explicitly use horizontal overlap.

Tile coordinates index the room grid; entity positions and collider dimensions
use world units. Convert through tilemap helpers rather than assuming every
quantity is measured in tiles. Model-derived bounds and scaling establish
character colliders and riding headroom.

Room files use the `.json` extension and a JSON5 parser. The typed room contract,
wire conversion, validation, and persistence live in separate tilemap files.
Keep wire names and IDs stable or introduce an explicit migration. Use atomic
saving and surface errors to the editor. Tests should cover malformed content,
round trips, and actual interactions affected by a change.

## Reviewing future changes

Keep commits complete and behaviorally coherent. Use the automated commit hook
for routine verification. Add regression tests for lifetime, timing, content,
and interaction bugs; use isolated worlds and pure helpers where possible.
Formatting and mechanical renames do not need tests that repeat the changed
implementation. Rendering and hardware behavior still require runtime review.
