# Title meadow

The title screen owns a separate perspective meadow scene. Its camera sits roughly 18 world units above the local ground, looking almost horizontally across low rolling hills. A pale sky, warm sun disc, and distance haze frame the grass. The main menu uses floating text and control hints rather than an opaque panel; existing settings menus remain available over the scene.

Gameplay and title share `grass_build_patch` and the grass vertex/fragment shaders, including the current green palette, curved blades, and wind sheen. The title uses its own shader instance, cached mesh chunks, and animation clock. Optional landscape displacement and fog uniforms default to zero in gameplay, preserving its flat tiles and lighting. Title grass has no contact uniforms or shadow map; its lighting comes explicitly from the day preset regardless of the gameplay debug toggle.

The meadow is built once on entry, with reduced grass density in the distance, and released when leaving the title screen. It does not load a gameplay room or change gameplay entities, tilemaps, grass caches, or environment state. The resource lifecycle also covers returning from gameplay to the menu.

Automated coverage checks shared mesh geometry and camera composition constraints. Runtime shader compilation, performance, text readability, and the low-angle composition need an in-game review; no graphical preview is available in the development agent environment.
