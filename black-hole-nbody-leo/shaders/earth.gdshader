shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D day_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D night_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D clouds_map : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction = vec3(0.0, 0.3, -1.0);
uniform float elapsed_days = 0.0;
varying vec3 outward;

void vertex() {
    outward = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec3 n = normalize(outward);
    float illumination = dot(n, normalize(sun_direction));
    float daylight = smoothstep(-0.12, 0.21, illumination);
    vec3 day_albedo = texture(day_map, UV).rgb;
    vec3 night_sample = texture(night_map, UV).rgb;
    float light_level = dot(night_sample, vec3(0.299, 0.587, 0.114));
    float urban = pow(max(light_level, 0.0), 1.27) * 3.2;
    vec3 city_lights = vec3(1.00, 0.66, 0.27) * urban * (1.0 - daylight);
    float cloud_level = dot(texture(clouds_map, UV + vec2(elapsed_days * 0.0006, 0.0)).rgb,
        vec3(0.299, 0.587, 0.114));
    float cloud_cover = smoothstep(0.26, 0.77, cloud_level) * 0.79;
    vec3 planet = day_albedo * (0.070 + 1.06 * daylight) + city_lights;
    planet = mix(planet, vec3(0.72, 0.79, 0.86) * (0.10 + 1.14 * daylight), cloud_cover);
    float limb = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.4);
    planet += vec3(0.02, 0.11, 0.22) * limb * (0.3 + 0.7 * daylight);
    ALBEDO = planet;
}
