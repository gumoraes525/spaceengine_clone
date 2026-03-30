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
	vec3 normVec0;
    normVec0.xy = 2.0 * PackedNormData0.xy - 1.0;
    normVec0.z  = sqrt(1.0 - dot(normVec0.xy, normVec0.xy));
    float height0 = PackedNormData0.w + PackedNormData0.z * 0.00390625;

	vec4 PackedNormData1 = texture(Tex, TexCoord + Offset.zy);
	vec3 normVec1;
    normVec1.xy = 2.0 * PackedNormData1.xy - 1.0;
    normVec1.z  = sqrt(1.0 - dot(normVec1.xy, normVec1.xy));
    float height1 = PackedNormData1.w + PackedNormData1.z * 0.00390625;

	vec4 PackedNormData2 = texture(Tex, TexCoord + Offset.xw);
	vec3 normVec2;
    normVec2.xy = 2.0 * PackedNormData2.xy - 1.0;
    normVec2.z  = sqrt(1.0 - dot(normVec2.xy, normVec2.xy));
    float height2 = PackedNormData2.w + PackedNormData2.z * 0.00390625;

	vec4 PackedNormData3 = texture(Tex, TexCoord + Offset.zw);
	vec3 normVec3;
    normVec3.xy = 2.0 * PackedNormData3.xy - 1.0;
    normVec3.z  = sqrt(1.0 - dot(normVec3.xy, normVec3.xy));
    float height3 = PackedNormData3.w + PackedNormData3.z * 0.00390625;

	vec3  normVec = normalize(normVec0 + normVec1 + normVec2 + normVec3);
	float height = 0.25 * (height0 + height1 + height2 + height3);

    OutColor.xy = normVec.xy * 0.5 + 0.5;
    OutColor.z = fract(height * 256);
    OutColor.w = height - OutColor.z * 0.00390625;
}

#endif
