#version 330 core
#auto_defines

uniform sampler2D Texture;
uniform mat4x4    ModelViewMatrix;
uniform mat4x4    ProjectionMatrix;
uniform vec4      BrightZoom;   // (emBright, absBright, Zoom, cam.PixelSize)
uniform vec3      Reddening;

#ifdef _VERTEX_

layout(location = 0) in  vec3  VertexPos;
layout(location = 1) in  vec4  VertexColor;
layout(location = 2) in  vec4  VertexData; // (tile ID, vertex ID, rotation, size)
                     out vec2  TexCoord;
                     out vec4  Color;

void main()
{
    TexCoord.x = mod(floor(VertexData.y * 4.0), 2.0);
    TexCoord.y = mod(floor(VertexData.y * 2.0), 2.0);

    vec4  viewPos   = ModelViewMatrix * vec4(VertexPos, 1.0);
    vec3  viewUpS   = ModelViewMatrix[2].xyz;
    vec3  viewRight = normalize(cross(viewPos.xyz, viewUpS));
    vec3  viewUp    = normalize(cross(viewRight,   viewPos.xyz));
    float spriteSize = BrightZoom.z * VertexData.w;
    float dist = length(viewPos.xyz);

    float rot = VertexData.z * 6.2831853;
    float ca = cos(rot);
    float sa = sin(rot);
    mat2x2 rotMat = mat2x2(ca, sa, -sa, ca);
    vec2   rotation = (TexCoord * 2.0 - vec2(1.0)) * rotMat;

    viewPos.xyz += spriteSize * (rotation.x * viewRight + rotation.y * viewUp);
    gl_Position = ProjectionMatrix * viewPos;

    vec2 TileOffset;
    TileOffset.x = mod(floor(VertexData.x * 128.0), 4.0);
    TileOffset.y = mod(floor(VertexData.x * 256.0), 2.0);
    TexCoord = (TexCoord + TileOffset) * vec2(0.25, 0.5);

    float fade = VertexColor.a * clamp(dist / (spriteSize*BrightZoom.w) - 0.5, 0.0, 1.0);
    if (TileOffset.x > 0.5)
    {
        Color.rgb = -VertexColor.rgb;
        Color.a   = BrightZoom.y * fade;
    }
    else
    {
        Color.rgb = VertexColor.rgb;
        Color.a   = 0.0;
    }
    Color.rgb *= Reddening * BrightZoom.x * fade;
}

#else

                      in vec2  TexCoord;
                      in vec4  Color;
layout(location = 0) out vec4  OutColor;

void main()
{
    OutColor = Color * texture(Texture, TexCoord);
}

#endif
