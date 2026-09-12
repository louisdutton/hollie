#version 330

in vec3 vertexPosition;
in vec4 vertexColor;
uniform mat4 mvp;
uniform float grass_time;
// World X/Z, contact radius, and movement/contact strength for each player.
uniform vec4 grass_players[2];
uniform vec4 grass_motion[2];
uniform vec4 grass_trail[32];
uniform vec4 grass_trail_motion[32];
out vec3 world_position;
out float blade_height;
out float blade;

void main()
{
    blade = step(0.01, vertexColor.a);
    blade_height = clamp(vertexPosition.y / max(vertexColor.a * 8.0, 0.01), 0.0, 1.0) * blade;
    vec3 position = vertexPosition;
    float wave = sin(dot(position.xz, vec2(0.045, 0.032)) - grass_time * 1.3);
    float flutter = sin(dot(position.xz, vec2(0.31, -0.18)) + grass_time * 2.4);
    // Squared tip weighting anchors the roots and bends the upper blade.
    position.xz += vec2(1.0, 0.45) * (0.55 + wave * 0.8 + flutter * 0.18)
                   * blade_height * blade_height;
    vec2 bend = vec2(0.0);
    float flatten = 0.0;
    for (int i = 0; i < 2; i++) {
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
    for (int i = 0; i < 32; i++) {
        vec4 imprint = grass_trail[i];
        if (imprint.w <= 0.0) continue;
        float distance_to_imprint = length(vertexPosition.xz - imprint.xy);
        float contact = (1.0 - smoothstep(0.0, imprint.z, distance_to_imprint)) * imprint.w;
        if (contact > flatten) {
            bend = grass_trail_motion[i].xy * contact;
            flatten = contact;
        }
    }
    // Keep overlapping players bounded and the roots planted.
    bend /= max(length(bend), 1.0);
    float tip_weight = blade_height * blade_height;
    position.xz += bend * 2.5 * tip_weight;
    position.y -= vertexPosition.y * flatten * 0.18 * tip_weight;
    // Anchor the painted colour to the leaf instead of sliding it through
    // world-space patches as the leaf bends.
    world_position = vertexPosition;
    gl_Position = mvp * vec4(position, 1.0);
}
