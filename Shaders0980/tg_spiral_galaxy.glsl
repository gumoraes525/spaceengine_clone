#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

vec3    Rotate2d(float Angle, vec3 Vector)
{
    float  cosa = cos(Angle);
    float  sina = sin(Angle);
    return Vector * mat3x3(cosa, sina, 0.0, -sina, cosa, 0.0, 0.0, 0.0, 1.0);
}

//-----------------------------------------------------------------------------

float   ArmProfile(float fi, float r)
{
    const float fi0 = 0.2;
    //fi = floor(fi / pi);
    //fi = max(sin(floor(fi / pi)), 0.0);
    fi = (fi < fi0) ? fi / fi0 : (1.0 - fi) / (1.0 - fi0);
    return pow(fi, 15.0 * r + 1.0);
}

//-----------------------------------------------------------------------------

float   RayFunc(float fi, float r)
{
    const float r0 = 0.15;
    float t = (r < r0) ? r / r0 : (1.0 - r) / (1.0 - r0);
    //float d = pow(NoiseU(vec3(20.7 * fi, 0.5, 0.5)), 4.0);
    //return sqrt(t) * saturate(pow(d, 8.0) + 1.0 - smoothstep(d, d + 0.75, r));
    float d = ArmProfile(fi, r);
    return pow(t, 1.8) * d;
}

//-----------------------------------------------------------------------------

float   SpiralDensity(vec3 point)
{
    // Compute cyclons
    float cycloneRadius = length(point);
    float cycloneAmpl   = 2.3;
    float weight        = 1.0;
    vec3  twistedPoint  = point;
    float global = 0;
    float distort = 0;
    float turbulence = 0;

    //twistedPoint += 0.15 * Fbm3D(twistedPoint * 1.5);

    if (cycloneRadius < 1.0)
    {
        float dist = 1.0 - cycloneRadius;
        float fi = log(cycloneRadius);
        twistedPoint = Rotate2d(cycloneAmpl*fi, twistedPoint);
    }

    noiseOctaves = 4;
    noiseLacunarity = 3.0;
    distort = Fbm(point * 0.7 + Randomize) * 0.2;

    //twistedPoint.x *= 0.2;
    //twistedPoint.y *= 5.0;
    //noiseOctaves = 2;
    //float global = (Fbm(twistedPoint) + 1.0) * 0.7;
    //float global = abs(sin(pi*2*twistedPoint.x));
    
    noiseLacunarity = 2.0;
    noiseOctaves    = 3;
    float r = length(twistedPoint.xy);
    float fi = atan(twistedPoint.y, twistedPoint.x);
    fi = fract(3 * ((fi / pi) * 0.5 + 0.5));
    global = RayFunc(fi + distort, r) * weight;

    // Compute flow-like distortion
    //noiseOctaves = 6;
    //global = (Fbm(twistedPoint + distort) + 1.0) * 0.7;
    //global = (global + offset) * weight;

    // Compute turbilence features
    noiseOctaves = 5;
    turbulence = Fbm(point * 100.0 + Randomize) * 0.1;
    return  global + turbulence * step(0.1, global);
}

//-----------------------------------------------------------------------------

void main()
{
    vec3  point = vec3(TexCoord.xy, 0.0);
    float height = SpiralDensity(point);
    OutColor = vec4(height);
}

//-----------------------------------------------------------------------------

#endif
