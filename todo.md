# Robust Room-Building Roadmap

## Goal

Make Hollie capable of producing rooms safely and quickly while keeping characters, items, dialogue, and behavior definitions concise, strongly typed, and intentionally controlled in Odin.

The target workflow is:

1. Create or duplicate a room in the editor.
2. Select code-defined enemies, NPCs, items, dialogue, and mechanisms through typed editor choices.
3. Configure relationships and properties in the editor.
4. Validate the content and receive actionable errors before playing it.
5. Save, reload, and ship it without hand-editing code or relying on undocumented conventions.

## Definition of done

- [ ] A new room can be added without editing an Odin enum, switch, or hardcoded room list.
- [ ] Content variants reuse existing semantic Odin enums where possible and have concise code-owned definitions.
- [ ] Readable variant names in room JSON are converted to typed values during decoding; unchecked content strings do not reach gameplay code.
- [ ] Dialogue is authored in a dedicated Odin content module outside `room.odin` and referenced by a typed ID.
- [ ] Entity data has typed, entity-specific properties rather than one flat collection of mostly irrelevant fields.
- [ ] Rooms are the only editable file-driven game content; their JSON DTOs are explicit, typed, and deterministic.
- [ ] Invalid syntax, missing assets, broken room links, duplicate IDs, and invalid mechanism links fail validation with the file path and actionable context.
- [ ] The editor can author every property required by the runtime and never presents fields that the runtime ignores.
- [ ] Reusable conditions and actions can express at least the existing plate/gate puzzle plus dialogue, encounter, and room-state interactions.
- [ ] Focused unit tests pass for pure room serialization, validation, and typed variant conversion logic.
- [ ] One representative room is built entirely through the finished content workflow as an end-to-end proof.
- [ ] The authoring workflow and content formats are documented.

## Working principles

- Dynamic room IDs and placed-instance IDs remain strings because rooms are discovered from files.
- Reuse an existing semantic type before introducing another ID or enum; keep one canonical representation and one source of choices.
- Closed sets with multiple real values use Odin enums; single-variant categories do not carry redundant IDs solely for possible future variants.
- Spatial layout and per-room configuration belong in room files; reusable definitions belong in typed Odin modules.
- Room file DTOs contain persistence data only; runtime structures own loaded assets and mutable state.
- Built-in `core:encoding/json` handles syntax; Hollie code handles entity discrimination, defaults, conversion, and semantic validation.
- Human-readable enum names may appear as strings on the wire, but they are parsed into typed values at the serde boundary and encoded back explicitly.
- Content is validated before runtime systems consume it.
- Loading errors are returned with context rather than silently replaced with defaults.
- The editor and runtime consume the same room schema, room registry, enums, and Odin definition tables.
- Automated tests are reserved for pure library behavior such as parsing, conversion, serialization, and validation; gameplay and editor workflows are verified by quick playtests.
- New abstractions should first prove themselves against real content needs.
- Existing maps remain playable after each coordinated code-and-content change.

## Chosen persistence model

- JSON is the canonical editable source format for rooms only; the reader remains JSON5-permissive for comments and trailing commas.
- Room source files live under `res/maps/` and use the `<room-id>.json` naming convention.
- File DTOs are marshalled and unmarshalled with Odin's built-in reflection-based JSON package.
- File DTOs are converted into separate runtime structures after successful validation and ID resolution.
- Entity records use an explicit stable type discriminator and typed, entity-specific property data.
- Reusable enemies, NPCs, holdables, dialogue, and behaviors are not loaded from data files; they are defined and compiled in Odin.
- The in-game, gamepad-first editor remains the primary room authoring surface.
- Third-party map formats may be supported later through optional one-way importers, but are not canonical.
- Format changes update all shipped content and focused pure-contract tests together; no compatibility or migration framework is maintained.

## Milestone 0 — Restore a trustworthy baseline

### Tests and current behavior

