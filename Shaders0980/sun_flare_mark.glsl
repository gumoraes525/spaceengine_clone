#version 330 core
#auto_defines

uniform vec4    uPosition;
uniform vec4    uColor;
uniform float   PointSize;              // point size
uniform mat4x4  ModelViewMatrix;        // modelview  matrix
uniform mat4x4  ProjectionMatrix;       // projection matrix

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

void main()
{
    vec4 viewPos = ModelViewMatrix * vec4(uPosition.xyz, 1.0);
    viewPos.xyz -= uPosition.w * 1.1 * normalize(viewPos.xyz);    // move particle in front of the object's mesh
    gl_Position  = ProjectionMatrix * viewPos;
    gl_PointSize = PointSize;
}

#else

layout(location = 0) out vec4  OutColor;

void main()
{
    OutColor = uColor;
}

#endif
