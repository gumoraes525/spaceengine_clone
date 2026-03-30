#version 330 core
#auto_defines

uniform mat4x4    ProjectionMatrix;
uniform mat4x4    ModelViewMatrix;
uniform vec4      ScaleTime;    // (Length, partCyclePhase, perihelionDist, spriteScale)
uniform vec3      GasColor;
uniform vec3      DustColor;
uniform vec3      CometVel;
uniform vec3      EyePos;
uniform vec4      SunPos;		// (SunPos, 1 / SunDist^2)
uniform vec4      SunCol;

#define km2au 1.0/149598000.0

#ifdef _VERTEX_

layout(location = 0) in  vec3  VertexPos;   // sprite center world position
layout(location = 1) in  vec4  VertexData;  // phase (hi byte), phase (lo byte), sprite type, sprite id

out vec3  FragPos;
out vec4  TexCoord;
out vec4  Color;
out float SpriteSize;

void main()
{
    TexCoord.x = mod(floor(VertexData.a * 4.0), 2.0);
    TexCoord.y = mod(floor(VertexData.a * 2.0), 2.0);

    vec3  posVec = normalize(VertexPos);
    vec3  sunVec = normalize(SunPos.xyz);

    float t = fract(ScaleTime.y + VertexData.r + VertexData.g / 256.0);
    vec3  pos, vel, acc, spriteDir;
    float fade, scale, spriteSize, spriteLength;

    if (VertexData.b == 0.0)
    {
        // gas particles - interaction with solar wind
        Color = vec4(GasColor, 0.0);
        TexCoord.w = 0.0;
        vel        =  0.03 * (1.000 + 13.0 * ScaleTime.z) * posVec;
        vec3  wvel = -14.0 * (1.001 -        ScaleTime.z) * sunVec;
        vec3  dv = dot(vel, sunVec) * sunVec - wvel;
        acc = 0.005 * dot(dv, dv) * sunVec;
        pos = posVec * 0.001 + vel * t + acc * t*t;

        fade  = (1.0 - pow(t, 0.25)) * clamp(t * 50.0, 0.0, 1.0) * clamp(1.0 - ScaleTime.z, 0.0, 1.0) / ScaleTime.w;
        scale = 1.0 + 10.0 * t + 10.0 * ScaleTime.z;
        spriteSize = ScaleTime.x * scale * 0.0025 * ScaleTime.w;
        spriteLength = 0.0001 + 0.1 * pow(clamp(t * 2.0, 0.0, 1.0), 4.0);
        spriteDir = sunVec * spriteLength;
    }
    else
    {
        // dust particles - interaction with solar light (light pressure)
        Color = vec4(DustColor, 0.0);
        TexCoord.w = 1.0;
        vel = 0.1 * (1.0 + 13.0 * ScaleTime.z) * posVec;
        acc = 0.5 * SunPos.w * sunVec - 0.02 * VertexData.b * CometVel;	// km/s
        //vel = 0.03 * (1.000 + 13.0 * ScaleTime.z) * posVec - 0.0003 * CometVel + 0.2 * VertexData.b * sunVec;
        //acc = -0.02 * SunPos.w * sunVec;
        pos = posVec * 0.001 + vel * t + acc * t*t;

        fade  = (1.0 - pow(t, 0.25)) * clamp(t * 50.0, 0.0, 1.0) * clamp(1.0 - ScaleTime.z, 0.0, 1.0) / ScaleTime.w;
        scale = 1.0 + 10.0 * t + 10.0 * ScaleTime.z;
        spriteSize = ScaleTime.x * scale * 0.0075 * ScaleTime.w;
        spriteLength = 0.0001 + 0.1 * pow(clamp(t * 2, 0.0, 1.0), 4.0);
        spriteDir = normalize(acc) * spriteLength;
    }

    vec4  viewPosN = ModelViewMatrix * vec4(pos, 1.0);
    vec4  viewPosO = ModelViewMatrix * vec4(pos + spriteDir, 1.0);

    vec4  viewPos;
    if (TexCoord.x == 0.0)
    {
        viewPos = viewPosN;
        FragPos = pos;
    }
    else
    {
        viewPos = viewPosO;
        FragPos = pos + spriteDir;
    }

    FragPos *= ScaleTime.x * km2au;

    vec2  Offset = 1.0 - TexCoord.xy * 2.0;
    vec3  Ray    = viewPosN.xyz - viewPosO.xyz;
    float RayLen = length(viewPosN.xy - viewPosO.xy);

    float l = RayLen / spriteSize;

    RayLen = length(viewPosN.xy - viewPosO.xy);
    TexCoord.z = RayLen / (RayLen + 2.0 * spriteSize);
    vec3 Tangent = normalize(cross(Ray, viewPosN.xyz));
    mat2x2 Mat = mat2x2(Tangent.y, -Tangent.x, Tangent.x, Tangent.y);
    viewPos.xy += (Mat * Offset) * spriteSize;

    gl_Position = ProjectionMatrix * viewPos;

    SpriteSize = 3.0 * spriteSize * km2au;
    Color *= fade;
}

#else

in vec3  FragPos;
in vec4  TexCoord;
in vec4  Color;
in float SpriteSize;

layout(location = 0) out vec4 FragColor;

float HG(float cosa) // Henyey-Greenstein phase function
{
    const float g = -0.3;
	float x = 1.0 + g*g - 2.0*g*cosa;
    return 0.25 * (1.0 - g*g) * inversesqrt(x*x*x);
}

void main()
{
    vec3  eyePosRel = EyePos.xyz + FragPos;
	vec3  sunPosRel = SunPos.xyz + FragPos;
	float eyeDist   = length(eyePosRel);
	float sunDist   = length(sunPosRel);

    vec2  tc = TexCoord.xy * 2.0 - 1.0;
	float s = sign(tc.x);
	tc.x = s * min(s * (tc.x - s * TexCoord.z) / (TexCoord.z - 1.0), 0.0);

    float  r = length(tc);
    float  bright = exp(-1.5 * r) * clamp(1.0 - r, 0.0, 1.0);
    bright *= clamp(eyeDist / SpriteSize, 0.0, 1.0) * SunCol.a / (sunDist * sunDist + 0.05);
    bright = pow(bright, 0.35);

    // ion sprites - just blue glow
    FragColor = Color * bright;

   // dust sprites - sunlight scattering with the Henyey-Greenstein phase function
    if (TexCoord.w != 0.0)
    {
        float cosa = dot(eyePosRel, sunPosRel) / (eyeDist * sunDist);
        FragColor *= SunCol * (bright / SunCol.a * HG(cosa));
    }
}

#endif
