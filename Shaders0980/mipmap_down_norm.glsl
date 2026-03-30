#version 330 core
#auto_defines

uniform sampler2D  Tex;
uniform vec4       Offset;

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
	vec4 PackedNormData0 = texture(Tex, TexCoord + Offset.xy);
    vec3 normVec0 = 2.0 * PackedNormData0.xyz - 1.0;

	vec4 PackedNormData1 = texture(Tex, TexCoord + Offset.zy);
    vec3 normVec1 = 2.0 * PackedNormData1.xyz - 1.0;

	vec4 PackedNormData2 = texture(Tex, TexCoord + Offset.xw);
    vec3 normVec2 = 2.0 * PackedNormData2.xyz - 1.0;

	vec4 PackedNormData3 = texture(Tex, TexCoord + Offset.zw);
    vec3 normVec3 = 2.0 * PackedNormData3.xyz - 1.0;

    OutColor.xyz = normalize(normVec0 + normVec1 + normVec2 + normVec3) * 0.5 + 0.5;
    OutColor.w = 0.25 * (PackedNormData0.w + PackedNormData1.w + PackedNormData2.w + PackedNormData3.w);
}

#endif
