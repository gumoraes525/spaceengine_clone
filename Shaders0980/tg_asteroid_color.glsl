#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

vec4    ColorMapAsteroid(vec3 point, float height, float slope)
{
    noiseOctaves = 5.0;
    height = DistFbm(point * 3.7 + Randomize, 1.5);

    noiseOctaves = 5.0;
    vec3 p = point * colorDistFreq * 2.3;
    p += Fbm3D(p * 0.5) * 1.2;
    float vary = saturate((Fbm(p) + 0.7) * 0.7);

    Surface surf = GetSurfaceColor(height, slope, vary);
    surf.color.rgb *= 0.5 + slope;
    return surf.color;
}

//-----------------------------------------------------------------------------

void main()
{
    vec3  point = GetSurfacePoint();
    float height, slope;
    GetSurfaceHeightAndSlope(height, slope);
    OutColor = ColorMapAsteroid(point, height, slope);
}

//-----------------------------------------------------------------------------

#endif
