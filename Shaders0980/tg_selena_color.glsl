#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

vec4  ColorMapSelena(vec3 point, float height, float slope, vec3 norm)
{
    // Biome domains
    vec3  p = point * mainFreq + Randomize;
    vec4  col;
    noiseOctaves = 6;
    vec3  distort = p * 2.3 + 13.5 * Fbm3D(p * 0.06);
    vec2  cell = Cell3Noise2Color(distort, col);
    float biome = col.r;
    float biomeScale = saturate(2.0 * (pow(abs(cell.y - cell.x), 0.7) - 0.05));

    // Assign a material
    noiseOctaves = 12.0;
    float mat, dist, lat, latitude;

    if (tidalLock <= 0.0)
    {
        lat = abs(point.y);
        latitude = lat + 0.15 * (Fbm(point * 0.7 + Randomize) - 1.0);
        latitude = saturate(latitude);
        mat = height;
    }
    else
    {
        lat = 1.0 - point.x;
        latitude = lat + 0.15 * (Fbm(point * 0.7 + Randomize) - 1.0);
        mat = mix(climateTropic, climatePole, latitude);
    }

    // Color texture distortion
    noiseOctaves = 15.0;
    dist = 1.5 * floor(2.0 * DistFbm(point * 0.002 * colorDistFreq, 2.0));
    mat += colorDistMagn * dist;

    // Color texture variation
    noiseOctaves = 5;
    p = point * colorDistFreq * 2.3;
    p += Fbm3D(p * 0.5) * 1.2;
    float vary = saturate((Fbm(p) + 0.7) * 0.7);

    // Shield volcano lava
    if (volcanoOctaves > 0)
    {
        // Global volcano activity mask
        noiseOctaves = 3;
        float volcActivity = saturate((Fbm(point * 1.37 + Randomize) - 1.0 + volcanoActivity) * 5.0);
        // Lava in volcano caldera and flows
	    vec2  volcMask = VolcanoGlowNoise(point);
        volcMask.x *= volcActivity;
		// Model lava as rocks texture
		mat   = mix(mat,   0.0, volcMask.x);
		slope = mix(slope, 0.0, volcMask.x);
    }

    Surface surf = GetSurfaceColor(saturate(mat), slope, vary);

    // Global albedo variations
    noiseOctaves = 8;
    distort = Fbm3D((point + Randomize) * 0.07) * 1.5;
    noiseOctaves = 5;
    float slopeMod = 1.0 - slope;
    vary = saturate(1.0 - Fbm((point + distort) * 0.78) * slopeMod * slopeMod * 2.0);

    // Ice cracks
    float mask = 1.0;
    if (cracksOctaves > 0.0)
        vary *= CrackColorNoise(point, mask);

    // "Freckles" (structures like on Europa)
    if ((biome > hillsFraction) && (biome < hills2Fraction))
    {
        noiseOctaves    = 10.0;
        noiseLacunarity = 2.0;
        vary *= 1.0 - saturate(2.0 * mask * biomeScale * JordanTurbulence(point * hillsFreq + Randomize, 0.8, 0.5, 0.6, 0.35, 1.0, 0.8, 1.0));
    }

    // Apply albedo variations
    surf.color *= mix(vec4(0.67, 0.58, 0.36, 0.00), vec4(1.0), vary);

    // Make driven hemisphere darker
    if (drivenDarkening != 0.0)
    {
        noiseOctaves = 3;
        float z = -point.z * sign(drivenDarkening);
        z += 0.2 * Fbm(point * 1.63);
        z = saturate(1.0 - z);
        z *= z;
        surf.color.rgb *= mix(1.0 - abs(drivenDarkening), 1.0, z);
    }
        
    // Rayed craters
    if (craterSqrtDensity * craterSqrtDensity * craterRayedFactor > 0.05 * 0.05)
    {
        float craterRayedSqrtDensity = craterSqrtDensity * sqrt(craterRayedFactor);
        float craterRayedOctaves = floor(craterOctaves * craterRayedFactor);
        float crater = RayedCraterColorNoise(point, craterFreq, craterRayedSqrtDensity, craterRayedOctaves);
        surf.color.rgb = mix(surf.color.rgb, vec3(1.0), crater);
    }

    // Ice caps - thin frost
    // TODO: make it only on shadowed slopes
    float iceCap = saturate((latitude - latIceCaps) * 2.0);
    surf.color.rgb = mix(surf.color.rgb, vec3(1.0), 0.4 * iceCap);

    return surf.color;
}

//-----------------------------------------------------------------------------

void main()
{
    vec3  point = GetSurfacePoint();
    float height, slope;
    vec3  norm;
    GetSurfaceHeightAndSlopeAndNormal(height, slope, norm);
    OutColor = ColorMapSelena(point, height, slope, norm);
}

//-----------------------------------------------------------------------------

#endif
