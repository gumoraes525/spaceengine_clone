#version 330 core
#auto_defines

uniform vec4      Color;
uniform vec4      PlanetPosMVP; // PlanetPos * ModelView«Í˘ÓMatrix
uniform vec2      VertId;
uniform mat4x4    ModelViewProjMatrix;
uniform mat4x4    ProjectionMatrix;

#ifdef MAP_MODE
uniform mat4x4    ModelViewMatrix;
uniform vec4      PlanetPos;
uniform vec4      Clip;         // (Center, Radius^2)
#endif

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPosId;
out vec4  fColor;
#ifdef MAP_MODE
out vec4  fVertexPos;
#endif

void main()
{
    fColor = Color;
    fColor.a *= fract(VertexPosId.w + 1.0 - VertId.x) * 0.7 + 0.3;
    fColor.a *= step(0.0, VertexPosId.w);

#ifndef MAP_MODE

    // Move 2 vertexes, closest to planet, to the exact planet position
    if (fract(VertId.x - VertexPosId.w) <= VertId.y)
        gl_Position = PlanetPosMVP;
    else
        gl_Position = ModelViewProjMatrix * vec4(VertexPosId.xyz, 1.0);

#else

    // Move 2 vertexes, closest to planet, to the exact planet position
    if (fract(VertId.x - VertexPosId.w) <= VertId.y)
    {
        fVertexPos  = PlanetPos;
        gl_Position = PlanetPosMVP;
    }
    else
    {
        fVertexPos  = vec4(VertexPosId.xyz, 1.0);
        gl_Position = ModelViewProjMatrix * fVertexPos;
    }

    fVertexPos = ModelViewMatrix * fVertexPos;

#endif
}

#else

in  vec4  fColor;
#ifdef MAP_MODE
in  vec4  fVertexPos;
#endif
layout(location = 0) out vec4  OutColor;

void main()
{
#ifdef MAP_MODE
    vec3  Vector = fVertexPos.xyz - Clip.xyz;
    float Dist2 = dot(Vector, Vector);
    OutColor = fColor * clamp((Clip.w - Dist2) * 100.0, 0.0, 1.0);
#else
    OutColor = fColor;
#endif
}

#endif
