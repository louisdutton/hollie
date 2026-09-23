#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord; // Shared world-space root for each blade.
in vec4 vertexColor;
uniform mat4 mvp;
uniform float grass_time;
uniform vec4 grass_players[2];
uniform vec4 grass_motion[2];
uniform vec4 grass_trail[64];
uniform vec4 grass_trail_motion[64];
uniform int grass_trail_count;
out vec3 world_position;
out vec3 meadow_normal;
out float blade_height;
out float blade;
out float grass_contact;
out float meadow_tone;
out float cloud_light;

float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p)
{
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(cell), hash(cell + vec2(1, 0)), f.x),
               mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), f.x), f.y);
}

vec2 directional_displacement(vec2 direction, float strength)
{
    return direction / max(length(direction), 0.001) * max(strength, 0.0);
}

void main()
{
    blade = step(0.01, vertexColor.a);
    vec2 root = vertexTexCoord;
    // All leaf vertices sample the same field, avoiding rubbery changes in width.
    float height = max(vertexColor.a * 12.0, 0.01);
    blade_height = clamp((vertexPosition.y - 0.04) / height, 0.0, 1.0) * blade;
    meadow_tone = noise(root * 0.009);
    vec2 wind_direction = normalize(vec2(1.0, 0.45));
    cloud_light = smoothstep(0.2, 0.8,
        noise(root * 0.005 + wind_direction * grass_time * 0.012));
    float gust = noise(root * 0.006 - wind_direction * grass_time * 0.07);
    float wind_front = 0.5 + 0.5 * sin(dot(root, vec2(0.018, -0.01))
        - grass_time * 0.9 + (gust - 0.5) * 1.4);
    float wind_strength = 0.1 + smoothstep(0.3, 0.85, wind_front) * 0.25
        + (gust - 0.5) * 0.08;
    vec2 wind = directional_displacement(wind_direction, wind_strength);
    vec2 bend = vec2(0.0);
    float contact = 0.0;
    for (int i = 0; i < 2 && blade > 0.0; i++) {
        vec4 player = grass_players[i];
        if (player.w <= 0.0 || player.z <= 0.0) continue;
        float influence = (1.0 - smoothstep(0.0, player.z, length(root - player.xy))) * player.w;
        if (influence > contact) {
            bend = directional_displacement(grass_motion[i].xy, influence);
            contact = influence;
        }
    }
    // Strongest imprint wins; overlapping footsteps never accumulate a crater.
    for (int i = 0; i < grass_trail_count && blade > 0.0; i++) {
        vec4 imprint = grass_trail[i];
        float influence = (1.0 - smoothstep(imprint.z * 0.4, imprint.z,
            length(root - imprint.xy))) * imprint.w;
        if (influence > contact) {
            bend = directional_displacement(grass_trail_motion[i].xy, influence);
            contact = influence;
        }
    }
    vec3 position = vertexPosition;
    if (blade > 0.0) {
        // Constant-curvature centreline: radius * angle = blade length.
        // Width offsets stay intact and roots remain exactly planted.
        // Wind and interactions share one directional curvature system.
        vec2 curvature = wind + bend * 1.15;
        float magnitude = length(curvature);
        float angle = clamp(magnitude, 0.001, 1.35);
        vec2 direction = curvature / max(magnitude, 0.001);
        float arc = angle * blade_height;
        float radius = height / angle;
        position.xz += direction * radius * (1.0 - cos(arc));
        position.y = 0.04 + radius * sin(arc);
    }
    // Terrain-aligned normals unify the field. A little shared wind tilt
    // reveals broad waves without lighting every ribbon as a separate sheet.
    meadow_normal = normalize(vec3(-wind.x * blade_height * 0.18, 1.0,
                                    -wind.y * blade_height * 0.18));
    grass_contact = contact * blade;
    world_position = position; // Shadows must follow the displaced geometry.
    gl_Position = mvp * vec4(position, 1.0);
}