- [x] Reconcile `hollie/tilemap/test.map` with `serde_test.odin` so the current serialization and deserialization tests agree on entity types and layer dimensions.
- [x] Replace exact whole-file fixture comparison where appropriate with focused field assertions plus a serialize-deserialize round-trip test.
- [x] Add coverage for every current entity type and every optional entity field.
- [x] Add explicit tests for comments, empty sections, default values, malformed rectangles, invalid numbers, and truncated entity records.
- [x] Keep shipped-room loading in the standalone content validator rather than the unit-test suite.
- [x] Record the intended current behavior of all three rooms before changing the format.

### Repeatable developer checks

- [x] Add `hollie:check`, `hollie:test`, and `hollie:validate-content` devenv tasks.
- [x] Make the full non-interactive check run the compiler, automated tests, and content validation.
- [x] Document a short manual smoke test using `devenv tasks run hollie:run`.

### Exit criteria

- [x] `odin check hollie -debug` passes.
- [x] All existing automated tests pass.
- [x] All current maps pass standalone content validation.
- [ ] Current room transitions, enemies, NPC interaction, holdables, and the Olivewood puzzle are manually verified.

## Milestone 1 — Move rooms to a typed JSON contract

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
- [x] Add typed file data for:
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
- [x] Replace the enemy archetype string with the existing character-kind enum during entity-property decoding, and remove redundant single-variant NPC and holdable archetype fields.

### JSON serde and diagnostics

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

- [x] Convert all three shipped maps to JSON in one coordinated content change.
- [x] Switch runtime room loading to the JSON DTO pipeline.
- [x] Switch in-game editor saving and reloading to the same JSON DTO pipeline.
- [x] Switch the standalone validator to discover and read JSON rooms.
- [x] Verify semantic parity for room metadata, tile layers, every entity, and every entity property.
- [x] Remove the legacy positional serializer, parser, fixtures, and tests after parity checks pass.

### Exit criteria

- [x] No runtime-only resource or state is serialized into room files.
- [ ] Corrupt or semantically invalid content cannot reach runtime assertions or unchecked indexing.
- [x] Every converted map passes the standalone validator.
- [x] Focused pure DTO tests produce deterministic JSON and round-trip without semantic changes.
- [x] Runtime loading, editor saving, and validation all use the same file DTO definitions.
- [x] The legacy custom syntax and parser are no longer used.

## Milestone 2 — Introduce strongly typed Odin content definitions

### Room registry

- [x] Replace the `Room` enum and `ROOM_PATHS` table with a room registry keyed by `room_id`.
- [x] Discover room files from the content tree without requiring gameplay-code edits.
- [x] Store the current and pending room as stable room IDs.
- [x] Resolve door transitions through the room registry.
- [x] Populate editor room choices from the same registry.
- [x] Validate duplicate IDs and room/file mismatches during catalog loading.

### Typed variants at the room boundary

- [x] Move the existing `NPC_Race` enum to a dependency-light package usable by serde, runtime, and editor code and rename it to `Character_Kind` to reflect its shared role.
- [x] Decode room-file enemy names such as `Goblin`, `Skeleton`, and `Human` directly from the corresponding enum member names.
- [x] Encode enum member names directly so code and room files share one canonical representation.
- [x] Report an unknown character variant as a path-aware decode error before semantic validation or runtime conversion.
- [x] Replace the flat runtime `archetype_id` string with the typed character variant needed by enemies.
- [x] Remove `archetype_id` and empty `properties` objects from NPC and holdable room/runtime data while each has only one valid variant.
- [x] Populate editor enemy choices from the same enum-backed mapping; do not maintain a second list of string IDs.
- [x] Avoid introducing NPC or holdable variant enums before a second real variant requires a choice.

### Code-owned definitions

