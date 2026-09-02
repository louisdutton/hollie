# Content smoke test

Run the game with:

```sh
devenv tasks run hollie:run
```

Run this checklist after changing map loading, entity spawning, room transitions, or editor persistence.

## Small room

- Start a one-player game and confirm the player appears beside the room's door.
- Confirm the room title is `???` and ambient music plays.
- Approach the NPC and confirm the three-page `Village NPC` dialogue opens, advances, and closes.
- Enter the door and confirm the game transitions to Olivewood without immediately transitioning back.

## Olivewood

- Confirm the room title is `Olivewood`.
- Toggle the gameplay debug UI and confirm solid collision cells appear with a translucent red overlay, including the house footprint around its walkable doorway.
- Confirm three goblin enemies, two pressure plates, one gate, one wood holdable, and two doors appear.
- Pick up and drop the wood holdable.
- Activate pressure plates 1 and 2 and confirm the gate opens only while both required triggers are active.
- Enter the cottage through its centered south-facing door and confirm it transitions to the small room at the matching door marker.
- Return to Olivewood, use the right door, and confirm it transitions to the Desert at the matching door marker.

## Desert

- Confirm the room title is `Blisterwind`.
- Confirm five enemies spawn. They currently use the goblin archetype; selecting skeletons from content data is later roadmap work.
- Use the room's door and confirm it returns to Olivewood at the matching door marker.

## Two-player pass

- Start a two-player game and confirm both players spawn with distinct `P1` and `P2` labels.
- Confirm both players can move, attack, and roll independently.
- Confirm room transitions remain disabled until both players have moved clear of the arrival door.
- Confirm either player can activate each of Olivewood's current pressure plates.

## Editor persistence

- In a debug build, press `F1` to enter the editor.
- Paint and erase one base tile and one decoration tile.
- Paint and erase one collision tile and confirm solid cells use the red overlay.
- Place, inspect, and remove an entity marker.
- Save with `Ctrl+S`, leave the editor, and confirm the room reloads cleanly.
- Revert deliberate smoke-test content edits before committing.
