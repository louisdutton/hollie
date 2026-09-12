#version 330

in vec3 vertexPosition;
in vec4 vertexColor;
uniform mat4 mvp;
uniform float grass_time;
// World X/Z, contact radius, and movement/contact strength for each player.
uniform vec4 grass_players[2];
uniform vec4 grass_motion[2];
uniform vec4 grass_trail[64];
uniform vec4 grass_trail_motion[64];
uniform int grass_trail_count;
out vec3 world_position;
out float blade_height;
out float blade;
out float grass_contact;
out float wind_light;

void main()
{
    blade = step(0.01, vertexColor.a);
    blade_height = clamp(vertexPosition.y / max(vertexColor.a * 12.0, 0.01), 0.0, 1.0) * blade;
    vec3 position = vertexPosition;
    float wave = sin(dot(position.xz, vec2(0.025, 0.018)) - grass_time * 1.05);
    float ripple = sin(dot(position.xz, vec2(0.075, -0.04)) - grass_time * 1.7);
    wind_light = smoothstep(0.05, 0.9, wave * 0.8 + ripple * 0.2);
    // Squared tip weighting anchors the roots and bends the upper blade.
    position.xz += vec2(1.0, 0.45) * (0.4 + wave * 1.1 + ripple * 0.25)
                   * blade_height * blade_height;
    vec2 bend = vec2(0.0);
    float flatten = 0.0;
    for (int i = 0; i < 2 && blade > 0.0; i++) {
        vec4 player = grass_players[i];
        if (player.w <= 0.0 || player.z <= 0.0) continue;
        vec2 away = vertexPosition.xz - player.xy;
        float distance_to_player = length(away);
        float contact = (1.0 - smoothstep(0.0, player.z, distance_to_player)) * player.w;
        // Brush leaves along the stride rather than opening a radial crater.
        bend += grass_motion[i].xy * contact;
        flatten = max(flatten, contact);
    }
    // Use the strongest local imprint, not a sum: repeated footsteps should
    // never deepen into a crater. Each imprint retains its original direction.
    for (int i = 0; i < grass_trail_count && blade > 0.0; i++) {
        vec4 imprint = grass_trail[i];
        if (imprint.w <= 0.0) continue;
        float distance_to_imprint = length(vertexPosition.xz - imprint.xy);
        // A full-strength inner footprint avoids fading most of the effect
        // before the player has even uncovered it. Keep only the edge soft.
        float contact = (1.0 - smoothstep(imprint.z * 0.4, imprint.z, distance_to_imprint)) * imprint.w;
        if (contact > flatten) {
            bend = grass_trail_motion[i].xy * contact;
            flatten = contact;
        }
    }
    // Keep overlapping players bounded and the roots planted.
    bend /= max(length(bend), 1.0);
    float tip_weight = blade_height * blade_height;
    position.xz += bend * 3.2 * tip_weight;
    position.y -= vertexPosition.y * flatten * 0.38 * tip_weight;
    grass_contact = flatten * blade;
    // Anchor the painted colour to the leaf instead of sliding it through
    // world-space patches as the leaf bends.
    world_position = vertexPosition;
    gl_Position = mvp * vec4(position, 1.0);
}
