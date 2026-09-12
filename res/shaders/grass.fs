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

void main()
{
    vec2 p = world_position.xz;
    // Distort broad shapes rather than layering fine noise. World coordinates
    // let the painted patches span tiles without visible grid boundaries.
    vec2 warp = vec2(noise(p * 0.018), noise(p * 0.018 + vec2(19.0, 7.0)));
    float breeze = sin(dot(p, vec2(0.025, 0.018)) - grass_time * 0.65);
    float patches = noise(p * vec2(0.022, 0.032) + warp * 1.2
                          + vec2(breeze * 0.035, 0.0));
    vec3 moss = vec3(0.36, 0.51, 0.27);
    vec3 leaf = vec3(0.48, 0.61, 0.31);
    vec3 sunlight = vec3(0.61, 0.69, 0.38);
    // Three mostly solid paint tones, with soft edges only at their borders.
    float edge = max(0.025, fwidth(patches));
    vec3 color = mix(moss, leaf, smoothstep(0.38 - edge, 0.38 + edge, patches));
    color = mix(color, sunlight, smoothstep(0.65 - edge, 0.65 + edge, patches));
    // Tufts share the ground palette; avoid bright individual leaf tips.
    color *= 1.0 - blade * smoothstep(0.25, 0.75, blade_height) * 0.055;

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
