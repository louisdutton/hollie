#version 330

in vec3 vertexPosition;
in vec4 vertexColor;
uniform mat4 mvp;
uniform float grass_time;
out vec3 world_position;
out float blade_height;
out float blade;

void main()
{
    blade = step(0.01, vertexColor.a);
    blade_height = clamp(vertexPosition.y / max(vertexColor.a * 8.0, 0.01), 0.0, 1.0) * blade;
    vec3 position = vertexPosition;
    float wave = sin(dot(position.xz, vec2(0.045, 0.032)) - grass_time * 1.3);
    float flutter = sin(dot(position.xz, vec2(0.31, -0.18)) + grass_time * 2.4);
    // Squared tip weighting anchors the roots and bends the upper blade.
    position.xz += vec2(1.0, 0.45) * (0.55 + wave * 0.8 + flutter * 0.18)
                   * blade_height * blade_height;
    world_position = position;
    gl_Position = mvp * vec4(position, 1.0);
}
