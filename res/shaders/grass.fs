#version 330

in vec3 world_position;
in vec3 meadow_normal;
in float blade_height;
in float blade;
in float grass_contact;
in float meadow_tone;
in float cloud_light;
in float wind_highlight;
uniform vec3 view_position;
uniform vec3 ambientColor;
uniform vec3 keyDirection;
uniform vec3 keyColor;
uniform vec3 fillDirection;
uniform vec3 fillColor;
uniform mat4 lightVP;
uniform sampler2D shadowMap;
uniform int shadowMapResolution;
out vec4 finalColor;

void main()
{
    // One low-frequency albedo field for the ground and all leaf roots.
    // Muted darker greens blend into fresh light greens beside the turquoise water.
    vec3 albedo = mix(vec3(0.44, 0.65, 0.38), vec3(0.56, 0.79, 0.38),
                      smoothstep(0.0, 1.0, meadow_tone));
    float upper_leaf = smoothstep(0.2, 0.95, blade_height);
    // A subtle yellow-green tip, with roots still matching the ground.
    albedo = mix(albedo, vec3(0.70, 0.85, 0.43), upper_leaf * 0.12);

    vec4 light_position = lightVP * vec4(world_position, 1.0);
    vec3 uv = light_position.xyz / light_position.w * 0.5 + 0.5;
    float shadow = 0.0;
    if (all(greaterThanEqual(uv, vec3(0.0))) && all(lessThanEqual(uv, vec3(1.0)))) {
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                float depth = texture(shadowMap, uv.xy + vec2(x, y) / float(shadowMapResolution)).r;
                shadow += step(depth + 0.001, uv.z);
            }
        }
    }
    float visibility = (1.0 - shadow / 9.0) * mix(0.86, 1.0, cloud_light);
    vec3 normal = normalize(meadow_normal);
    vec3 light = -normalize(keyDirection);
    vec3 view = normalize(view_position - world_position);
    float diffuse = max(dot(normal, light), 0.0);
    float fill = max(dot(normal, -normalize(fillDirection)), 0.0);
    vec3 illumination = ambientColor + keyColor * diffuse * visibility + fillColor * fill;

    // Broad, restrained transmission when looking toward the sun. This and
    // the soft grazing highlight disappear under cast or cloud shadows.
    float transmission = pow(max(dot(view, -light), 0.0), 3.0);
    vec3 half_vector = normalize(light + view + vec3(0.0, 0.0001, 0.0));
    float highlight = pow(max(dot(normal, half_vector), 0.0), 12.0);
    float wind_sheen = pow(max(dot(normal, half_vector), 0.0), 6.0) * wind_highlight;
    float fresnel = pow(1.0 - max(dot(normal, view), 0.0), 3.0);
    vec3 linear_albedo = pow(albedo, vec3(2.2));
    vec3 lit = linear_albedo * illumination;
    lit += linear_albedo * keyColor * transmission * upper_leaf * visibility * 0.35;
    lit += keyColor * (highlight * 0.035 + fresnel * 0.025 + wind_sheen * 0.06)
        * upper_leaf * visibility;
    lit *= 1.0 - grass_contact * 0.08;
    finalColor = vec4(pow(max(lit, vec3(0.0)), vec3(1.0 / 2.2)), 1.0);
}
