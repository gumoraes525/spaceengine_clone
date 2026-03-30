#version 330 core
#auto_defines

uniform samplerCube CubeMap;
uniform vec4        Param;      // (scale.x, scale.y, LensAngle, CutOff)
uniform vec4        BackColor;
uniform vec3        Offset;

const float pi = 3.14159265358;

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;

out vec2  Spherical;

void main()
{
    gl_Position = VertexPos;
    Spherical.x = (VertexTexCoord.x * 2.0 - 0.5) * pi;
    Spherical.y = (0.5 - VertexTexCoord.y) * pi;
}

#else

in  vec2  Spherical;

layout(location = 0) out vec4  OutColor;

void main()
{
    vec2 alpha = vec2(sin(Spherical.x), cos(Spherical.x));
    vec2 delta = vec2(sin(Spherical.y), cos(Spherical.y));
    vec3 cubeTexCoord = vec3(delta.y*alpha.x, delta.x, delta.y*alpha.y);
    OutColor = texture(CubeMap, cubeTexCoord);
}

#endif
