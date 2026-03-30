#version 330 core
#auto_defines

uniform sampler2D Texture;
uniform mat4x4 ModelView;
uniform mat4x4 Projection;

#ifdef _VERTEX_

layout(location = 0) in  vec3  VertexPos;       // Sprite center world position
layout(location = 1) in  vec3  VertexPosOld;    // Sprite center old world position
layout(location = 2) in  vec2  VertexRadLum;    // Radius, Luminosity
layout(location = 3) in  vec4  VertexColor;     // Sprite color
layout(location = 4) in  vec4  VertexTexCoord;  // Sprite texture coordinates

out vec3 vTexCoord;
out vec4 vColor;

void main()
{
    vTexCoord.xy = VertexTexCoord.xy;
    vColor = VertexColor;

    vec4 viewPosN = ModelView * vec4(VertexPos, 1.0);
    vec4 viewPosO = ModelView * vec4(VertexPosOld, 1.0);
    vec4 viewPos = (vTexCoord.x == 0.0) ? viewPosN : viewPosO;

    float spriteSize = VertexRadLum.x;

    vec2  Offset = 1.0 - vTexCoord.xy * 2.0;
    vec3  Ray    = viewPosN.xyz - viewPosO.xyz;
    float RayLen = dot(Ray, Ray);

    if ((RayLen <= 1e-3) && (abs(viewPosN.z - viewPosO.z) <= 1e-4))
    {
        viewPos = viewPosN;
        viewPos.xy += Offset * spriteSize;
        vTexCoord.z = 0.0;
    }
    else
    {
        RayLen = 0.5 * length(viewPosN.xy - viewPosO.xy);
        vTexCoord.z = RayLen / (RayLen + 1.0);
        vec3 Tangent = normalize(cross(Ray, viewPosN.xyz));
        mat2x2 Mat = mat2x2(Tangent.y, -Tangent.x, Tangent.x, Tangent.y);
        viewPos.xy += (Mat * Offset) * spriteSize;
    }

    gl_Position = Projection * viewPos;
}

#else

in vec3 vTexCoord;
in vec4 vColor;
layout(location = 0) out vec4 OutColor;

void main()
{
    vec2 texCoord;
    texCoord.y = vTexCoord.y;
    if (abs(2.0 * vTexCoord.x - 1.0) < vTexCoord.z)
        texCoord.x = 0.5;
    else
    {
        if (vTexCoord.x > 0.5)
            texCoord.x = (vTexCoord.x - vTexCoord.z) / (1.0 - vTexCoord.z);
        else
            texCoord.x = vTexCoord.x / (1.0 - vTexCoord.z);
    }

    OutColor = vColor * texture(Texture, texCoord);
}

#endif
