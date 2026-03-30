#version 330 core
#auto_defines

uniform sampler2D Texture;
uniform mat4x4    Mvp;
uniform vec4      EyePos;
uniform vec4      FadeParams;
uniform vec3      Reddening;

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;
                     out vec2  TexCoord;
                     out vec3  PixPos;

void main()
{
    gl_Position = Mvp * VertexPos;
    TexCoord = VertexTexCoord.xy;
    PixPos = VertexPos.xyz;
}

#else

                     in  vec2  TexCoord;
                     in  vec3  PixPos;
layout(location = 0) out vec4  OutColor;

void main()
{
    vec3  ray  = PixPos + EyePos.xyz;
    float dist = length(ray);
    float fade = clamp((dist - FadeParams.x) * FadeParams.y, 0.0, 1.0) *
                 clamp((abs(ray.z / dist) - FadeParams.z) * FadeParams.w, 0.0, 1.0);
    OutColor = fade * texture(Texture, TexCoord);
    OutColor.rgb *= EyePos.w;

    OutColor.rgb *= Reddening;
    OutColor = clamp(OutColor, 0.0, 1.0);
}

#endif
