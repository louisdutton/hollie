# Robust Content-Building Roadmap

## Goal

Make Hollie capable of producing rooms, characters, encounters, puzzles, and dialogue safely and quickly without requiring routine changes to gameplay code.

The target workflow is:

1. Create or duplicate a room in the editor.
2. Select registered content such as enemies, NPCs, items, dialogue, and mechanisms.
3. Configure relationships and properties in the editor.
4. Validate the content and receive actionable errors before playing it.
5. Save, reload, and ship it without hand-editing code or relying on undocumented conventions.

## Definition of done

- [ ] A new room can be added without editing an Odin enum, switch, or hardcoded room list.
- [ ] Enemy, NPC, holdable, and interactive variants are selected through stable content IDs.
- [ ] Dialogue is authored outside `room.odin` and referenced by ID.
- [ ] Entity data has typed, entity-specific properties rather than one flat collection of mostly irrelevant fields.
- [ ] Editable source content uses JSON5 file DTOs that are explicit, typed, deterministic, and covered by round-trip tests.
- [ ] Invalid syntax, missing assets, broken room links, duplicate IDs, and invalid mechanism links fail validation with the file path and actionable context.
- [ ] The editor can author every property required by the runtime and never presents fields that the runtime ignores.
- [ ] Reusable conditions and actions can express at least the existing plate/gate puzzle plus dialogue, encounter, and room-state interactions.
- [ ] All content serialization, validation, registry, and runtime integration tests pass.
- [ ] One representative room is built entirely through the finished content workflow as an end-to-end proof.
- [ ] The authoring workflow and content formats are documented.

## Working principles

- Stable string IDs are content-facing; enum ordinals and array indexes are implementation details.
- Spatial layout belongs in map files; reusable definitions belong in content registries.
- JSON5 file DTOs contain persistence data only; runtime structures own loaded assets and mutable state.
- Built-in `core:encoding/json` handles syntax; Hollie code handles entity discrimination, defaults, conversion, and semantic validation.
- Content is validated before runtime systems consume it.
- Loading errors are returned with context rather than silently replaced with defaults.
- The editor and runtime consume the same schemas and registries.
- New abstractions should first prove themselves against real content needs.
- Existing maps remain playable after each coordinated code-and-content change.

## Chosen persistence model

- JSON5 is the canonical editable source format for rooms and future content registries.
- Room source files live under `res/maps/` and use the `<room-id>.json` naming convention.
- File DTOs are marshalled and unmarshalled with Odin's built-in reflection-based JSON package.
- File DTOs are converted into separate runtime structures after successful validation and ID resolution.
- Entity records use an explicit stable type discriminator and typed, entity-specific property data.
- The in-game, gamepad-first editor remains the primary room authoring surface.
- Third-party map formats may be supported later through optional one-way importers, but are not canonical.
- Format changes update all shipped content and tests together; no compatibility or migration framework is maintained.

## Milestone 0 — Restore a trustworthy baseline

### Tests and current behavior

- [x] Reconcile `hollie/tilemap/test.map` with `serde_test.odin` so the current serialization and deserialization tests agree on entity types and layer dimensions.
- [x] Replace exact whole-file fixture comparison where appropriate with focused field assertions plus a serialize-deserialize round-trip test.
- [x] Add coverage for every current entity type and every optional entity field.
- [x] Add explicit tests for comments, empty sections, default values, malformed rectangles, invalid numbers, and truncated entity records.
- [x] Add a test that loads every file under `res/maps/`.
- [x] Record the intended current behavior of all three rooms before changing the format.

### Repeatable developer checks

- [x] Add `hollie:check`, `hollie:test`, and `hollie:validate-content` devenv tasks.
- [x] Make the full non-interactive check run the compiler, automated tests, and content validation.
- [x] Document a short manual smoke test using `devenv tasks run hollie:run`.

### Exit criteria

- [x] `odin check hollie -debug` passes.
- [x] All existing automated tests pass.
- [x] All current maps load and round-trip without unintended changes.
- [ ] Current room transitions, enemies, NPC interaction, holdables, and the Olivewood puzzle are manually verified.

## Milestone 1 — Move rooms to a typed JSON5 content contract

### File/runtime boundary

- [x] Add a narrow serde test proving the intended JSON5 representation for enums/type names, optional fields, arrays, and entity discrimination.
- [x] Define `Room_File` and supporting metadata/layer DTOs containing only persisted values.
- [x] Keep renderer textures, loaded audio, allocators, caches, and mutable room state out of file DTOs.
- [x] Add explicit conversion from validated file DTOs into runtime `TileMap` data.
- [x] Add explicit conversion from editable/runtime room data back into file DTOs.
- [x] Centralize JSON5 marshal options for readable, deterministic output.
- [x] Choose and consistently apply the room filename extension and content directory convention.

