shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never;

uniform vec3 sun_direction = vec3(0.0, 0.3, -1.0);

void fragment() {
    vec3 n = normalize(NORMAL);
    float toward_eye = clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
    float rim = pow(1.0 - toward_eye, 4.2);
    ALBEDO = vec3(0.055, 0.38, 0.96) * (1.2 + 1.8 * rim);
    ALPHA = clamp(rim * 0.39 + 0.018, 0.0, 0.51);
}
