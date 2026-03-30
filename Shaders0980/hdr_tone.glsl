#version 330 core
#auto_defines

uniform sampler2D    Base;
uniform vec2         Param; // (Bright, Exposure)

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;

out vec2  TexCoord;

void main()
{
    gl_Position = VertexPos;

#ifndef ALPHA
    TexCoord = VertexTexCoord.xy;
#else
    TexCoord = vec2(VertexTexCoord.x, 1.0 - VertexTexCoord.y);
#endif
}

#else

in  vec2  TexCoord;

layout(location = 0) out vec4  OutColor;

void main()
{
    OutColor = texture(Base, TexCoord) * Param.x;
    OutColor.rgb = 1.0 - exp(-Param.y * OutColor.rgb);

#ifdef LUMA
    OutColor.a = dot(OutColor.rgb, vec3(0.299, 0.587, 0.114)); // compute luminosity (required for FXAA)
#endif
#ifdef ALPHA
    OutColor.a = Param.x;
#endif
}

#endif
