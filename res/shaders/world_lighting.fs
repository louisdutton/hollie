#version 330

in vec2 fragTexCoord;
in vec3 fragNormal;
in vec4 fragColor;
in vec3 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec3 ambientColor;
uniform vec3 keyDirection;
uniform vec3 keyColor;
uniform vec3 fillDirection;
uniform vec3 fillColor;
uniform float flashAmount;
uniform mat4 lightVP;
uniform sampler2D shadowMap;
uniform int shadowMapResolution;

out vec4 finalColor;

void main()
{
    vec3 normal = normalize(fragNormal);
    float keyAmount = max(dot(normal, -normalize(keyDirection)), 0.0);
    float fillAmount = max(dot(normal, -normalize(fillDirection)), 0.0);

	vec4 lightSpacePosition = lightVP*vec4(fragPosition, 1.0);
	vec3 shadowCoordinates = lightSpacePosition.xyz/lightSpacePosition.w;
	shadowCoordinates = shadowCoordinates*0.5 + 0.5;
	vec2 texelSize = vec2(1.0/float(shadowMapResolution));
	// Compute depth slope in shadow UV space before any divergent branches.
	vec3 shadowDx = dFdx(shadowCoordinates);
	vec3 shadowDy = dFdy(shadowCoordinates);
	float determinant = shadowDx.x*shadowDy.y - shadowDx.y*shadowDy.x;
	vec2 depthSlope = vec2(0.0);
	if (abs(determinant) > 1e-10)
	{
		depthSlope = vec2(
			shadowDy.y*shadowDx.z - shadowDx.y*shadowDy.z,
			shadowDx.x*shadowDy.z - shadowDy.x*shadowDx.z
		)/determinant;
	}
	// Cover the 3x3 filter radius plus half a texel of sampling uncertainty.
	float slopeBias = min(1.5*dot(abs(depthSlope), texelSize), 0.01);
	float shadow = 0.0;
	bool insideShadowMap =
		shadowCoordinates.x >= 0.0 && shadowCoordinates.x <= 1.0 &&
		shadowCoordinates.y >= 0.0 && shadowCoordinates.y <= 1.0 &&
		shadowCoordinates.z >= 0.0 && shadowCoordinates.z <= 1.0;
	if (insideShadowMap)
	{
		float bias = max(0.0002*(1.0 - keyAmount), 0.00002) + 0.00001 + slopeBias;
		for (int x = -1; x <= 1; x++)
		{
			for (int y = -1; y <= 1; y++)
			{
				float closestDepth = texture(shadowMap, shadowCoordinates.xy + texelSize*vec2(x, y)).r;
				shadow += shadowCoordinates.z - bias > closestDepth ? 1.0 : 0.0;
			}
		}
		shadow /= 9.0;
	}
	vec3 lighting = ambientColor + keyColor*keyAmount*(1.0 - shadow) + fillColor*fillAmount;
	// Keep cast shadows legible without removing environment light entirely.
	lighting *= mix(1.0, 0.42, shadow);
	vec4 albedo = texture(texture0, fragTexCoord)*colDiffuse*fragColor;
	vec3 linearAlbedo = pow(max(albedo.rgb, vec3(0.0)), vec3(2.2));
	vec3 linearLitColor = linearAlbedo*lighting;
	vec3 litColor = pow(max(linearLitColor, vec3(0.0)), vec3(1.0/2.2));
	finalColor = vec4(mix(litColor, vec3(1.0), clamp(flashAmount, 0.0, 1.0)), albedo.a);
}
