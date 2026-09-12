#version 330

in vec3 world_position;
in float blade_height;
in float blade;
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

// Small tapered brush marks fill the undergrowth without extra geometry.
// Derivative filtering fades them out before they become subpixel noise.
float undergrowth(vec2 p)
{
    vec2 grid = vec2(p.x - p.y * 0.35, p.y) * 0.65;
    vec2 cell = floor(grid);
    vec2 local = fract(grid);
    float seed = hash(cell);
    float height = 0.5 + seed * 0.35;
    float taper = 1.0 - clamp(local.y / height, 0.0, 1.0);
    float center = 0.35 + seed * 0.3 + local.y * 0.15;
    float edge = abs(local.x - center) - taper * 0.23;
    float filter_width = max(fwidth(grid.x), fwidth(grid.y));
    float stroke = 1.0 - smoothstep(-filter_width, filter_width, edge);
    stroke *= 1.0 - smoothstep(height - filter_width, height + filter_width, local.y);
    return stroke * (1.0 - smoothstep(0.3, 0.8, filter_width));
}

void main()
{
    vec2 p = world_position.xz;
    float patches = noise(p * 0.032) * 0.7 + noise(p * 0.11) * 0.3;
    vec3 moss = vec3(0.24, 0.40, 0.20);
    vec3 leaf = vec3(0.47, 0.62, 0.28);
    vec3 sunlight = vec3(0.72, 0.76, 0.40);
    vec3 color = mix(moss, leaf, smoothstep(0.15, 0.8, patches));
    float brush = undergrowth(p);
    color = mix(color, leaf * 1.08, brush * (1.0 - blade) * 0.45);
    color = mix(color, sunlight, blade_height * blade_height * 0.72);
    color *= mix(1.0, 0.82 + 0.24 * blade_height, blade);
    // Broad moving light bands tie the individual blades into one breeze.
    float breeze = sin(dot(p, vec2(0.045, 0.032)) - grass_time * 1.3);
    color += vec3(0.035, 0.04, 0.012) * smoothstep(0.25, 0.95, breeze);
    float cloud = noise(p * 0.013 + vec2(grass_time * 0.012, 0.0));
    color *= mix(0.89, 1.04, smoothstep(0.25, 0.72, cloud));

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
    finalColor = vec4(color, 1.0);
}
