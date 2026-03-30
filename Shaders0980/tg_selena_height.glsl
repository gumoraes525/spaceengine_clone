#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

float   HeightMapSelena(vec3 point)
{
    // Biome domains
    vec3  p = point * mainFreq + Randomize;
    vec4  col;
    noiseOctaves = 6;
    vec3  distort = p * 2.3 + 13.5 * Fbm3D(p * 0.06);
    vec2  cell = Cell3Noise2Color(distort, col);
    float biome = col.r;
    float biomeScale = saturate(2.0 * (pow(abs(cell.y - cell.x), 0.7) - 0.05));

    float montRage = saturate(DistNoise(point * 22.6 + Randomize, 2.5) + 0.5);
    montRage *= montRage;
    float montBiomeScale = min(pow(2.2 * biomeScale, 2.5), 1.0) * montRage;
    float inv2montesSpiky = 1.0 /(montesSpiky*montesSpiky);

    // Global landscape
    noiseOctaves = 4;
    p = point * mainFreq + Randomize;
    distort = 0.35 * Fbm3D(p * 2.37);
    p += distort;// + 0.005 * (1.0 - abs(Fbm3D(p * 132.3)));
    float global = 0.6 * (1.0 - Cell3Noise(p));

    // Venus-like structure
    float venus = 0.0;
    if (venusMagn > 0.05)
    {
        noiseOctaves = 4;
        distort = Fbm3D(point * 0.3) * 1.5;
        noiseOctaves = 6;
        venus = Fbm((point + distort) * venusFreq) * venusMagn;
    }
    global += venus;

    // Mare
    float mare = global;
    float mareFloor = global;
    float mareSuppress = 1.0;
    if (mareSqrtDensity > 0.05)
    {
        noiseOctaves = 2;
        mareFloor = 0.6 * (1.0 - Cell3Noise(0.3*p));
        craterDistortion = 1.0;
        noiseOctaves = 6;  // Mare roundness distortion
        mare = MareNoise(point, global, mareFloor, mareSuppress);
    }

    // Old craters
    float crater = 0.0;
    if (craterSqrtDensity > 0.05)
    {
        heightFloor = -0.1;
        heightPeak  =  0.6;
        heightRim   =  1.0;
        crater = mareSuppress * CraterNoise(point, craterMagn, craterFreq, craterSqrtDensity, craterOctaves);
        noiseOctaves    = 10.0;
        noiseLacunarity = 2.0;
        crater = 0.25 * crater + 0.05 * crater * iqTurbulence(point * montesFreq + Randomize, 0.55);
    }

    float height = mare + crater;

    // Ice cracks
    float mask = 1.0;
    if (cracksOctaves > 0.0)
        height += CrackNoise(point, mask);

    if (biome > hillsFraction)
    {
        if (biome < hills2Fraction)
        {
            // "Freckles" (structures like on Europa)
            noiseOctaves    = 10.0;
            noiseLacunarity = 2.0;
            height += 0.2 * hillsMagn * mask * biomeScale * JordanTurbulence(point * hillsFreq + Randomize, 0.8, 0.5, 0.6, 0.35, 1.0, 0.8, 1.0);
        }
        else if (biome < canyonsFraction)
        {
            // Rimae
            noiseOctaves     = 3.0;
            noiseLacunarity  = 2.218281828459;
            noiseH           = 0.9;
            noiseOffset      = 0.5;
            p = point * mainFreq + Randomize;
            distort  = 0.035 * Fbm3D(p * riversSin * 5.0);
            distort += 0.350 * Fbm3D(p * riversSin);
            cell = Cell3Noise2(canyonsFreq * 0.05 * p + distort);
            float rima = 1.0 - saturate(abs(cell.y - cell.x) * 250.0 * canyonsMagn);
            rima = biomeScale * smoothstep(0.0, 1.0, rima);
            height = mix(height, height-0.02, rima);
        }
        else
        {
            // Mountains
            noiseOctaves    = 10.0;
            noiseLacunarity = 2.0;
            height += montesMagn * montBiomeScale * iqTurbulence(point * 0.5 * montesFreq + Randomize, 0.45);
        }
    }

    // Rayed craters
    if (craterSqrtDensity * craterSqrtDensity * craterRayedFactor > 0.05 * 0.05)
    {
        heightFloor = -0.5;
        heightPeak  =  0.6;
        heightRim   =  1.0;
        float craterRayedSqrtDensity = craterSqrtDensity * sqrt(craterRayedFactor);
        float craterRayedOctaves = floor(craterOctaves * craterRayedFactor);
        float craterRayedMagn = craterMagn * pow(0.62, craterOctaves - craterRayedOctaves);
        crater = RayedCraterNoise(point, craterRayedMagn, craterFreq, craterRayedSqrtDensity, craterRayedOctaves);
        height += crater;
    }

    // Shield volcano
    if (volcanoOctaves > 0)
        height = VolcanoNoise(point, global, height);

    return height;
}

//-----------------------------------------------------------------------------

void main()
{
    vec3  point = GetSurfacePoint();
    float height = HeightMapSelena(point);
    OutColor = vec4(height);
}

//-----------------------------------------------------------------------------

#endif