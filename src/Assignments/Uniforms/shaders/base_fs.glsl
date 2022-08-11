#version 420

layout(location=0) out vec4 vFragColor;
in vec3 v_Color;

layout(std140, binding = 0) uniform Modifiers {
   float strength;
  vec3 light;
};

void main() {
// passing vector colors to vec4 excluding alfa as its not required 
    vFragColor = vec4(v_Color[0], v_Color[1], v_Color[2], 1.0f);
}
