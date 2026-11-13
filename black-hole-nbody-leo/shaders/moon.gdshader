shader_type canvas_item;
render_mode unshaded;

uniform vec3 sunlight = vec3(0.4, 0.1, 0.6);

void fragment() {
    vec2 coordinate = (UV - vec2(0.5)) * 2.0;
    float radial = dot(coordinate, coordinate);
    if (radial > 1.0) {
        discard;
    }
    vec3 n = normalize(vec3(coordinate, sqrt(max(1.0 - radial, 0.0))));
    float lit = clamp(dot(n, normalize(sunlight)), 0.0, 1.0);
    float rim = smoothstep(1.0, 0.97, radial);
    vec3 texture_color = texture(TEXTURE, UV).rgb;
    COLOR = vec4(texture_color * (0.08 + 1.12 * lit), rim);
}
