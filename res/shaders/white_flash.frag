#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float flashAmount;

out vec4 finalColor;

void main()
{
  vec4 texelColor = texture(texture0, fragTexCoord) * colDiffuse * fragColor;

  // Mix the original color with white based on flashAmount
  vec3 flashedColor = mix(texelColor.rgb, vec3(1.0), flashAmount);

  finalColor = vec4(flashedColor, texelColor.a);
}
