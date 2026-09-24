// Shared sunlight transmission, injected into every lit fragment shader.
uniform vec3 cloud_offset_scale; // World-space drift.xy and inverse patch size.
uniform vec3 cloud_shape;        // Coverage, edge softness, sunlight attenuation.

float environment_hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float environment_noise(vec2 p)
{
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(environment_hash(cell), environment_hash(cell + vec2(1, 0)), f.x),
               mix(environment_hash(cell + vec2(0, 1)), environment_hash(cell + vec2(1, 1)), f.x), f.y);
}

float environment_sun_visibility(vec3 position)
{
    if (cloud_shape.x <= 0.0 || cloud_shape.z <= 0.0) return 1.0;
    // Project along the sun ray onto a common plane, so walls, elevated bodies,
    // grass and water agree. Fade the effect as the sun reaches the horizon.
    vec3 sun_ray = normalize(keyDirection);
    float daylight = smoothstep(0.02, 0.15, -sun_ray.y);
    vec2 ground = position.xz - sun_ray.xz * position.y / min(sun_ray.y, -0.02);
    vec2 p = (ground - cloud_offset_scale.xy) * cloud_offset_scale.z;
    float field = environment_noise(p) * 0.78
                + environment_noise(p * 2.03 + vec2(17.2, 9.4)) * 0.22;
    float threshold = mix(1.2, -0.2, clamp(cloud_shape.x, 0.0, 1.0));
    float softness = max(cloud_shape.y, 0.001);
    float cover = smoothstep(threshold - softness, threshold + softness, field);
    return 1.0 - cover * clamp(cloud_shape.z, 0.0, 1.0) * daylight;
}
