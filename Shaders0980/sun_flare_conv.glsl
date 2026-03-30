#version 330 core
#auto_defines

uniform sampler2D   Scene;
uniform sampler2D   Texture;
uniform vec4        Param1; // (SunPosX,      SunPosY,      szie / (fbo.W * ClienSizeX),  size / (fbo.H * ClienSizeY))
uniform vec4        Param2; // (1.0 / fbo.W,  1.0 / fbo.H,   0.5 / Texture.W,              0.5 / Texture.H)
uniform vec4        Param3; // (Radius,       Stride,       Bright,                       aspect)
uniform vec4        Param4; // (flare tex coord transform)

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
    const vec3 Gray = vec3(0.299, 0.587, 0.114);
    vec3 Conv = vec3(0.0);
    vec3 Core;
    vec2 flareTC0 = (TexCoord - Param2.xy) * Param4.zw + Param4.xy;
    vec2 flareTC;
    vec2 Step;

    for (Step.x = -Param3.x; Step.x <= Param3.x; Step.x += Param3.y)
    {
        for (Step.y = -Param3.x; Step.y <= Param3.x; Step.y += Param3.y)
        {
            Core = texture(Scene, Param1.xy - Step * Param1.zw).rgb;
            if (dot(Core, Gray) <= 1.0) continue;
			flareTC = flareTC0 + Step * Param2.zw;
            Conv += Core * texture(Texture, flareTC).rgb;
        }
    }

    OutColor.rgb = Conv * Param3.z;
    OutColor.a = 0.0;
}

#endif
