shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform float rotation_angle = 0.0;
varying vec3 object_normal;
float hash31(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise3(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = mix(hash31(i), hash31(i + vec3(1.0, 0.0, 0.0)), f.x);
    float b = mix(hash31(i + vec3(0.0, 1.0, 0.0)), hash31(i + vec3(1.0, 1.0, 0.0)), f.x);
    float c = mix(hash31(i + vec3(0.0, 0.0, 1.0)), hash31(i + vec3(1.0, 0.0, 1.0)), f.x);
    float d = mix(hash31(i + vec3(0.0, 1.0, 1.0)), hash31(i + vec3(1.0, 1.0, 1.0)), f.x);
    return mix(mix(a,b,f.y),mix(c,d,f.y),f.z);
}
void vertex() { object_normal = NORMAL; }
void fragment() {
    vec3 n = normalize(object_normal);
    float a = rotation_angle;
    vec3 q = vec3(cos(a)*n.x + sin(a)*n.z, n.y, -sin(a)*n.x + cos(a)*n.z);
    float terrain = noise3(q * 5.0) * 0.56 + noise3(q * 15.0) * 0.29 + noise3(q * 39.0) * 0.15;
    float land = smoothstep(0.45,0.57,terrain);
    float cloud = smoothstep(0.57,0.7,noise3(q * 28.0));
    vec3 color = mix(vec3(0.018,0.07,0.18),vec3(0.13,0.28,0.13),land);
    color = mix(color,vec3(0.7,0.76,0.83),cloud * 0.58);
    float day = smoothstep(-0.12,0.36,dot(n,normalize(sun_direction)));
    vec3 lights = vec3(0.75,0.36,0.09) * step(0.83,hash31(floor(q*180.0))) * land * (1.0-day);
    ALBEDO = color * (0.08 + day * 1.5) + lights;
    EMISSION = lights * 0.4 + vec3(0.0,0.025,0.065) * pow(1.0-max(0.0,dot(n,VIEW)),6.0);
}
