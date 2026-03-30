#version 330 core
#auto_defines

// Texture noise is much faster, but makes jerky animation.
// The #auto_defines marco contains one of these defines:
//#define TEX_NOISE - use texture noise for fast aurora
//#define DETAIL    - use datail textures in fragment shader for HD aurora

uniform sampler2D NoiseTex;
uniform mat4x4    ProjectionMatrix;
uniform mat4x4    ModelViewMatrix;
uniform vec4      ScaleTime;    // (sprite width, sprite length, aurora width, time)
uniform vec4      TopColor;
uniform vec4      BottomColor;
uniform vec3      EyePos;
uniform vec4      SunVecClip;   // (SunVec.x, SunVec.y, clip sign, ClipDist2)

//-----------------------------------------------------------------------------
#ifdef TEX_NOISE
//-----------------------------------------------------------------------------

float   Fbm(vec2 point, int octaves)
{
    float Sum = 0.0;
    vec3  PointAmp = vec3(point, 1.0);
    vec3  LacGain  = vec3(2.218281828459, 2.218281828459, 0.671415927);
    for (int i=0; i<octaves; ++i)
    {
        Sum += PointAmp.z * (texture(NoiseTex, PointAmp.xy).r - 0.5);
        PointAmp *= LacGain;
    }
    return Sum;
}

//-----------------------------------------------------------------------------

vec4    Fbm4(vec2 point, int octaves)
{
    vec4  Sum = vec4(0.0);
    vec3  PointAmp = vec3(point, 1.0);
    vec3  LacGain  = vec3(2.218281828459, 2.218281828459, 0.671415927);
    for (int i=0; i<octaves; ++i)
    {
        Sum += PointAmp.z * (texture(NoiseTex, PointAmp.xy) - 0.5);
        PointAmp *= LacGain;
    }
    return Sum;
}

//-----------------------------------------------------------------------------
#else // TEX_NOISE
//-----------------------------------------------------------------------------

float   hash(float n) { return fract(sin(n) * 43758.5453); }

//-----------------------------------------------------------------------------

float   noise(in vec2 x)
{
	vec2 p = floor(x);
    vec2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float  n = p.x + p.y * 57.0;
    return mix(mix(hash(n),        hash(n +  1.0), f.x),
               mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y);
}

//-----------------------------------------------------------------------------

vec4    noise4(in vec2 x)
{
    return vec4(noise(x), noise(x + vec2(0.272, -0.375)), noise(x + vec2(-0.464, 0.674)), noise(x + vec2(0.548, -0.145)));
}

//-----------------------------------------------------------------------------

float   Fbm(in vec2 point, int octaves)
{
    float Sum = 0.0;
    vec3  PointAmp = vec3(point * 256.0, 1.0);
    vec3  LacGain  = vec3(2.218281828459, 2.218281828459, 0.671415927);
    for (int i=0; i<octaves; ++i)
    {
        Sum += PointAmp.z * (noise(PointAmp.xy) - 0.5);
        PointAmp *= LacGain;
    }
    return Sum;
}

//-----------------------------------------------------------------------------

vec4    Fbm4(in vec2 point, int octaves)
{
    vec4  Sum = vec4(0.0);
    vec3  PointAmp = vec3(point * 256.0, 1.0);
    vec3  LacGain  = vec3(2.218281828459, 2.218281828459, 0.671415927);
    for (int i=0; i<octaves; ++i)
    {
        Sum += PointAmp.z * (noise4(PointAmp.xy) - 0.5);
        PointAmp *= LacGain;
    }
    return Sum;
}

//-----------------------------------------------------------------------------
#endif // TEX_NOISE
//-----------------------------------------------------------------------------

// Use texture noise in the pixel shader anyway - it is much faster
float   FbmTex(vec2 point, int octaves)
{
    float Sum = 0.0;
    vec3  PointAmp = vec3(point, 1.0);
    vec3  LacGain  = vec3(2.218281828459, 2.218281828459, 0.671415927);
    for (int i=0; i<octaves; ++i)
    {
        Sum += PointAmp.z * (texture(NoiseTex, PointAmp.xy).r - 0.5);
        PointAmp *= LacGain;
    }
    return Sum;
}

//-----------------------------------------------------------------------------
#ifdef _VERTEX_
//-----------------------------------------------------------------------------

layout(location = 0) in  vec3  VertexPos;   // sprite center world position
layout(location = 1) in  vec4  VertexData;  // phase (hi byte), phase (lo byte), sprite type, sprite id

out vec3  FragPos;
out vec4  TexCoord;
out vec4  Color;
out vec2  NoisePoint;

//-----------------------------------------------------------------------------

