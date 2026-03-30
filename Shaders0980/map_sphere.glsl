#version 330 core
#auto_defines

uniform mat4x4 ModelViewProj;
uniform vec3   EyeDir;
uniform vec4   Color;

#ifdef _VERTEX_

layout(location = 0) in  vec3  VertexPos;
layout(location = 1) in  vec2  TexCoord;
layout(location = 2) in  vec3  Tangent;

out vec3 vNormal;

void main()
{
    gl_Position = ModelViewProj * vec4(VertexPos, 1.0);
    vNormal = VertexPos;
}

#else

in vec3 vNormal;

layout(location = 0) out vec4 FragColor;

void main()
{
    float R = dot(vNormal, EyeDir);
    FragColor.rgb = Color.rgb * clamp(1.0 - 1.15 * R, 0.0, 1.0);
    FragColor.a = Color.a;
}

#endif