### Typed entity DTOs

- [x] Give every placed entity a stable instance ID, stable type discriminator, position, and type-specific properties.
- [ ] Add typed file data for:
  - [x] player spawns;
  - [x] enemy spawns;
  - [x] NPC spawns;
  - [x] holdables;
  - [x] doors;
  - [x] pressure plates;
  - [x] gates.
- [x] Implement the small discriminated decode/encode layer needed around JSON's untagged union behavior.
- [x] Replace numeric entity types and positional fields with stable names and named properties.
- [x] Define required fields, optional fields, and defaults once for each entity type.
- [x] Reject unknown entity type names and report unsupported or unknown properties clearly.

### JSON5 serde and diagnostics

- [x] Marshal and unmarshal file DTOs with `core:encoding/json`; do not maintain a custom tokenizer or general parser.
- [x] Support comments and trailing commas on input through JSON5.
- [ ] Add tests for missing required fields, defaults, unknown entity types, malformed JSON5, and type mismatches.
- [x] Add deterministic JSON5 semantic round-trip tests for every entity DTO.
- [x] Return load failures with the file path and a useful parse, conversion, or validation reason.
- [x] Verify layer lengths against room width and height.
- [x] Ensure allocations from failed and successful loads have explicit ownership and cleanup.
- [x] Validate after every JSON5 load and before every JSON5 save.
- [x] Save JSON5 maps atomically so an interrupted save cannot destroy the previous file.

### Reuse and extend content validation

- [x] Keep the validator callable independently of the graphical game.
- [x] Validate unique room IDs.
- [ ] Validate that referenced assets exist and have an allowed type.
- [x] Validate door target rooms and destination markers.
- [x] Validate unique local entity/mechanism IDs where uniqueness is required.
- [x] Validate mechanism links and report missing or incompatible endpoints.
- [x] Validate entities are within permitted room bounds.
- [ ] Adapt every validation rule to operate on the JSON5 file/runtime boundary without duplicating schema knowledge.
- [ ] Treat warnings and errors distinctly, with errors producing a non-zero exit code.

### Coordinated conversion

- [ ] Convert all three shipped maps to JSON5 in one coordinated content change.
- [ ] Switch runtime room loading to the JSON5 DTO pipeline.
- [ ] Switch in-game editor saving and reloading to the same JSON5 DTO pipeline.
- [ ] Switch the standalone validator and shipped-map tests to discover and read JSON5 rooms.
- [ ] Verify semantic parity for room metadata, tile layers, every entity, and every entity property.
- [ ] Remove the legacy positional serializer, parser, fixtures, and tests only after parity checks pass.

### Exit criteria

- [ ] No runtime-only resource or state is serialized into room files.
- [ ] Corrupt or semantically invalid content cannot reach runtime assertions or unchecked indexing.
- [ ] Every converted map passes the standalone validator.
- [ ] Every converted map produces deterministic JSON5 and round-trips without semantic changes.
- [ ] Runtime loading, editor saving, and validation all use the same file DTO definitions.
- [ ] The legacy custom syntax and parser are no longer used.

## Milestone 2 — Introduce a data-driven content catalog

### Room registry

- [ ] Replace the `Room` enum and `ROOM_PATHS` table with a room registry keyed by `room_id`.
- [ ] Discover room files from the content tree or a generated manifest without requiring gameplay-code edits.
- [ ] Store the current and pending room as stable room IDs.
- [ ] Resolve door transitions through the room registry.
- [ ] Populate editor room choices from the same registry.
- [ ] Validate duplicate IDs and room/file mismatches during catalog loading.

### Archetype registries

- [ ] Apply the JSON5 DTO conventions to a common content-definition format and loading lifecycle.
- [ ] Add enemy archetypes containing animations, health, movement, combat values, collider, and behavior ID.
- [ ] Add NPC archetypes containing appearance, animations, collider, movement behavior, and default dialogue ID.
- [ ] Add holdable/item archetypes containing texture, collider, interaction behavior, and future-facing tags.
- [ ] Keep player configuration separate but express animation and combat tuning through the same data-loading conventions where useful.
- [ ] Reference archetypes from map entities by stable ID.
- [ ] Cache shared textures and animations so repeated archetypes do not load duplicate GPU resources per entity.
- [ ] Define ownership and unloading rules for catalog strings, arrays, audio, textures, and animations.

