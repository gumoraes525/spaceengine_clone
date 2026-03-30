#version 330 core
#auto_defines

uniform sampler2D   Texture;

#ifdef MODULATE
uniform sampler2D   ModTexture;
#endif

uniform mat4x4      Mvp;
uniform vec4        Color;
uniform vec4        TexCoordTransf;

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;

out vec2  TexCoord;

void main()
{
    gl_Position = Mvp * VertexPos;
    TexCoord = VertexTexCoord.xy;
}

#else

in  vec2  TexCoord;

layout(location = 0) out vec4  OutColor;

void main()
{
#ifdef MODULATE
	vec4  color = texelFetch(ModTexture, ivec2(0, 0), 0);
    float bright = dot(color.rgb, vec3(0.30, 0.59, 0.11));
    color *= clamp(1.0 - color.a, 0.0, 1.0) / max(bright, 0.001);
    OutColor = texture(Texture, TexCoord * TexCoordTransf.zw + TexCoordTransf.xy) * max(Color * color, 0.0);
#else
    OutColor = texture(Texture, TexCoord * TexCoordTransf.zw + TexCoordTransf.xy) * max(Color, 0.0);
#endif
}

#endif