- [x] Dispatch enemy-specific animations exhaustively from the existing character-kind enum while keeping shared enemy stats in one constructor.
- [x] Keep the single human NPC configuration in one code-owned spawn path while its collider and movement defaults remain shared.
- [x] Keep the single wood holdable configuration in one code-owned spawn path while its collider defaults remain shared.
- [x] Keep player configuration separate while using the same shared character primitives where useful.
- [x] Make enemy variant dispatch exhaustive so adding an enum member requires explicit spawn handling.
- [ ] Cache shared textures and animations so repeated definitions do not load duplicate GPU resources per entity.
- [ ] Define ownership and unloading rules for shared definition assets and runtime instances.

### Convert existing content

- [x] Reuse the existing goblin, skeleton, and human enum values for enemy definitions.
- [x] Make the Desert enemy markers actually select skeletons through map data.
- [x] Define the existing human NPC and wood holdable once in Odin without redundant room identifiers.
- [x] Remove the runtime default that silently turns all enemies into goblins.
- [x] Remove the temporary `wood` texture switch from `room.odin` in favor of the single code-owned holdable definition.

### Exit criteria

- [x] Adding a fourth room requires only a room JSON file.
- [x] Adding another enemy variant is an intentional enum/definition change in Odin and requires no stringly typed runtime branching.
- [x] No current closed-set content variant remains an unchecked runtime string.
- [x] Runtime, editor, and room files use the same character-kind enum names.
- [ ] Shared definition assets are loaded and unloaded once through a clear ownership model.

## Milestone 3 — Make typed narrative and room interactions authorable

### Dialogue definitions

- [x] Move the hardcoded test dialogue out of `room.odin`.
- [ ] Define `Dialogue_ID` and code-owned dialogue definitions in a focused Odin module.
- [ ] Support the current linear sequence of speaker/text messages first.
- [ ] Allow an NPC room instance to override its kind's default typed dialogue ID.
- [ ] Decode any dialogue name present in a room directly into `Dialogue_ID` and reject unknown names at the file boundary.
- [ ] Make definition lookup exhaustive and validate speaker references.
- [ ] Unit test pure dialogue definition lookup and validation for Unicode, empty dialogue, and missing dialogue.
- [ ] Playtest multi-page dialogue progression.
- [ ] Defer branching dialogue until a concrete content requirement needs it.

### Reusable condition/action mechanism

- [ ] Define stable instance IDs for addressable entities in a room.
- [ ] Define typed signal enums, initially including room entered, plate changed, interaction, entity defeated, and dialogue completed.
- [ ] Define typed composable condition variants including all/any signals, player count, and boolean room flags.
- [ ] Define typed action variants including open/close gate, enable/disable entity, start dialogue, spawn encounter, set flag, and transition room.
- [ ] Keep reusable behavior in Odin while allowing room files to place instances and connect typed conditions/actions by local instance ID.
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

- [x] Centralize editor actions so input handling and displayed control hints use the same bindings.
- [x] Introduce reusable panel, field, status, and wrapping action-bar primitives and migrate the editor HUD and inspector.
- [x] Add row/column layout, stable widget focus, and gamepad navigation as interactive controls require them.
- [x] Migrate title and pause menus after the editor UI primitives have proven stable.
- [ ] Generate entity palettes from typed Odin entity and content definitions.
- [ ] Generate property controls from the same enums and field definitions used for room loading and validation.
- [ ] Remove duplicate room, door-name, texture-path, tile, and entity lists where the room registry or typed definition tables can supply them.
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

- [ ] The representative proof room can be built from existing typed content without hand-editing a room file or Odin code.
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
- [ ] Playtest spawning, updating, saving, loading, and destroying the new type.

### Exit criteria

- [ ] The extension guide accurately describes all required integration points.
- [ ] A new entity type does not require searching the entire codebase for switches to update.
- [ ] Entity references remain stable through spawning and removal.

## Milestone 6 — Prove and document the production workflow

### End-to-end proof room

