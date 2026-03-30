#version 330 core
#auto_defines

uniform sampler2D   Base;
uniform sampler2D   Bloom;
#ifdef DITHERING
uniform sampler3D   Noise;
#endif

uniform vec4        Param;  // (BloomBright, Exposure, 1/ViewPortW, 1/ViewPortH)
#ifdef DITHERING
uniform vec2        Param2; // (Time, Amplitude)
#endif

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;

out vec2  TexCoord;

void main()
{
    gl_Position = VertexPos;
    TexCoord = VertexTexCoord.xy;
}

#else

in  vec2  TexCoord;

layout(location = 0) out vec4  OutColor;

void main()
{
    vec4 BaseColor  = texture(Base,  TexCoord);
    vec4 BloomColor = texture(Bloom, TexCoord);
    BloomColor.rgb = max(BloomColor.rgb - vec3(0.3), vec3(0.0));

#ifndef REVERSE
    OutColor.rgb = BaseColor.rgb + BloomColor.rgb * Param.x;    // add bloom texture
    OutColor.rgb = 1.0 - exp(Param.y * OutColor.rgb);           // apply tone mapping to the result
#else
	BaseColor.rgb = log(1.0 - BaseColor.rgb);                   // reverse tone mapping for the base texture
    OutColor.rgb = BaseColor.rgb + BloomColor.rgb * Param.x;    // add bloom texture (BaseColor.rgb and Param.x already premultiplied on Param.y)
    OutColor.rgb = 1.0 - exp(OutColor.rgb);                     // apply tone mapping to the result
#endif

    OutColor.a   = BaseColor.a;

#ifdef DITHERING
    const float N = 256.0;
    vec3  n = texture(Noise, vec3(TexCoord.xy * Param.zw, Param2.x)).rgb * 4.0 - vec3(2.0);
    OutColor.rgb = floor(N * OutColor.rgb + n * Param2.y) / N;
#endif
}

#endif
