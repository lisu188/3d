#version 420

layout(location=0) out vec4 vFragColor;
in vec3 v_Color;

layout(std140, binding = 0) uniform Modifier {
 float strength;
 vec3  color; 
};

void main() {
    //vFragColor = vec4(v_Color[0], v_Color[1], v_Color[2], 1.0);
    vFragColor = vec4(v_Color[0]*strength*color[0], v_Color[1]*strength*color[1], v_Color[2]*strength*color[2], 1.0);
}
