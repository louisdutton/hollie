#version 330

in vec3 world_position;
in float surface_weight;
uniform float water_time;
uniform float tile_size;
uniform sampler2D shore_map;
uniform vec3 shore_map_info;
uniform vec4 foam_contacts[16]; // centre.xy, waterline radii.zw
uniform vec4 foam_headings[16]; // direction.xy, speed.z, active.w
uniform vec4 foam_starts[64];   // start.xy, width.z, age.w
uniform vec4 foam_ends[64];     // end.xy, strength.z, active.w
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

float cutout(float value, float threshold)
{
    float aa = max(fwidth(value), 0.015);
    return smoothstep(threshold - aa, threshold + aa, value);
}

// Warped cellular borders give foam scallops, curved branches and open holes.
// The same continuous world-space pattern breaks up shores, bodies and wakes.
float foam_cells(vec2 p)
{
    p += vec2(sin(p.y * 1.7 + water_time * 0.24),
              cos(p.x * 1.3 - water_time * 0.19)) * 0.32;
    vec2 base = floor(p);
    vec2 local = fract(p);
    float nearest = 10.0;
    float second = 10.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 cell = vec2(x, y);
            vec2 jitter = vec2(hash(base + cell), hash(base + cell + vec2(37.2, 19.8)));
            vec2 delta = cell + 0.2 + jitter * 0.6 - local;
            float d = length(delta);
            if (d < nearest) {
                second = nearest;
                nearest = d;
            } else {
                second = min(second, d);
            }
        }
    }
    return 1.0 - smoothstep(0.055, 0.17, second - nearest);
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
    vec2 drift = vec2(water_time * 0.60, -water_time * 0.35);
    float wash = noise((p + drift) * 0.020);
    float detail = noise((p - drift) * 0.14);
    vec2 warp = vec2(noise(p * 0.11 + drift * 0.08),
                     noise(p * 0.11 + vec2(17.3, 8.2) - drift * 0.06)) - 0.5;
    vec2 shore_uv = (p / tile_size * shore_map_info.z + 0.5) / shore_map_info.xy;
    float bank = texture(shore_map, shore_uv).r * tile_size;
    float shore_fade = smoothstep(0.0, tile_size * 0.4, bank);
    float shallows = 1.0 - smoothstep(0.0, tile_size * 0.9, bank);

    vec3 color = mix(vec3(0.10, 0.47, 0.56), vec3(0.19, 0.56, 0.61),
                     smoothstep(0.25, 0.75, wash));
    color = mix(color, vec3(0.37, 0.71, 0.66), shallows * 0.8);

    float pattern = foam_cells((p + drift) * 0.043);
    float dark_pattern = foam_cells((p + drift + vec2(4.0, -3.0)) * 0.043);
    float quiet = smoothstep(0.42, 0.72, wash);
    color = mix(color, color * vec3(0.77, 0.86, 0.90),
                dark_pattern * quiet * 0.42 * surface_weight);
    float surface_foam = cutout(pattern * quiet, 0.68) * 0.40 * shore_fade;

    // A broad scalloped contact strip with irregular holes and broken bands.
    float shore_contact = 1.0 - smoothstep(0.7, 2.5, bank + warp.x * 1.8);
    float shore_band = sin(bank * 0.95 + detail * 2.0 + water_time * 0.8);
    float shore_foam = cutout(shore_contact * mix(0.7, 1.0, detail), 0.48);
    shore_foam = max(shore_foam, cutout(shore_band, 0.93) *
                    smoothstep(2.0, 3.0, bank) * (1.0 - smoothstep(4.0, 8.0, bank)) *
                    cutout(detail, 0.44) * 0.7);

    float body_foam = 0.0;
    for (int i = 0; i < 16; i++) {
        if (foam_headings[i].w == 0.0) continue;
        vec2 delta = p - foam_contacts[i].xy;
        vec2 radius = foam_contacts[i].zw + 1.2;
        vec2 local = (delta + warp * 2.0) / radius;
        float r = length(local);
        float rim = 1.0 - smoothstep(0.08, 0.27, abs(r - 1.06));
        float facing = dot(delta / max(length(delta), 0.001), foam_headings[i].xy);
        float bow = 1.0 - smoothstep(0.06, 0.19, abs(r - 1.40 - warp.y * 0.12));
        bow *= smoothstep(0.05, 0.65, facing) * foam_headings[i].z;
        float breakup = mix(0.42, 1.0, detail);
        body_foam = max(body_foam, max(rim * breakup, bow * mix(0.70, 1.0, detail)));
    }
    body_foam = cutout(body_foam, 0.50);

    // Union connected footprints before applying the pattern: no visible
    // per-segment outlines, paired rails, or repeating circles.
    float trail_coverage = 0.0;
    for (int i = 0; i < 64; i++) {
        if (foam_ends[i].w == 0.0) continue;
        vec2 a = foam_starts[i].xy;
        vec2 segment = foam_ends[i].xy - a;
        float age = foam_starts[i].w;
        vec2 q = p + warp * (2.0 + age * 3.0);
        float t = clamp(dot(q - a, segment) / max(dot(segment, segment), 0.001), 0.0, 1.0);
        float distance = length(q - (a + segment * t));
        float width = foam_starts[i].z * mix(1.1, 0.45, age);
        float coverage = 1.0 - smoothstep(width * 0.2, width, distance);
        coverage *= pow(1.0 - age, 0.65) * mix(0.8, 1.0, foam_ends[i].z);
        trail_coverage = max(trail_coverage, coverage);
    }
    float wake_pattern = foam_cells((p - drift * 0.3) * 0.095);
    float trail_foam = cutout(trail_coverage * (0.15 + wake_pattern * 0.85) *
                             mix(0.7, 1.0, detail), 0.44);
    float foam = max(max(surface_foam, shore_foam), max(body_foam, trail_foam));
    foam *= surface_weight;

    // Broad graphic colour and foam remain readable in shadow. Lighting gives
    // context, with restrained sheen instead of making the effect depend on it.
    vec2 slope = cos(dot(p, vec2(0.065, 0.045)) - water_time * 0.70) * vec2(0.065, 0.045) * 0.24
               + cos(dot(p, vec2(-0.040, 0.100)) - water_time * 0.93) * vec2(-0.040, 0.100) * 0.14;
    vec3 normal = normalize(vec3(-slope.x * shore_fade, 1.0, -slope.y * shore_fade));
    vec3 light = -normalize(keyDirection);
    float visibility = light_visibility();
    vec3 illumination = ambientColor + keyColor * max(dot(normal, light), 0.0) * visibility
                      + fillColor * max(dot(normal, -normalize(fillDirection)), 0.0);
    illumination = mix(vec3(1.0), illumination, 0.55);
    color *= mix(0.72, 1.0, surface_weight);
    color = mix(color, vec3(0.90, 0.94, 0.82), foam * 0.95);
    vec3 lit = pow(color, vec3(2.2)) * illumination;
    vec3 half_vector = normalize(light + normalize(view_direction));
    float highlight = pow(max(dot(normal, half_vector), 0.0), 6.0);
    lit += keyColor * highlight * 0.035 * visibility * surface_weight * (1.0 - foam);
    float opacity = mix(0.76, mix(0.82, 0.60, shallows), surface_weight);
    finalColor = vec4(pow(max(lit, vec3(0.0)), vec3(1.0 / 2.2)), mix(opacity, 0.96, foam));
}
