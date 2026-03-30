#version 330 core
#auto_defines

uniform sampler2D   FrameLeft;
uniform sampler2D   FrameRight;
uniform vec4        LeftMask;
uniform vec4        RightMask;

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
	OutColor = texture(FrameLeft, TexCoord) * LeftMask + texture(FrameRight, TexCoord) * RightMask;
}

#endif
