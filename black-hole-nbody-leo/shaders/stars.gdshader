shader_type canvas_item;
render_mode unshaded;

uniform vec2 black_hole_uv = vec2(0.5, 0.40);
uniform float black_hole_shadow_radius = 0.018;
uniform float black_hole_lens_radius = 0.060;
uniform float aspect = 1.77778;
uniform float sky_rotation = 0.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float smooth_noise(vec2 p) {
    vec2 g = floor(p);
    vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
    return mix(mix(hash21(g), hash21(g + vec2(1.0, 0.0)), f.x),
        mix(hash21(g + vec2(0.0, 1.0)), hash21(g + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float weight = 0.53;
    for (int i = 0; i < 4; i++) {
        value += weight * smooth_noise(p);
        weight *= 0.47;
        p = p * 2.05 + vec2(7.3, 13.1);
    }
    return value;
}

vec3 sample_stars(vec2 u) {
    vec2 p = u + vec2(sky_rotation * 0.015, sky_rotation * 0.008);
    vec3 sky = vec3(0.0035, 0.007, 0.015);
    float arm = abs((p.y + p.x * 0.32 - 0.38) + 0.028 * sin(9.0 * p.x));
    float dust = fbm(p * 24.0 + vec2(0.3, 7.1));
    float gal = exp(-arm * arm * 87.0);
    sky += vec3(0.092, 0.084, 0.12) * gal * (0.11 + 0.95 * dust);
    sky += vec3(0.068, 0.041, 0.019) * exp(-pow((arm - 0.04) * 28.0, 2.0)) * dust * 0.37;
    for (int layer = 0; layer < 3; layer++) {
        float density = 130.0 + float(layer) * 147.0;
        vec2 cell = p * density + float(layer) * 19.7;
        vec2 id = floor(cell);
        vec2 f = fract(cell) - vec2(hash21(id + vec2(2.1, 12.4)), hash21(id + vec2(4.9, 27.3)));
        float seed = hash21(id + vec2(18.8, 4.2));
        float threshold = 0.977 + 0.008 * float(layer);
        float intensity = smoothstep(threshold, 1.0, seed);
        float glow = exp(-dot(f, f) * (230.0 - 39.0 * float(layer))) * intensity;
        sky += mix(vec3(0.62, 0.75, 1.0), vec3(1.0, 0.78, 0.61), hash21(id + vec2(3.5, 9.7))) * glow * (1.7 + 0.2 * float(layer));
    }
    return sky;
}

void fragment() {
    vec2 angle = (UV - black_hole_uv) * vec2(aspect, 1.0);
    float d = length(angle);
    float lens = black_hole_lens_radius;
    float shadow = black_hole_shadow_radius;
    float deflection = lens * lens / max(d, 0.0003);
    float screen_dist = max(d, 0.001);
    vec2 unlensed = UV - angle * (deflection / screen_dist) / vec2(aspect, 1.0) * 0.24;
    vec3 col = sample_stars(unlensed);
    float ring = exp(-pow((d - lens) / max(lens * 0.055, 0.0011), 2.0));
    float arc = 0.24 + 0.76 * pow(sin(3.0 * atan(angle.y, angle.x) + 0.85) * 0.5 + 0.5, 7.0);
    col += vec3(0.36, 0.64, 1.0) * ring * arc * 1.25;
    float halo = exp(-d / max(0.020, lens * 2.0));
    col += halo * vec3(0.006, 0.012, 0.027);
    float silhouette = 1.0 - smoothstep(shadow * 0.94, shadow * 1.05, d);
    col = mix(col, vec3(0.0002), silhouette);
    col *= clamp(1.0 - length(UV - vec2(0.5)) * 0.45, 0.70, 1.0);
    COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
