#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

float   HeightMapAsteroid(vec3 point)
{
    // Global landscape
    vec3  p = point * 0.6 + Randomize;
    float height = 0.5 - Noise(p) * 2.0;

    noiseOctaves = 10;
    noiseLacunarity = 2.0;
    height += 0.05 * iqTurbulence(point * 2.0 * mainFreq + Randomize, 0.35);

    // Hills
    noiseOctaves = 5;
    noiseLacunarity  = 2.218281828459;
    float hills = (0.5 + 1.5 * Fbm(p * 0.0721)) * hillsFreq;
    hills = Fbm(p * hills) * 0.15;
    noiseOctaves = 2;
    float hillsMod = smoothstep(0, 1, Fbm(p * hillsFraction) * 3.0);
    height *= 1.0 + hillsMagn * hills * hillsMod;

    // Craters
    heightFloor = -0.1;
    heightPeak  =  0.6;
    heightRim   =  0.4;
    float crater = 0.4 * CraterNoise(point, craterMagn, craterFreq, craterSqrtDensity, craterOctaves);

    noiseOctaves = 10;
    noiseLacunarity = 2.0;
	crater += montesMagn * crater * iqTurbulence(point * montesFreq, 0.52);	

    return height + crater;
}

//-----------------------------------------------------------------------------

void main()
{
    float height = HeightMapAsteroid(GetSurfacePoint());
    OutColor = vec4(height);
}

//-----------------------------------------------------------------------------

#endif