void main()
{
    TexCoord.x = mod(floor(VertexData.a * 4.0), 2.0);
    TexCoord.y = mod(floor(VertexData.a * 2.0), 2.0);

    float dist   = length(VertexPos);
    vec3  posVec = VertexPos / dist;

    NoisePoint = posVec.xz + VertexData.xy + SunVecClip.xy;
    vec4  nois = Fbm4(NoisePoint * 0.002, 8);

    vec3  pos = posVec;
    pos.xz *= 1.0 + ScaleTime.z * nois.a;
    pos = normalize(pos);

    vec3  relPos = pos - EyePos;
    dist = dot(relPos, relPos);

    bool clip = (SunVecClip.z > 0.0) ? dist < SunVecClip.w : dist > SunVecClip.w;

    if (clip)
        gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
    else
    {
        // ScaleFade.x : sprite width
        // ScaleFade.y : sprite height
        // ScaleFade.z : sprite top to bottom color interpolator
        // ScaleFade.w : sprite bright
        const vec4 multScaleFade = vec4(0.7, 0.7, 1.4, 0.7);
        const vec4 offsScaleFade = vec4(0.7, 0.7, 0.7, 0.7);
        const vec4 clampParams   = vec4(0.05, 0.0, 2.0, 1.0);
        vec4  ScaleFade = Fbm4(NoisePoint * 0.05, 6) * multScaleFade + offsScaleFade;
        ScaleFade = clamp(ScaleFade, clampParams.xxyy, clampParams.zzww);

        float spriteWidth  = ScaleTime.x / ScaleFade.x * 1.5;
        float spriteLength = ScaleTime.y * ScaleFade.y;
        vec3  spriteDir = posVec * spriteLength;

        vec4  viewPosN = ModelViewMatrix * vec4(pos, 1.0);
        vec4  viewPosO = ModelViewMatrix * vec4(pos + spriteDir, 1.0);
        vec4  viewPos;

        if (TexCoord.x == 0.0)
        {
            viewPos = viewPosN;
            FragPos = pos;
            Color   = BottomColor;
        }
        else
        {
            viewPos = viewPosO;
            FragPos = pos + spriteDir;
            const vec4 offsColor = vec4(0.5, 0.5, 0.5, 0.0);
            vec4  topColor = Fbm4(NoisePoint * 0.07 + vec2(0.0, ScaleTime.w), 8) * offsColor + offsColor;
            Color = mix(BottomColor, topColor * TopColor, ScaleFade.z * 3.0);
        }

        float bright = FbmTex(NoisePoint * 0.0073 + vec2(0.75, 0.37 * ScaleTime.w), 4) + 0.5;
        Color *= bright;

        vec2  Offset = 1.0 - TexCoord.xy * 2.0;
        vec3  Ray    = viewPosN.xyz - viewPosO.xyz;
        float RayLen = length(viewPosN.xy - viewPosO.xy);

        RayLen = length(viewPosN.xy - viewPosO.xy);
        TexCoord.z = RayLen / (RayLen + 2.0*spriteWidth);
        vec3 Tangent = normalize(cross(Ray, viewPosN.xyz));
        mat2x2 Mat = mat2x2(Tangent.y, -Tangent.x, Tangent.x, Tangent.y);
        viewPos.xy += (Mat * Offset) * spriteWidth;

        gl_Position = ProjectionMatrix * viewPos;

        FragPos     *= ScaleTime.x;
        spriteWidth *= 3.0;
        Color        = clamp(Color * ScaleFade.a, 0.0, 1.0);
        TexCoord.w   = ScaleFade.z;
    }
}

//-----------------------------------------------------------------------------
#else
//-----------------------------------------------------------------------------

in  vec3 FragPos;
in  vec4 TexCoord;
in  vec4 Color;
in  vec2 NoisePoint;

layout(location = 0) out vec4 FragColor;

//-----------------------------------------------------------------------------

void main()
{
    // Elongated gaussian "texture"
    vec2 tc = 2.0 * TexCoord.xy - 1.0;
    if (tc.x < 0)
        tc.x = max((tc.x + TexCoord.z) / (TexCoord.z - 1.0), 0.0);
    else
        tc.x = min((tc.x - TexCoord.z) / (TexCoord.z - 1.0), 0.0);
    float bright = exp(-5.55 * dot(tc, tc));

    // Fade out aurora top
    bright *= log(max(2.0 - TexCoord.x, 1.0)) * 2.0;

#ifdef DETAIL
    // Using texture noise in the pixel shader - it is much faster
    // 4 octaves looks bad when rendering in low-res FBO, so 1 octave is enough
    bright *= texture(NoiseTex, NoisePoint * 15.0 + vec2(tc.y * 0.03, 0.0) + vec2(0.0, 0.37) * ScaleTime.w).r * 2.0 - 0.25;
    //bright *= Fbm(NoisePoint * 15.0 + vec2(tc.y * 0.03, 0.0) + vec2(0.0, 0.37) * ScaleTime.w, 4) * 2.0 + 0.75;
#endif

    // Resulting color
    FragColor = Color * bright;
}

//-----------------------------------------------------------------------------

#endif