- [ ] Build a new room using only code-defined content and the editor.
- [ ] Include at least two enemy variants.
- [ ] Include an NPC with typed, code-owned dialogue.
- [ ] Include the code-defined holdable/item.
- [ ] Include a multi-source condition and at least two different actions.
- [ ] Include working entry and exit links to existing rooms.
- [ ] Run the validator and focused pure-library unit tests.
- [ ] Playtest in both one-player and two-player modes.

### Documentation

- [ ] Document the content directory layout and naming conventions.
- [ ] Document how to create, duplicate, validate, and playtest a room.
- [ ] Document each entity type and its properties.
- [ ] Document how to add typed enemies, NPCs, holdables, dialogue, and their asset requirements in Odin.
- [ ] Document conditions, actions, state lifetimes, and debugging tools.
- [ ] Document the current content contract and how intentional format changes should update shipped content and focused pure-contract tests together.
- [ ] Add minimal valid example files suitable for copying.

### Exit criteria

- [ ] A contributor unfamiliar with the implementation can create and connect a small room using existing typed content by following the documentation.
- [ ] The proof room survives save, reload, validation, and a release-mode run.
- [ ] No proof-room-specific runtime code exists.

## Verification approach

- [x] Focused unit tests cover pure room parsing, serialization, typed variant conversion, and validation rules where failures are cheap to isolate.
- [x] The retired legacy-format tests were removed with the legacy parser.
- [x] Golden fixtures are used only where exact output stability matters.
- [x] Do not add integration tests for runtime entity lifecycles, shipped-room loading, editor workflows, or gameplay behavior.
- [ ] Quick manual playtests cover one-player, two-player, editor entry/exit, room transitions, dialogue, combat, carrying, and mechanisms.

## Recommended implementation order

1. Milestone 0: restore green tests and establish the repeatable checks.
2. Milestone 1: introduce JSON room DTOs, convert all rooms, and retire the positional parser.
3. Milestone 2 room registry: discover rooms by their dynamic string IDs.
4. Milestone 2 typed content: coerce closed-set identifiers into enums at the serde boundary and define their behavior in Odin.
5. Milestone 3 dialogue: move narrative definitions into typed Odin modules.
6. Milestone 4: drive editor choices and controls from the room registry and typed Odin definitions.
7. Milestone 3 mechanisms: generalize room interactions using concrete editor use cases.
8. Milestone 5: simplify runtime extension based on pressure exposed by the typed content model.
9. Milestone 6: build the proof room, close workflow gaps, and document the result.

## Explicit non-goals for the first pass

- [ ] Do not build a general-purpose visual scripting language.
- [ ] Do not add branching quests, inventory, loot tables, localization, or save-game persistence without a concrete content requirement.
- [ ] Do not replace the renderer, input layer, or scene framework as part of the content work.
- [ ] Do not adopt a full ECS solely to remove type switches; typed identifiers and reliable room authoring come first.
- [ ] Do not serialize runtime `TileMap` structures, GPU/audio handles, caches, or mutable state directly.
- [ ] Do not build a general-purpose JSON schema framework or custom JSON parser around the built-in serde package.
- [ ] Do not add file-driven archetype, dialogue, behavior, item, or general content registries; rooms are the sole data-file boundary.
- [ ] Do not preserve arbitrary string IDs past room decoding when the valid values form a closed set controlled by the program.
- [ ] Do not make a third-party desktop map editor part of the canonical gamepad-first authoring workflow.
- [ ] Do not build backward-compatibility or migration machinery while all shipped content can be updated with the code.

## Progress tracking

When starting a task:

- Check its dependencies and relevant exit criteria.
- Add or update a focused unit test when changing pure serialized-contract, conversion, or validation behavior.
- Update all affected shipped maps in the same change as a content-format change.
- Run focused unit tests for pure logic and use the relevant quick playtest for runtime or editor behavior.
- Record intentional scope changes in this file so the roadmap remains authoritative.
