#version 330 core
#auto_defines

uniform mat4x4 Mvp;
uniform vec4   Color;

#ifdef UNIFORM_VERTEXES
uniform vec3   Vertexes[8];
#endif

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;
layout(location = 2) in  vec4  VertexNormal;

void main()
{
#ifdef UNIFORM_VERTEXES
    gl_Position = Mvp * vec4(Vertexes[int(VertexPos.w)], 1.0);
#else
    gl_Position = Mvp * vec4(VertexPos.xyz, 1.0);
#endif
}

#else

layout(location = 0) out vec4  OutColor;

void main()
{
    OutColor = Color;
}

#endif
