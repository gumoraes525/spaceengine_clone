#version 330 core
#auto_defines

uniform sampler2D   Texture;
uniform mat4x4      ProjectionMatrix;
uniform vec4        PosSize;
uniform vec4        Color;
uniform vec4        TexCoordTransf;

#ifdef _VERTEX_

layout(location = 0) in  vec4  vPosition;
layout(location = 1) in  vec4  vTexCoord;
                     out vec2  fTexCoord;

void main()
{
    fTexCoord = vTexCoord.xy * TexCoordTransf.xy + TexCoordTransf.zw;
    float size = length(PosSize.xyz) * PosSize.w;
    gl_Position = ProjectionMatrix * vec4(PosSize.xy + size * (vTexCoord.xy * 2.0 - 1.0), PosSize.z, 1.0);
}

#else

                     in  vec2  fTexCoord;
layout(location = 0) out vec4  OutColor;

void main()
{
    OutColor = texture(Texture, fTexCoord) * Color;
}

#endif
