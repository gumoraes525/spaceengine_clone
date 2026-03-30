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

vec3  UnitToColor24(in float unit)
{
    const vec3  factor = vec3(1.0, 255.0, 65025.0);
    const float mask = 1.0 / 256.0;
    vec3 color = unit * factor.rgb;
    color.gb = fract(color.gb);
    color.rg -= color.gb * mask;
    return clamp(color, 0.0, 1.0);
}
 
float ColorToUnit24(in vec3 color)
{
    return dot(color, vec3(1.0, 1.0/255.0, 1.0/65025.0));
}

void main()
{
/*
	vec4  PackedGlowData0 = texture(Tex, TexCoord + Offset.xy);
    float Temp0 = dot(PackedGlowData0.rgb, vec3(1.0, 1.0/255.0, 1.0/65025.0));
	Temp0 = exp(Temp0 / 0.188 - 0.7);

	vec4  PackedGlowData1 = texture(Tex, TexCoord + Offset.zy);
    float Temp1 = dot(PackedGlowData1.rgb, vec3(1.0, 1.0/255.0, 1.0/65025.0));
	Temp1 = exp(Temp1 / 0.188 - 0.7);

	vec4  PackedGlowData2 = texture(Tex, TexCoord + Offset.xw);
    float Temp2 = dot(PackedGlowData2.rgb, vec3(1.0, 1.0/255.0, 1.0/65025.0));
	Temp2 = exp(Temp2 / 0.188 - 0.7);

	vec4  PackedGlowData3 = texture(Tex, TexCoord + Offset.zw);
    float Temp3 = dot(PackedGlowData3.rgb, vec3(1.0, 1.0/255.0, 1.0/65025.0));
	Temp3 = exp(Temp3 / 0.188 - 0.7);

	float Temp = 0.25 * (Temp0 + Temp1 + Temp2 + Temp3);
	Temp = log(Temp) * 0.188 + 0.1316;

    OutColor.rgb = UnitToColor24(Temp);
    OutColor.a = 0.25 * (PackedGlowData0.a + PackedGlowData1.a + PackedGlowData2.a + PackedGlowData3.a);
/*
	vec4  PackedGlowData0 = texture(Tex, TexCoord + Offset.xy);
	float LavaMask0 = step(2.0/3.0, PackedGlowData0.a);
	float CityMask0 = 1.0 - step(1.0/3.0, PackedGlowData0.a);
	float PermMask0 = (1.0 - LavaMask0) * (1.0 - CityMask0);

	vec4  PackedGlowData1 = texture(Tex, TexCoord + Offset.zy);
	float LavaMask1 = step(2.0/3.0, PackedGlowData1.a);
	float CityMask1 = 1.0 - step(1.0/3.0, PackedGlowData1.a);
	float PermMask1 = (1.0 - LavaMask1) * (1.0 - CityMask1);

	vec4  PackedGlowData2 = texture(Tex, TexCoord + Offset.xw);
	float LavaMask2 = step(2.0/3.0, PackedGlowData2.a);
	float CityMask2 = 1.0 - step(1.0/3.0, PackedGlowData2.a);
	float PermMask2 = (1.0 - LavaMask2) * (1.0 - CityMask2);

	vec4  PackedGlowData3 = texture(Tex, TexCoord + Offset.zw);
	float LavaMask3 = step(2.0/3.0, PackedGlowData3.a);
	float CityMask3 = 1.0 - step(1.0/3.0, PackedGlowData3.a);
	float PermMask3 = (1.0 - LavaMask3) * (1.0 - CityMask3);

	if (LavaMask0 + LavaMask1 + LavaMask2 + LavaMask3 > 0)
	{
		const vec3 factor = vec3(1.0, 1.0/255.0, 1.0/65025.0);
		float Temp0  = exp(dot(PackedGlowData0.rgb, factor) * 21.2765957 - 2.8) * LavaMask0;
		float Temp1  = exp(dot(PackedGlowData1.rgb, factor) * 21.2765957 - 2.8) * LavaMask1;
		float Temp2  = exp(dot(PackedGlowData2.rgb, factor) * 21.2765957 - 2.8) * LavaMask2;
		float Temp3  = exp(dot(PackedGlowData3.rgb, factor) * 21.2765957 - 2.8) * LavaMask3;
		float Temp = Temp0 + Temp1 + Temp2 + Temp3;
		Temp = log(0.25 * Temp) * 0.047 + 0.1316;
		OutColor.rgb = UnitToColor24(Temp);
		OutColor.a = 1.0;
	}
	else if (PermMask0 + PermMask1 + PermMask2 + PermMask3 > 0)
	{
		OutColor.rgb = 0.25 * (PackedGlowData0.rgb * PermMask0 + PackedGlowData1.rgb * PermMask1 + PackedGlowData2.rgb * PermMask2 + PackedGlowData3.rgb * PermMask3);
		OutColor.a = 0.5;
	}
	else// if (CityMask0 + CityMask1 + CityMask2 + CityMask3 > 0)
	{
		OutColor.rgb = 0.25 * (PackedGlowData0.rgb * CityMask0 + PackedGlowData1.rgb * CityMask1 + PackedGlowData2.rgb * CityMask2 + PackedGlowData3.rgb * CityMask3);
		OutColor.a = 0.0;
	}
	/*else
	{
		OutColor.rgb = 0.25 * (PackedGlowData0.rgb + PackedGlowData1.rgb + PackedGlowData2.rgb + PackedGlowData3.rgb);
		OutColor.a = 0.0;
	}
/*
	float p = 1.0;

	vec4  PackedGlowData0 = texture(Tex, TexCoord + Offset.xy);
    float Temp0 = dot(PackedGlowData0.rgb, vec3(1.0, 1.0/255.0, 1.0/65025.0));
	Temp0 = pow(exp(Temp0 / 0.188 - 0.7), p);

	vec4  PackedGlowData1 = texture(Tex, TexCoord + Offset.zy);
    float Temp1 = dot(PackedGlowData1.rgb, vec3(1.0, 1.0/255.0, 1.0/65025.0));
	Temp1 = pow(exp(Temp1 / 0.188 - 0.7), p);

	vec4  PackedGlowData2 = texture(Tex, TexCoord + Offset.xw);
    float Temp2 = dot(PackedGlowData2.rgb, vec3(1.0, 1.0/255.0, 1.0/65025.0));
	Temp2 = pow(exp(Temp2 / 0.188 - 0.7), p);

	vec4  PackedGlowData3 = texture(Tex, TexCoord + Offset.zw);
    float Temp3 = dot(PackedGlowData3.rgb, vec3(1.0, 1.0/255.0, 1.0/65025.0));
	Temp3 = pow(exp(Temp3 / 0.188 - 0.7), p);

	float Temp = pow(0.25 * (Temp0 + Temp1 + Temp2 + Temp3), 1.0/p);
	Temp = log(Temp) * 0.188 + 0.1316;

    OutColor.rgb = UnitToColor24(Temp);
    OutColor.a = 0.25 * (PackedGlowData0.a + PackedGlowData1.a + PackedGlowData2.a + PackedGlowData3.a);
/**/
	vec4  PackedGlowData0 = texture(Tex, TexCoord + Offset.xy);
	vec4  PackedGlowData1 = texture(Tex, TexCoord + Offset.zy);
	vec4  PackedGlowData2 = texture(Tex, TexCoord + Offset.xw);
	vec4  PackedGlowData3 = texture(Tex, TexCoord + Offset.zw);
    OutColor = 0.25 * (PackedGlowData0 + PackedGlowData1 + PackedGlowData2 + PackedGlowData3);
/**/
}

#endif
