#version 330 core
#auto_defines

uniform sampler2D Texture;
uniform mat4x4    Mvp;
uniform vec4      EyePos;
uniform vec4      FadeParams;
uniform vec4      Clip;

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
    vec3  Vector = PixPos - Clip.xyz;
    float dist2 = dot(Vector, Vector);
    float fade = clamp((dist - FadeParams.x) * FadeParams.y, 0.0, 1.0) *
                 clamp((abs(ray.z / dist) - FadeParams.z) * FadeParams.w, 0.0, 1.0) *
                 clamp((Clip.w - dist2) * 1000.0, 0.0, 1.0);
    OutColor = fade * texture2D(Texture, TexCoord);
    OutColor.rgb *= EyePos.w;
}

#endif
