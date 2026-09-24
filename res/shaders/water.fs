#version 330

in vec3 world_position;
in float surface_weight;
uniform float water_time;
uniform float tile_size;
uniform vec4 wakes[48];
uniform vec4 wake_shapes[48];
uniform sampler2D shore_map;
uniform vec3 shore_map_info;
uniform vec3 view_direction;
uniform vec3 ambientColor;
uniform vec3 keyDirection;
uniform vec3 keyColor;
uniform vec3 fillDirection;
uniform vec3 fillColor;
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
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(cell), hash(cell + vec2(1, 0)), u.x),
               mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), u.x), u.y);
}

float crest_mask(float wave, float threshold)
{
    float width = max(fwidth(wave), 0.025);
    return smoothstep(threshold - width, threshold + width, wave);
}

float light_visibility()
{
    vec4 light_position = lightVP * vec4(world_position, 1.0);
    vec3 uv = light_position.xyz / light_position.w * 0.5 + 0.5;
    if (any(lessThan(uv, vec3(0.0))) || any(greaterThan(uv, vec3(1.0)))) return 1.0;
    float shadow = 0.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            float depth = texture(shadowMap, uv.xy + vec2(x, y) / float(shadowMapResolution)).r;
            shadow += step(depth + 0.001, uv.z);
        }
    }
    return 1.0 - shadow / 9.0;
}

void main()
{
    vec2 p = world_position.xz;
    vec2 drift = vec2(water_time * 0.55, -water_time * 0.32);
    float wash = noise((p + drift) * 0.022);
    float detail = noise((p - drift * 1.3) * 0.080);
    vec2 shore_uv = (p / tile_size * shore_map_info.z + 0.5) / shore_map_info.xy;
    float bank = texture(shore_map, shore_uv).r * tile_size;
    float shore_fade = smoothstep(0.0, tile_size * 0.5, bank);
    float shallows = 1.0 - smoothstep(0.0, tile_size * 0.85, bank);

    // Broad pigment washes, with a shore tint rather than simulated bed depth.
    vec3 color = mix(vec3(0.12, 0.40, 0.46), vec3(0.24, 0.55, 0.55),
                     smoothstep(0.24, 0.78, wash));
    color = mix(color, vec3(0.38, 0.65, 0.59), shallows * 0.65);
    color += (detail - 0.5) * vec3(0.025, 0.035, 0.025);

    // Long curved strokes break into islands; leave plenty of quiet surface.
    float wave = sin(p.y * 0.27 + p.x * 0.055 + (detail - 0.5) * 3.0 - water_time * 0.75);
    float stroke = crest_mask(wave, 0.94);
    stroke *= smoothstep(0.50, 0.72, noise((p + drift) * vec2(0.095, 0.032)));
    color = mix(color, vec3(0.64, 0.79, 0.70), stroke * 0.40 * shore_fade * surface_weight);

    float contact = 1.0 - smoothstep(0.35, 1.35 + detail * 0.65, bank);
    contact *= mix(0.30, 0.80, smoothstep(0.25, 0.75, detail));
    float shore_wave = sin(bank * 1.4 + detail * 1.8 + water_time * 0.90);
    float foam = contact + crest_mask(shore_wave, 0.92) *
                 smoothstep(0.8, 2.0, bank) * (1.0 - smoothstep(2.0, 7.0, bank)) * 0.28;

    vec2 slope = cos(dot(p, vec2(0.065, 0.045)) - water_time * 0.70) * vec2(0.065, 0.045) * 0.24
               + cos(dot(p, vec2(-0.040, 0.100)) - water_time * 0.93) * vec2(-0.040, 0.100) * 0.14;
    // Fine ripples affect the light without requiring denser geometry.
    slope += cos(dot(p, vec2(0.19, 0.11)) - water_time * 1.05) * vec2(0.19, 0.11) * 0.16;
    float wake_lift = 0.0;
    vec2 wake_slope = vec2(0.0);
    for (int i = 0; i < 48; i++) {
        if (wakes[i].w <= 0.0) continue;
        vec2 delta = p - wakes[i].xy;
        vec2 direction = wake_shapes[i].xy;
        vec2 side = vec2(-direction.y, direction.x);
        float extent = wake_shapes[i].z;
        float along = dot(delta, direction);
        float across = dot(delta, side);
        float edge = abs(across) - wakes[i].z;
        float ribbon = exp(-edge * edge * 0.5 - along * along / (extent * extent)) * wakes[i].w;
        // Match the vertex height field; overlapping strokes never pile up.
        if (ribbon > wake_lift) {
            wake_lift = ribbon;
            wake_slope = ribbon * (-edge * sign(across) * side -
                                   2.0 * along / (extent * extent) * direction);
        }
    }
    foam = max(foam, wake_lift * mix(0.35, 0.65, detail) * shore_fade);
    slope += wake_slope * 0.30;
    slope *= shore_fade;
    vec3 normal = normalize(vec3(-slope.x, 1.0, -slope.y));
    vec3 light = -normalize(keyDirection);
    // Orthographic rays are parallel, including at the corners of the screen.
    vec3 view = normalize(view_direction);
    vec3 half_vector = normalize(light + view);
    float visibility = light_visibility();
    float diffuse = max(dot(normal, light), 0.0);
    float fill = max(dot(normal, -normalize(fillDirection)), 0.0);
    vec3 illumination = ambientColor + keyColor * diffuse * visibility + fillColor * fill;

    foam = clamp(foam, 0.0, 1.0) * surface_weight;
    color *= mix(0.72, 1.0, surface_weight);
    color = mix(color, vec3(0.86, 0.89, 0.76), foam * 0.85);
    vec3 lit = pow(max(color, vec3(0.0)), vec3(2.2)) * illumination;
    float highlight = smoothstep(0.20, 0.55, pow(max(dot(normal, half_vector), 0.0), 4.0));
    lit += keyColor * highlight * 0.07 * visibility * surface_weight * (1.0 - foam);
    float fresnel = pow(1.0 - max(dot(normal, view), 0.0), 3.0);
    lit += vec3(0.18, 0.28, 0.32) * fresnel * 0.10 * surface_weight;
    float opacity = mix(0.72, mix(0.70, 0.48, shallows), surface_weight);
    finalColor = vec4(pow(max(lit, vec3(0.0)), vec3(1.0 / 2.2)), mix(opacity, 0.88, foam));
}