### Convert existing content

- [ ] Register goblin, skeleton, and human enemy archetypes.
- [ ] Make the Desert enemy markers actually select skeletons through map data.
- [ ] Register the existing NPC and wood holdable.
- [ ] Remove runtime defaults that silently turn all enemies into goblins or all NPCs into the same human.
- [ ] Report unknown archetype IDs as validation errors.

### Exit criteria

- [ ] Adding a fourth room requires only content files.
- [ ] Adding a stat or visual variant of an existing enemy requires only an archetype and map selection.
- [ ] Runtime and editor resolve exactly the same room and archetype IDs.
- [ ] Shared archetype assets are loaded and unloaded once through a clear ownership model.

## Milestone 3 — Make narrative and interaction content authorable

### Dialogue data

- [ ] Move the hardcoded test dialogue out of `room.odin`.
- [ ] Create a dialogue registry keyed by stable dialogue ID.
- [ ] Support the current linear sequence of speaker/text messages first.
- [ ] Allow an NPC instance to override its archetype's default dialogue ID.
- [ ] Validate speaker references and dialogue IDs.
- [ ] Add tests for Unicode, empty dialogue, missing dialogue, and multi-page progression.
- [ ] Defer branching dialogue until a concrete content requirement needs it.

### Reusable condition/action mechanism

- [ ] Define stable instance IDs for addressable entities in a room.
- [ ] Define a small signal vocabulary, initially including room entered, plate changed, interaction, entity defeated, and dialogue completed.
- [ ] Define composable conditions including all/any signals, player count, and boolean room flags.
- [ ] Define a focused first set of actions including open/close gate, enable/disable entity, start dialogue, spawn encounter, set flag, and transition room.
- [ ] Reimplement pressure-plate-to-gate behavior using the shared mechanism.
- [ ] Preserve support for `requires_both` through a general player-count condition rather than plate-specific runtime branching.
- [ ] Define deterministic update ordering and prevent action loops.
- [ ] Add debug visualization for sources, targets, active conditions, and fired actions.

### State scope

- [ ] Define which flags reset on room reload, room re-entry, new game, and application restart.
- [ ] Implement room-session state first.
- [ ] Keep persistent quest/save state out of the initial mechanism unless required by the proof content.

### Exit criteria

- [ ] The existing gate puzzle uses the general mechanism with no special plate/gate coupling in its update loop.
- [ ] An NPC can start different dialogue based solely on content configuration.
- [ ] A room can trigger an encounter and react to its completion without a room-specific Odin function.

## Milestone 4 — Turn the editor into the primary authoring surface

### Schema-driven UI

- [ ] Generate entity palettes from registered entity types and archetypes.
- [ ] Generate property controls from the same field definitions used for loading and validation.
- [ ] Remove hardcoded room, door-name, texture-path, tile, and entity lists where registries can supply them.
- [ ] Support text, number, boolean, enum/ID reference, dimensions, list, and entity-reference fields.
- [ ] Make gate requirements and other mechanism links fully editable.
- [ ] Show invalid and unresolved references inline.
- [ ] Ensure every editable field affects runtime behavior after save/reload.

### Room workflow

- [ ] Create a new room from a valid template.
- [ ] Duplicate an existing room under a new ID.
- [ ] Edit room ID, display name, music, tileset, camera bounds, and collision bounds.
- [ ] Resize a room with an explicit crop/expand preview.
- [ ] Place and name player spawn points independently of doors.
- [ ] Select a playtest spawn and reload quickly into it.
- [ ] Track dirty state and confirm before discarding unsaved changes.
- [ ] Show save success and detailed save/validation failures in the UI.
- [ ] Keep a recoverable backup or use atomic replacement when saving.

### Mechanism authoring

- [ ] Display instance IDs and links in the world view.
- [ ] Provide source, condition, target, and action selection without manual numeric ID coordination.
- [ ] Highlight dangling, duplicated, and cyclic links.
- [ ] Add a live debug panel for current flags, signals, and action history.

### Exit criteria

- [ ] The representative proof room can be built without hand-editing a map or Odin file.
- [ ] Saving invalid content is blocked with an actionable explanation.
- [ ] Editor save/reload preserves every supported property.

## Milestone 5 — Make extension predictable for programmers

### Runtime structure

