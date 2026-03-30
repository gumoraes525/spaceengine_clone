#version 330 core
#auto_defines

uniform sampler2D   guiTexture;
uniform vec2        Param;      // (LensAngle, CutOff)
uniform vec4        Offset;     // (offset.x - 1.0, offset.y - 1.0, zoom.x, zoom.y)
uniform vec3        Warp;       // (warp.x, warp.y, warp.z)
uniform vec4        BackColor;
uniform mat3x3      Rotation;

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;

out vec2  TexCoord;

void main()
{
    gl_Position = VertexPos;
    TexCoord = (VertexTexCoord.xy * 2.0 + Offset.xy) * Offset.zw;
}

#else

in  vec2  TexCoord;

layout(location = 0) out vec4  OutColor;

void main()
{
    float r = length(TexCoord);
    if (r > Param.y)
        OutColor = vec4(0.0);
    else
    {
        float Angle = Param.x * r;
        float sinr = sin(Angle) / r;
        vec3  ray = vec3(cos(Angle), sinr * TexCoord.y, sinr * TexCoord.x) + Warp;
		ray = Rotation * ray;
		if (ray.x > 0)
		{
			vec2 tc = (-ray.zy / ray.x + 1.0) * 0.5;
			OutColor = texture2D(guiTexture, tc);
		}
		else
			OutColor = vec4(0.0);
    }
}

#endif
