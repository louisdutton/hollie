#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord; // Shared world-space root for each blade.
in vec4 vertexColor;
uniform mat4 mvp;
uniform float grass_time;
uniform float meadow_landscape; // Zero for gameplay; title-only rolling terrain.
uniform vec4 grass_contacts[32];
uniform vec4 grass_motion[32];
uniform int grass_contact_count;
uniform vec4 grass_trail[64];
uniform vec4 grass_trail_motion[64];
uniform int grass_trail_count;
out vec3 world_position;
out vec3 meadow_normal;
out float blade_height;
out float blade;
out float grass_contact;
out float meadow_tone;
out float wind_highlight;

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
    meadow_tone = noise(root * 0.012);
    vec2 wind_direction = normalize(vec2(1.0, 0.45));
    float gust = noise(root * 0.01 - wind_direction * grass_time * 0.11);
    float wind_front = 0.5 + 0.5 * sin(dot(root, vec2(0.028, -0.016))
        - grass_time * 1.4 + (gust - 0.5) * 1.6);
    float wind_strength = 0.1 + smoothstep(0.2, 0.8, wind_front) * 0.62
        + gust * 0.1;
    vec2 wind = directional_displacement(wind_direction, wind_strength);
    float resting_angle = hash(root * 0.173 + vec2(19.1, 7.7)) * 6.2831853;
    vec2 resting_direction = vec2(cos(resting_angle), sin(resting_angle));
    float resting_strength = mix(0.12, 0.42, hash(root * 0.137 + vec2(3.1, 29.7)));
    vec2 resting_bend = directional_displacement(resting_direction, resting_strength);
    vec2 bend = vec2(0.0);
    float contact = 0.0;
    for (int i = 0; i < grass_contact_count && blade > 0.0; i++) {
        vec4 body = grass_contacts[i];
        if (body.w <= 0.0 || body.z <= 0.0) continue;
        float influence = (1.0 - smoothstep(0.0, body.z, length(root - body.xy))) * body.w;
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
    // Resting lean, wind, and interactions share one curvature system.
    vec2 curvature = resting_bend + wind + bend * 1.15;
    vec3 position = vertexPosition;
    if (blade > 0.0) {
        // Constant-curvature centreline: radius * angle = blade length.
        // Width offsets stay intact and roots remain exactly planted.
        float magnitude = length(curvature);
        float angle = clamp(magnitude, 0.001, 1.35);
        vec2 direction = curvature / max(magnitude, 0.001);
        float arc = angle * blade_height;
        float radius = height / angle;
        position.xz += direction * radius * (1.0 - cos(arc));
        position.y = 0.04 + radius * sin(arc);
    }
    // Curvature-derived normals make the travelling bend catch the light.
    meadow_normal = normalize(vec3(-curvature.x * blade_height * 0.32, 1.0,
                                    -curvature.y * blade_height * 0.32));
    // A soft band on the leading shoulder of each gust, never on the ground.
    wind_highlight = smoothstep(0.35, 0.68, wind_front)
        * (1.0 - smoothstep(0.78, 0.98, wind_front)) * blade;
    // Ground and blades use the same root height, preserving their attachment.
    if (meadow_landscape > 0.0) {
        float a = root.x * 0.009 + root.y * 0.004;
        float b = root.y * 0.010;
        position.y += (sin(a) * 12.0 + sin(b) * 8.0) * meadow_landscape;
        vec2 slope = vec2(cos(a) * 0.108, cos(a) * 0.048 + cos(b) * 0.08);
        meadow_normal = normalize(meadow_normal + vec3(-slope.x, 0.0, -slope.y) * meadow_landscape);
    }
    grass_contact = contact * blade;
    world_position = position; // Shadows must follow the displaced geometry.
    gl_Position = mvp * vec4(position, 1.0);
}