- [ ] Split the central entity update/draw logic into focused systems when doing so removes repeated type switches.
- [ ] Define the minimal integration points for a new entity type: schema, loader/factory, update behavior, renderer, validator, and editor metadata.
- [ ] Centralize common character movement, combat, animation, collision, and lifetime behavior.
- [ ] Separate content definition data from mutable runtime state.
- [ ] Add explicit entity destruction hooks for owned resources and references.
- [ ] Avoid raw pointers that can be invalidated when the dynamic entity array reallocates; adopt stable handles or another documented storage strategy.

### Extension proof

- [ ] Add one new interactive entity type using the documented extension points.
- [ ] Measure how many files and switches must change and simplify the extension path if it remains scattered.
- [ ] Add a focused integration test for spawning, updating, saving, loading, and destroying the new type.

### Exit criteria

- [ ] The extension guide accurately describes all required integration points.
- [ ] A new entity type does not require searching the entire codebase for switches to update.
- [ ] Entity references remain stable through spawning and removal.

## Milestone 6 — Prove and document the production workflow

### End-to-end proof room

- [ ] Build a new room using only registered content and the editor.
- [ ] Include at least two enemy archetypes.
- [ ] Include an NPC with external dialogue.
- [ ] Include a holdable/item archetype.
- [ ] Include a multi-source condition and at least two different actions.
- [ ] Include working entry and exit links to existing rooms.
- [ ] Run the validator and full automated test suite.
- [ ] Playtest in both one-player and two-player modes.

### Documentation

- [ ] Document the content directory layout and naming conventions.
- [ ] Document how to create, duplicate, validate, and playtest a room.
- [ ] Document each entity type and its properties.
- [ ] Document archetype creation and asset requirements.
- [ ] Document conditions, actions, state lifetimes, and debugging tools.
- [ ] Document the current content contract and how intentional format changes should update shipped content and tests together.
- [ ] Add minimal valid example files suitable for copying.

### Exit criteria

- [ ] A contributor unfamiliar with the implementation can create and connect a small room by following the documentation.
- [ ] The proof room survives save, reload, validation, and a release-mode run.
- [ ] No proof-room-specific runtime code exists.

## Cross-cutting test matrix

- [ ] Unit tests cover parsing, serialization, registry resolution, validation rules, conditions, and actions.
- [x] Legacy-format round-trip tests cover every currently supported entity and property type.
- [ ] JSON5 DTO round-trip tests cover every supported entity and property type.
- [x] Golden fixtures are used only where exact output stability matters.
- [ ] Integration tests load every shipped content file and instantiate each registered archetype.
- [ ] Negative fixtures cover corrupt syntax, missing assets, unknown IDs, broken doors, invalid links, and duplicates.
- [ ] Memory tracking covers repeated room load/unload and editor save/reload cycles.
- [ ] Manual smoke tests cover one-player, two-player, editor entry/exit, room transitions, dialogue, combat, carrying, and mechanisms.

## Recommended implementation order

1. Milestone 0: restore green tests and establish the repeatable checks.
2. Milestone 1: introduce JSON5 file DTOs, convert all rooms, and retire the positional parser.
3. Milestone 2: replace hardcoded rooms and variants with registries.
4. Milestone 3 dialogue: externalize current narrative content.
5. Milestone 4 schema-driven editor work needed to author the new data.
6. Milestone 3 mechanisms: generalize interactions using concrete editor use cases.
7. Milestone 5: simplify runtime extension based on pressure exposed by the new content model.
8. Milestone 6: build the proof room, close workflow gaps, and document the result.

## Explicit non-goals for the first pass

- [ ] Do not build a general-purpose visual scripting language.
- [ ] Do not add branching quests, inventory, loot tables, localization, or save-game persistence without a concrete content requirement.
- [ ] Do not replace the renderer, input layer, or scene framework as part of the content work.
- [ ] Do not adopt a full ECS solely to remove type switches; stable content IDs and reliable authoring come first.
- [ ] Do not serialize runtime `TileMap` structures, GPU/audio handles, caches, or mutable state directly.
- [ ] Do not build a general-purpose JSON schema framework or custom JSON parser around the built-in serde package.
- [ ] Do not make a third-party desktop map editor part of the canonical gamepad-first authoring workflow.
- [ ] Do not build backward-compatibility or migration machinery while all shipped content can be updated with the code.

## Progress tracking

When starting a task:

- Check its dependencies and relevant exit criteria.
- Add or update a test before changing a serialized contract.
- Update all affected shipped maps and their tests in the same change as a content-format change.
- Mark the checkbox only after automated verification and the relevant manual smoke test.
- Record intentional scope changes in this file so the roadmap remains authoritative.
