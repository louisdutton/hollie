// Shared sunlight transmission, injected into every lit fragment shader.
uniform vec3 cloud_offset_scale; // World-space drift.xy and inverse patch size.
uniform vec3 cloud_shape;        // Coverage, edge softness, sunlight attenuation.

float environment_hash(vec2 p)
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Approximate signed ellipse distance, used only for a soft silhouette edge.
float environment_cloud_lobe(vec2 p, vec2 center, vec2 radius)
{
    return (length((p - center) / radius) - 1.0) * min(radius.x, radius.y);
}

float environment_cloud_cover(vec2 p)
{
    vec2 cell = floor(p);
    float distance_to_cloud = 2.0;
    float coverage = clamp(cloud_shape.x, 0.0, 1.0);
    // Each cell holds a whole cloud, not a noise sample. Neighbouring cells
    // keep silhouettes continuous as they drift across cell boundaries.
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 id = cell + vec2(x, y);
            float seed = environment_hash(id + vec2(13.7, 5.3));
            vec2 jitter = vec2(environment_hash(id), environment_hash(id + vec2(7.1, 29.4)));
            vec2 q = p - (id + 0.5 + (jitter - 0.5) * 0.44);
            float angle = seed * 6.2831853;
            q = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * q;
            float size = mix(0.72, 1.08, seed) * mix(0.35, 1.35, coverage);
            q /= size;
            // A connected, scalloped silhouette with a broad interior.
            // Combine lobes before softening so overlaps leave no ring seams.
            float d = environment_cloud_lobe(q, vec2(0.0, 0.0), vec2(0.34, 0.22));
            d = min(d, environment_cloud_lobe(q, vec2(-0.25, 0.02), vec2(0.20, 0.18)));
            d = min(d, environment_cloud_lobe(q, vec2(-0.10, 0.17), vec2(0.23, 0.22)));
            d = min(d, environment_cloud_lobe(q, vec2(0.16, 0.15), vec2(0.22, 0.19)));
            d = min(d, environment_cloud_lobe(q, vec2(0.30, -0.02), vec2(0.17, 0.16)));
            distance_to_cloud = min(distance_to_cloud, d * size);
        }
    }
    float softness = clamp(cloud_shape.y, 0.001, 0.15);
    float cover = 1.0 - smoothstep(-softness, softness, distance_to_cloud);
    return mix(cover, 1.0, smoothstep(0.85, 1.0, coverage));
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
    float cover = environment_cloud_cover(p);
    return 1.0 - cover * clamp(cloud_shape.z, 0.0, 1.0) * daylight;
}
