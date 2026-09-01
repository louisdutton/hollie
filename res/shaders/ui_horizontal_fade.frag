#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec2 fadeBounds;
uniform float fadeWidth;

out vec4 finalColor;

void main()
{
    vec4 color = texture(texture0, fragTexCoord) * colDiffuse * fragColor;
    float leftFade = smoothstep(fadeBounds.x, fadeBounds.x + fadeWidth, gl_FragCoord.x);
    float rightFade = 1.0 - smoothstep(fadeBounds.y - fadeWidth, fadeBounds.y, gl_FragCoord.x);
    color.a *= leftFade * rightFade;
    finalColor = color;
}
