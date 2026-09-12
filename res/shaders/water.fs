#version 330

in vec3 world_position;
in vec4 shore_edges;
uniform float water_time;
uniform float tile_size;
uniform float surface_height;
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

void main()
{
    vec2 p = world_position.xz;
    vec2 drift = vec2(water_time * 0.65, -water_time * 0.38);
    float wash = noise((p + drift) * 0.025);
    float detail = noise((p - drift * 1.4) * 0.075);
    // Broad, softly separated pigment washes rather than glossy reflections.
    vec3 color = mix(vec3(0.10, 0.39, 0.46), vec3(0.26, 0.63, 0.61),
                     smoothstep(0.20, 0.78, wash));
    color += (detail - 0.5) * vec3(0.035, 0.05, 0.04);

    float wave = sin(p.y * 0.30 + p.x * 0.055 + detail * 4.0 - water_time * 0.85);
    float width = max(fwidth(wave), 0.025);
    float stroke = smoothstep(0.91 - width, 0.91 + width, wave);
    stroke *= smoothstep(0.52, 0.72, noise((p + drift) * vec2(0.10, 0.035)));
    color = mix(color, vec3(0.67, 0.85, 0.77), stroke * 0.52);

    // Per-tile edge flags only mark actual banks, never internal tile seams.
    vec2 local = fract(p / tile_size) * tile_size;
    float bank = min(min(mix(1000.0, local.x, shore_edges.r),
                         mix(1000.0, tile_size - local.x, shore_edges.g)),
                     min(mix(1000.0, local.y, shore_edges.b),
                         mix(1000.0, tile_size - local.y, shore_edges.a)));
    float ripple = sin(bank * 2.2 - water_time * 1.1 + detail * 2.0);
    float foam = (1.0 - smoothstep(0.3, 2.8, bank)) * (0.65 + detail * 0.35);
    foam += (1.0 - smoothstep(2.0, 6.0, bank)) * smoothstep(0.86, 0.98, ripple) * 0.20;
    float surface = smoothstep(surface_height - 0.6, surface_height, world_position.y);
    color = mix(color * 0.78, color, surface);
    color = mix(color, vec3(0.86, 0.91, 0.77), foam * surface * 0.82);
    finalColor = vec4(color, mix(0.62, 0.82, foam * surface));
}
