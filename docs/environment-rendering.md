# Environment lighting

`Environment_State` is the resolved input to lighting, separate from material colours. The demo uses `ENVIRONMENT_DAY`, retaining the previous ambient, sun and fill colours/directions. Future time-of-day and weather controllers can blend these values; no day/night clock or weather simulation is implemented yet. The shadow-map camera reads the same sun direction as the materials.

Cloud shadows use a shared GLSL module, expanded by the lit-shader loader for static geometry, skinned characters, grass and water. A two-scale procedural field produces broad, softly edged patches. World positions project along the sun direction onto a common reference plane, aligning the pattern across elevated geometry and the ground. Coverage controls the threshold, softness controls the edges, and strength controls direct sunlight attenuation. Zero coverage or strength disables the effect; projection is guarded and attenuation fades near the horizon.

Cloud drift integrates world-space wind velocity in the simulation, independently of the water animation clock and camera. It pauses with simulation and persists across room changes. Grass's old independent cloud field is removed. Its blade wind animation remains unchanged for now; the environment wind currently drives cloud drift only.

Clouds attenuate direct sunlight and associated highlights, preserving ambient and fill light. Water retains its existing artistic lighting blend, so cloud contrast is deliberately gentler there. Existing geometry shadows continue to apply independently. This is a lighting mask, not visible sky clouds, volumetric weather, or cloud geometry.

The default daytime settings use coverage 0.52, strength 0.78, softness 0.08, inverse patch scale 0.012 and drift velocity (10, 4.5) world units per second. These produce smaller, more legible patches than the initial broad, faint wash. Tune these in `ENVIRONMENT_DAY` after in-game review. Automated tests cover drift timing, not runtime GLSL compilation or visual quality; review cloud alignment on banks, boxes and animals, and colour readability in shade.
