#version 420

layout(location=0) in  vec4 a_vertex_position;
layout(location=1) in vec3 a_vertex_color;
out vec3 v_Color;

layout(std140, binding=1) uniform Transformations {
    vec2 scale;
    vec2 translation;
    mat2 rotation;
};



void main() {
    gl_Position = a_vertex_position;
    v_Color = a_vertex_color;
}
