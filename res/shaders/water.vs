#version 330

in vec3 vertexPosition;
in vec4 vertexColor;
uniform mat4 mvp;
out vec3 world_position;
out vec4 shore_edges;

void main()
{
    // Immediate-mode water geometry is submitted in world coordinates.
    world_position = vertexPosition;
    shore_edges = vertexColor;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
