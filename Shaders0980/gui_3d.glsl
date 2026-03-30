#version 330 core
#auto_defines

uniform sampler2D   AtlasTexture;
uniform vec4        CoordTransf; // vertex coord offset, vertex coord scale
uniform float       AntiExposure; // 1 / (-Exposure)

#ifdef _VERTEX_

layout(location = 0) in vec2 vPosition;
layout(location = 1) in vec2 vTexCoord;
layout(location = 2) in vec4 vClip;
layout(location = 3) in vec4 vColor;

out vec2 fTexCoord;
out vec4 fColor;

void main()
{
    gl_Position = vec4(vPosition * CoordTransf.zw + CoordTransf.xy, 0.0, 1.0);
    fTexCoord = vTexCoord;
    fColor = vColor;
}

#else

in vec2 fTexCoord;
in vec4 fColor;

layout(location = 0) out vec4 OutColor;

void main()
{
    OutColor = fColor * texture(AtlasTexture, fTexCoord);
    OutColor.rgb = log2(max(1.0 - OutColor.rgb, 1.0e-9)) * AntiExposure;
}

#endif
