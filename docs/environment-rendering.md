# Environment lighting

`Environment_State` supplies shared ambient, directional key and fill lighting to terrain, characters, grass and water. The shadow-map camera uses the same key direction. Day retains the original warm lighting; night uses a dimmer cool moonlight preset, with a lower artistic lighting floor for water so it does not remain daytime-bright.

In debug builds, press **D-pad Right** on either controller during gameplay to toggle day/night. The binding is ignored while paused, in dialogue, during room transitions, or in the editor. A new gameplay session starts in day; room reloads and room changes retain the selected preset. Release builds have no toggle binding.

Cloud shadows, their procedural shader module, drift state and custom shader loader have been removed. The shared environment foundation remains available for future weather and time-of-day controllers; no automatic cycle is active. Presets switch immediately.

Automated tests cover preset switching and restoration. Night brightness, colour readability and runtime shader behaviour require in-game review.
