#version 330 core
#auto_defines

uniform sampler2D Tex;
uniform vec2      Step;

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
#if 1
    OutColor  =  texture(Tex, TexCoord) * 0.282095;
    vec2 offs = Step;
    OutColor += (texture(Tex, TexCoord + offs) + texture(Tex, TexCoord - offs)) * 0.265004;
    offs += Step;
    OutColor += (texture(Tex, TexCoord + offs) + texture(Tex, TexCoord - offs)) * 0.219696;
    offs += Step;
    OutColor += (texture(Tex, TexCoord + offs) + texture(Tex, TexCoord - offs)) * 0.160733;
    offs += Step;
    OutColor += (texture(Tex, TexCoord + offs) + texture(Tex, TexCoord - offs)) * 0.103777;
    offs += Step;
    OutColor += (texture(Tex, TexCoord + offs) + texture(Tex, TexCoord - offs)) * 0.0591303;
    offs += Step;
    OutColor += (texture(Tex, TexCoord + offs) + texture(Tex, TexCoord - offs)) * 0.0297326;
    offs += Step;
    OutColor += (texture(Tex, TexCoord + offs) + texture(Tex, TexCoord - offs)) * 0.0131937;
#else
    OutColor  =  texture(Tex, TexCoord) * 0.56419;
    vec2 offs = Step;
    OutColor += (texture(Tex, TexCoord + offs) + texture(Tex, TexCoord - offs)) * 0.439391;
    offs += Step;
    OutColor += (texture(Tex, TexCoord + offs) + texture(Tex, TexCoord - offs)) * 0.207554;
    offs += Step;
    OutColor += (texture(Tex, TexCoord + offs) + texture(Tex, TexCoord - offs)) * 0.0594651;
#endif
}

#endif
