shader_type canvas_item;
render_mode unshaded;

uniform float aspect = 1.7777778;
uniform float elapsed_time = 0.0;
uniform float disruption = 0.0;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float n = 0.0;
    float a = 0.53;
    for (int i = 0; i < 4; i++) {
        n += a * noise2(p);
        p = p * 2.07 + vec2(8.7, 3.4);
        a *= 0.50;
    }
    return n;
}

void fragment() {
    vec2 pos = vec2((UV.x - 0.47) * aspect, UV.y - 2.67);
    float radius = 2.03;
    float distance_to_center = length(pos);
    float shell = radius - distance_to_center;
    float inside = smoothstep(-0.004, 0.004, shell);
    float haze = exp(-abs(shell) * 57.0);
    float z = sqrt(max(radius * radius - dot(pos, pos), 0.000001)) / radius;
    vec3 normal = normalize(vec3(pos / radius, z));
    vec2 geographical = vec2(atan(normal.x, normal.z) * 7.5 + 2.5,
        normal.y * 8.0 + 1.4);
    float continents = fbm(geographical * 0.84 + vec2(2.7, 0.9));
    continents += 0.11 * noise2(geographical * 2.8);
    float land = smoothstep(0.43, 0.58, continents);
    float ocean_noise = fbm(geographical * 1.8 + vec2(4.0, 8.0));
    vec3 ocean = mix(vec3(0.012, 0.055, 0.118), vec3(0.040, 0.205, 0.345), ocean_noise);
    vec3 continent_color = mix(vec3(0.065, 0.125, 0.085), vec3(0.27, 0.30, 0.19),
        fbm(geographical * 2.5 + vec2(8.4, 2.6)));
    vec3 surface = mix(ocean, continent_color, land);
    vec3 direction_to_sun = normalize(vec3(0.90, 0.04, 0.52));
    float illumination = dot(normal, direction_to_sun);
    float daylight = smoothstep(-0.20, 0.52, illumination);
    float clouds = smoothstep(0.53, 0.70,
        fbm(geographical * 3.9 + vec2(elapsed_time * 0.006, 2.4)));
    surface = mix(surface * 0.18, surface * 1.7, daylight);
    surface += vec3(0.32, 0.42, 0.51) * clouds * (0.20 + daylight * 0.80);
    float lights = step(0.925, hash21(floor(geographical * 155.0))) *
        land * (1.0 - daylight) * 0.75;
    surface += vec3(1.0, 0.65, 0.21) * lights;
    surface = mix(surface, vec3(0.27, 0.075, 0.055), disruption * 0.43);
    float rim = pow(1.0 - z, 6.0);
    vec3 atmosphere = vec3(0.035, 0.27, 0.72) *
        (0.24 + daylight * 0.76) * (0.5 + 1.5 * rim);
    vec3 result_color = surface * inside + atmosphere * (haze * 0.78 + inside * rim * 0.45);
    float opacity = clamp(inside + haze * 0.40, 0.0, 1.0);
    COLOR = vec4(result_color, opacity);
}
