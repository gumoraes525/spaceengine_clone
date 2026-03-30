#version 330 core
#auto_defines

uniform sampler2D   FrameLeft;
uniform sampler2D   FrameRight;
uniform float       Resolution; // (ClientSizeX or ClientSizeY)

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
#ifdef HOR
    if ((int(TexCoord.x * Resolution) & 1) == 1)
    	OutColor = textureLod(FrameLeft, TexCoord, 0);
    else
    	OutColor = textureLod(FrameRight, TexCoord, 0);
#else
    if ((int(TexCoord.y * Resolution) & 1) == 1)
    	OutColor = textureLod(FrameLeft, TexCoord, 0);
    else
    	OutColor = textureLod(FrameRight, TexCoord, 0);
#endif
}

#endif
