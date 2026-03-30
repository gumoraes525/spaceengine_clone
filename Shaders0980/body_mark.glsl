#version 330 core
#auto_defines

uniform vec4    ViewPort;               // x, y, 0.5*width, 0.5*height
uniform vec4    AspectExposure;         // xAspect, yAspect, bright, -1.0/exposure
uniform float   PointSize;              // point size
uniform mat4x4  ModelViewMatrix;        // modelview  matrix
uniform mat4x4  ProjectionMatrix;       // projection matrix

const float PointRadius = 3.5;

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

out vec4  fColor;
out vec2  fSpriteCenter;

void main()
{
    vec4 viewPos = ModelViewMatrix * vec4(vPosition, 1.0);
    viewPos.xyz -= vLumRad.y * 1.1 * normalize(viewPos.xyz);    // move particle in front of the object's mesh
    gl_Position = ProjectionMatrix * viewPos;
    fSpriteCenter = (gl_Position.xy / gl_Position.w + 1.0) * ViewPort.zw + ViewPort.xy;
    fColor = vec4(vColor.rgb * 0.6 * AspectExposure.z, AspectExposure.z);
    gl_PointSize = PointSize;
}

#else

in vec4  fColor;
in vec2  fSpriteCenter;

layout(location = 0) out vec4  OutColor;

void main()
{
	float r = distance(gl_FragCoord.xy * AspectExposure.xy, fSpriteCenter) / PointRadius;
    OutColor = fColor * (1.0 - smoothstep(0.8, 1.0, r));

    // reverse the tone mapping
    OutColor.rgb = log(1.000001 - OutColor.rgb) * AspectExposure.w;
}

#endif
