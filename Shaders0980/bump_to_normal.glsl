#version 330 core
#auto_defines

uniform sampler2D BumpMap;
uniform vec3      Scale;

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
    vec2 dx = vec2(Scale.x, 0.0);
    vec2 dy = vec2(0.0, Scale.y);

    float h  = texture(BumpMap, TexCoord).r;
    float pc = h * Scale.z;
    float pl = texture(BumpMap, TexCoord - dx).r * Scale.z;
    float pr = texture(BumpMap, TexCoord + dx).r * Scale.z;
    float pu = texture(BumpMap, TexCoord - dy).r * Scale.z;
    float pd = texture(BumpMap, TexCoord + dy).r * Scale.z;

    vec3 s;
    s  = normalize(vec3(pu-pc, pc-pl, 1.0));
    s += normalize(vec3(pc-pd, pc-pl, 1.0));
    s += normalize(vec3(pc-pd, pr-pc, 1.0));
    s += normalize(vec3(pu-pc, pr-pc, 1.0));

    s = normalize(s);

    OutColor.xyz = s * 0.5 + 0.5;
    OutColor.w = h;
}

#endif
