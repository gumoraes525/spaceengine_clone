#version 330 core
#auto_defines

uniform sampler2D Tex;
uniform vec2      Offset[16];
uniform vec2      TexScale;

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;

out vec2  TexCoord;

void main()
{
    gl_Position = VertexPos;
    TexCoord = VertexTexCoord.xy * TexScale;
}

#else

in  vec2  TexCoord;

layout(location = 0) out vec4  OutColor;

void main()
{
    vec4 color = vec4(0.0);
    vec4 pix;
    for (int i=0; i<16; i++)
    {
        pix = texture(Tex, TexCoord + Offset[i]);
        color += clamp(pix * clamp(1.0 + pix.a, 0.0, 1.0), 0.0, 10.0);
    }
    OutColor = color * 0.0625;
}

#endif
