#version 330 core
#auto_defines

#ifdef CUBEMAP
uniform samplerCube Texture;
#else
uniform sampler2D   Texture;
#endif

uniform mat4x4      Mvp;
uniform vec4        Color;
#ifdef TEXCOORD
uniform vec4        TexCoord;
#endif

#ifdef CUBEMAP
uniform int         Face;
#endif

#ifdef UNIFORM_VERTEXES
uniform vec3   Vertexes[8];
#endif

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;

out vec4  fTexCoord;

#ifdef CUBEMAP
vec3    GetCubeTexCoords(vec2 tc)
{
    switch (Face)
    {
        case 0: return vec3(  1.0, -tc.y, -tc.x);  // neg_x
        case 1: return vec3( -1.0, -tc.y,  tc.x);  // pos_x
        case 2: return vec3(-tc.y,  -1.0, -tc.x);  // neg_y
        case 3: return vec3( tc.y,   1.0, -tc.x);  // pos_y
        case 4: return vec3(-tc.x, -tc.y,  -1.0);  // neg_z
        case 5: return vec3( tc.x, -tc.y,   1.0);  // pos_z
    }
}
#endif

void main()
{
#ifdef UNIFORM_VERTEXES
    gl_Position = Mvp * vec4(Vertexes[int(VertexPos.w)], 1.0);
#else
    gl_Position = Mvp * vec4(VertexPos.xyz, 1.0);
#endif

#ifdef CUBEMAP
    fTexCoord.xyz = GetCubeTexCoords(VertexTexCoord.xy * 2.0 - 1.0);
#else
#ifdef TEXCOORD
    fTexCoord.xy = VertexTexCoord.xy * TexCoord.zw + TexCoord.xy;
#else
    fTexCoord.xy = VertexTexCoord.xy;
#endif
#endif
}

#else

in  vec4  fTexCoord;

layout(location = 0) out vec4  OutColor;

void main()
{
#ifdef CUBEMAP
    OutColor = max(texture(Texture, fTexCoord.xyz), 0.0) * Color;
#else
    OutColor = max(texture(Texture, fTexCoord.xy), 0.0) * Color;
#endif
}

#endif
