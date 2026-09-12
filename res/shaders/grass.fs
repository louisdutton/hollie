#version 330

in vec3 world_position;
in float blade_height;
in float blade;
in float grass_contact;
in float wind_light;
uniform float grass_time;
uniform mat4 lightVP;
uniform sampler2D shadowMap;
uniform int shadowMapResolution;
out vec4 finalColor;

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

void main()
{
    vec2 p = world_position.xz;
    // Soft colour masses unite the full-density blades; no fine ground marks.
    float patches = noise(p * 0.022) * 0.8 + noise(p * 0.05) * 0.2;
    vec3 moss = vec3(0.23, 0.43, 0.25);
    vec3 leaf = vec3(0.40, 0.60, 0.29);
    vec3 sunlight = vec3(0.65, 0.75, 0.39);
    vec3 color = mix(moss, leaf, smoothstep(0.15, 0.8, patches));
    // Dark roots disappear into the ground; the upper leaf catches warm light.
    float tip_light = smoothstep(0.25, 1.0, blade_height);
    color = mix(color, sunlight, tip_light * (0.48 + patches * 0.16));
    color *= mix(1.0, 0.88 + 0.12 * tip_light, blade);
    color += vec3(0.025, 0.035, 0.012) * wind_light * mix(0.35, 1.0, tip_light);

    vec4 light_position = lightVP * vec4(world_position, 1.0);
    vec3 uv = light_position.xyz / light_position.w * 0.5 + 0.5;
    float shadow = 0.0;
    if (all(greaterThanEqual(uv, vec3(0.0))) && all(lessThanEqual(uv, vec3(1.0)))) {
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                float depth = texture(shadowMap, uv.xy + vec2(x, y) / float(shadowMapResolution)).r;
                shadow += step(depth + 0.001, uv.z);
            }
        }
    }
    color = mix(color, color * vec3(0.56, 0.68, 0.65), shadow / 9.0);
    // Pressed leaves catch less light, helping the narrow trail read even
    // when its bend points into the isometric camera rather than sideways.
    color *= 1.0 - grass_contact * 0.11;
    finalColor = vec4(color, 1.0);
}
