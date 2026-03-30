#version 330 core
#auto_defines

uniform samplerCube CubeMap;
uniform vec3        OffsetFace;

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

vec3 getCubemapCoord(in vec2 txc, in int face)
{
	vec3 v = vec3(1.0, 0.0, 0.0);
	switch (face)
	{
		case 0: v = vec3(  1.0,  -txc.y, -txc.x); break; // +X
		case 1: v = vec3( -1.0,  -txc.y,  txc.x); break; // -X
		case 2: v = vec3( txc.x,    1.0,  txc.y); break; // +Y
		case 3: v = vec3( txc.x,   -1.0, -txc.y); break; // -Y
		case 4: v = vec3( txc.x, -txc.y,    1.0); break; // +Z
		case 5: v = vec3(-txc.x, -txc.y,   -1.0); break; // -Z
		//case 0: v = vec3( 1.0, -txc.x, txc.y); break; // +X
		//case 1: v = vec3(-1.0,  txc.x, txc.y); break; // -X
		//case 2: v = vec3( txc.x,  1.0, txc.y); break; // +Y
		//case 3: v = vec3(-txc.x, -1.0, txc.y); break; // -Y
		//case 4: v = vec3(txc.x, -txc.y,  1.0); break; // +Z
		//case 5: v = vec3(txc.x,  txc.y, -1.0); break; // -Z
	}
	return normalize(v);
}

void main()
{
	OutColor = texture(CubeMap, getCubemapCoord(TexCoord * 2.0 - vec2(1.0) + OffsetFace.xy, int(OffsetFace.z)));
}

#endif
