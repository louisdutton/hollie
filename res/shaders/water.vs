#version 330

in vec3 vertexPosition;
uniform mat4 mvp;
uniform float water_time;
uniform float surface_height;
uniform float tile_size;
uniform sampler2D shore_map;
uniform vec3 shore_map_info;
out vec3 world_position;
out float surface_weight;

void main()
{
    vec2 p = vertexPosition.xz;
    vec2 shore_uv = (p / tile_size * shore_map_info.z + 0.5) / shore_map_info.xy;
    float bank = textureLod(shore_map, shore_uv, 0.0).r * tile_size;
    float shore_fade = smoothstep(0.0, tile_size * 0.5, bank);
    float swell = sin(dot(p, vec2(0.065, 0.045)) - water_time * 0.70) * 0.24
                + sin(dot(p, vec2(-0.040, 0.100)) - water_time * 0.93) * 0.14;
    surface_weight = smoothstep(surface_height - 0.6, surface_height, vertexPosition.y);
    // Anchor banks and volume bottoms. Shared vertices sample identical motion.
    world_position = vertexPosition;
    world_position.y += swell * shore_fade *
                       smoothstep(surface_height - 2.0, surface_height, vertexPosition.y);
    gl_Position = mvp * vec4(world_position, 1.0);
}
