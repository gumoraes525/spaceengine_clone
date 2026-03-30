#version 330 core
#auto_defines

#ifdef MSAA
uniform sampler2DMS Texture;
uniform ivec3       TexCoord;   // (x, y, NumSamples)
#else
uniform sampler2D   Texture;
uniform vec2        TexCoord;   // (x, y)
#endif

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;

void main()
{
    gl_Position = VertexPos;
}

#else

layout(location = 0) out vec4  OutColor;

void main()
{
#ifdef MSAA

    OutColor = vec4(0.0);

    for (int s=0; s<TexCoord.z; s++)
        OutColor += texelFetch(Texture, TexCoord.xy, s);

    OutColor /= float(TexCoord.z);

#else

    OutColor = texture(Texture, TexCoord);

#endif
}

#endif
