#version 330

in vec2 fragTexCoord;
in vec3 fragNormal;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec3 ambientColor;
uniform vec3 keyDirection;
uniform vec3 keyColor;
uniform vec3 fillDirection;
uniform vec3 fillColor;
uniform float flashAmount;

out vec4 finalColor;

void main()
{
    vec3 normal = normalize(fragNormal);
    float keyAmount = max(dot(normal, -normalize(keyDirection)), 0.0);
    float fillAmount = max(dot(normal, -normalize(fillDirection)), 0.0);
	vec3 lighting = ambientColor + keyColor*keyAmount + fillColor*fillAmount;
	vec4 albedo = texture(texture0, fragTexCoord)*colDiffuse*fragColor;
	vec3 linearAlbedo = pow(max(albedo.rgb, vec3(0.0)), vec3(2.2));
	vec3 linearLitColor = linearAlbedo*lighting;
	vec3 litColor = pow(max(linearLitColor, vec3(0.0)), vec3(1.0/2.2));
	finalColor = vec4(mix(litColor, vec3(1.0), clamp(flashAmount, 0.0, 1.0)), albedo.a);
}
