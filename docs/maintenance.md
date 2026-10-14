# Maintenance conventions

Preserve room wire names and IDs when changing content; existing maps and editor
workflows depend on them. Introduce an explicit migration for incompatible changes.

Door destinations in the existing maps share a routing token through
`target_door_id`; that token is not necessarily the destination entity's ID.
Keep that compatibility when loading old maps.

Use the cover and background images in `assets/` as the aesthetic reference:
warm sunlight, painted greens, cyan water, soft shadows, and atmospheric depth.
Review visual changes against those images in a private-display rendering session.

Seeded replay is a regression tool for this environment, not a promise of identical
results across GPUs or Bevy versions. Retain useful interactions as saved scenarios.

Editor exit discards unsaved changes. Review and commit generated assets together
with their source or generator changes, and keep source assets and licenses.

Hardware private-display probes render to a Bevy image target: Xvfb cannot present the
hardware Vulkan swapchain. Captures use Bevy’s texture readback on the selected GPU.
