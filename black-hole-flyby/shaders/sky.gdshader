shader_type canvas_item;
render_mode unshaded;

uniform float aspect = 1.7777778;
uniform vec2 hole_position = vec2(0.585, 0.380);
uniform float einstein_radius_screen = 0.03;
uniform float shadow_radius_screen = 0.016;
uniform float disruption = 0.0;
uniform float elapsed_time = 0.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float star_layer(vec2 p, float density, float threshold, float size_scale) {
    vec2 cell = floor(p * density);
    vec2 local = fract(p * density);
    float seed = hash21(cell);
    float visible = smoothstep(threshold, 1.0, seed);
    vec2 center = vec2(hash21(cell + vec2(17.3, 43.7)), hash21(cell + vec2(49.1, 12.7)));
    vec2 diff = local - center;
    float radius = length(diff);
    float star = exp(-radius * radius * size_scale) * visible;
    return star * (0.3 + 0.7 * hash21(cell + vec2(14.0, 61.0)));
}

vec3 sample_sky(vec2 p) {
    vec3 base = mix(vec3(0.015, 0.024, 0.050), vec3(0.034, 0.049, 0.102), clamp(1.0 - p.y, 0.0, 1.0));
    float galaxy = exp(-pow((p.y - 0.35 + p.x * 0.25) * 7.0, 2.0));
    float structure = sin(p.x * 38.0 + sin(p.y * 23.0) * 1.8) * 0.5 + 0.5;
    base += vec3(0.043, 0.051, 0.099) * galaxy * (0.4 + 0.6 * structure);
    float warm_cloud = exp(-dot((p - vec2(0.83, 0.21)) * vec2(4.3, 5.2), (p - vec2(0.83, 0.21)) * vec2(4.3, 5.2)));
    base += vec3(0.032, 0.012, 0.060) * warm_cloud;
    float fine = star_layer(p + vec2(0.0, 0.0), 680.0, 0.995, 55.0);
    float medium = star_layer(p + vec2(0.14, 0.22), 270.0, 0.985, 48.0);
    float bright = star_layer(p + vec2(0.24, 0.15), 110.0, 0.965, 35.0);
    base += vec3(0.49, 0.65, 1.0) * fine * 0.85;
    base += vec3(0.74, 0.84, 1.0) * medium * 1.08;
    base += vec3(1.0, 0.78, 0.56) * bright * 1.25;
    return base;
}

void fragment() {
    vec2 d = (UV - hole_position) * vec2(aspect, 1.0);
    float radius = max(length(d), 0.00001);
    float strength = (einstein_radius_screen * einstein_radius_screen) / max(radius * radius, 0.000004);
    vec2 source = hole_position + (d * (1.0 - strength)) / vec2(aspect, 1.0);
    vec3 sky = sample_sky(source);
    float ring_width = max(einstein_radius_screen * 0.13, 0.002);
    float ring = exp(-pow((radius - einstein_radius_screen) / ring_width, 2.0));
    float ring_segment = 0.25 + 0.5 * pow(max(0.0, sin(atan(d.y, d.x) * 4.0 + 0.7)), 3.0);
    sky += vec3(0.29, 0.56, 0.83) * ring * ring_segment * 0.65;
    float halo = exp(-radius / max(einstein_radius_screen * 1.8, 0.02));
    sky += vec3(0.012, 0.025, 0.045) * halo;
    float shadow = 1.0 - smoothstep(shadow_radius_screen * 0.92, shadow_radius_screen * 1.04, radius);
    sky = mix(sky, vec3(0.0001, 0.00015, 0.0004), shadow);
    float red_haze = smoothstep(0.22, 0.9, disruption) * (1.0 - UV.y);
    sky += red_haze * vec3(0.085, 0.022, 0.030);
    float vignette = 1.0 - 0.58 * pow(length((UV - vec2(0.5)) * vec2(1.0, 1.23)), 1.6);
    float flicker = 1.0 - 0.07 * disruption * sin(elapsed_time * 20.0 + UV.y * 16.0);
    COLOR = vec4(max(sky * vignette * flicker, vec3(0.0)), 1.0);
}
