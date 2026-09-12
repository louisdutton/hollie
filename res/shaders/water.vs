#version 330

in vec3 vertexPosition;
in vec4 vertexColor;
uniform mat4 mvp;
uniform vec4 wakes[48];
uniform float surface_height;
out vec3 world_position;
out vec4 shore_edges;

void main()
{
    // Immediate-mode water geometry is submitted in world coordinates.
    world_position = vertexPosition;
    shore_edges = vertexColor;
    vec3 displaced = vertexPosition;
    float lift = 0.0;
    for (int i = 0; i < 48; i++) {
        if (wakes[i].w <= 0.0) continue;
        float ring = length(vertexPosition.xz - wakes[i].xy) - wakes[i].z;
        lift += cos(ring * 1.15) * exp(-ring * ring * 0.10) * wakes[i].w;
    }
    // Keep the volume bottom fixed. Shared vertices receive identical waves.
    displaced.y += clamp(lift, -1.0, 1.0) * 0.65 *
                   smoothstep(surface_height - 2.0, surface_height, vertexPosition.y);
    gl_Position = mvp * vec4(displaced, 1.0);
}
