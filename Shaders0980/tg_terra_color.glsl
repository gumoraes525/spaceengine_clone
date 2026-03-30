#include "tg_common.glsl"

#ifdef _FRAGMENT_

//#define VISUALIZE_BIOMES

//-----------------------------------------------------------------------------

vec4  ColorMapTerra(vec3 point, float height, float slope)
{
    // Biome domains
    vec3  p = point * mainFreq + Randomize;
    vec4  col;
    noiseOctaves = 6;
    vec3  distort = p * 2.3 + 13.5 * Fbm3D(p * 0.06);
    vec2  cell = Cell3Noise2Color(distort, col);
    float biome = col.r;
    float biomeScale = saturate(2.0 * (pow(abs(cell.y - cell.x), 0.7) - 0.05));
    float vary;

#ifdef VISUALIZE_BIOMES
    vec4  colorOverlay;
    if (biome < dunesFraction)
        colorOverlay = vec4(1.0, 1.0, 0.0, 0.0);
    else if (biome < hillsFraction)
        colorOverlay = vec4(0.0, 1.0, 0.0, 0.0);
    else if (biome < hills2Fraction)
        colorOverlay = vec4(0.0, 1.0, 0.5, 0.0);
    else if (biome < canyonsFraction)
        colorOverlay = vec4(1.0, 0.0, 0.0, 0.0);
    else
        colorOverlay = vec4(1.0, 1.0, 1.0, 0.0);
#endif

    Surface surf;

    // Assign a climate type
    noiseOctaves    = 6.0;
    noiseH          = 0.5;
    noiseLacunarity = 2.218281828459;
    noiseOffset     = 0.8;
    float climate, latitude, dist;
    if (tidalLock <= 0.0)
    {
        latitude = abs(point.y);
        latitude += 0.15 * (Fbm(point * 0.7 + Randomize) - 1.0);
        latitude = saturate(latitude);
        if (latitude < latTropic - tropicWidth)
            climate = mix(climateTropic, climateEquator, (latTropic - tropicWidth - latitude) / latTropic);
        else if (latitude > latTropic + tropicWidth)
            climate = mix(climateTropic, climatePole, (latitude - latTropic - tropicWidth) / (1.0 - latTropic));
        else
            climate = climateTropic;
    }
    else
    {
        latitude = 1.0 - point.x;
        latitude += 0.15 * (Fbm(point * 0.7 + Randomize) - 1.0);
        climate = mix(climateTropic, climatePole, saturate(latitude));
    }

    // Litosphere cells
    //float lithoCells = LithoCellsNoise(point, climate, 1.5);

    // Change climate with elevation
    noiseOctaves    = 5.0;
    noiseLacunarity = 3.5;
    vary = Fbm(point * 1700.0 + Randomize);
    float snowLine   = height + 0.25 * vary * slope;
    float montHeight = saturate((height - seaLevel) / (snowLevel - seaLevel));
    climate = min(climate + 0.5 * heightTempGrad * montHeight, climatePole - 0.125);
    climate = mix(climate, climatePole, saturate((snowLine - snowLevel) * 100.0));

    // Beach
    float beach = saturate((height / seaLevel - 1.0) * 50.0);
    climate = mix(0.375, climate, beach);

    // Dunes must be made of sand only
    //float dunes = step(dunesFraction, biome) * biomeScale;
    //slope *= dunes;

    // Ice caps
    float iceCap = saturate((latitude / latIceCaps - 1.0) * 50.0);
    climate = mix(climate, climatePole, iceCap);

    // Flatland climate distortion
    noiseOctaves    = 4.0;
    noiseLacunarity = 2.218281828459;
	vec3  pp = (point + Randomize) * (0.0005 * hillsFreq / (hillsMagn * hillsMagn));
    float fr = 0.20 * (1.5 - RidgedMultifractal(pp,         2.0)) +
               0.05 * (1.5 - RidgedMultifractal(pp * 10.0,  2.0)) +
               0.02 * (1.5 - RidgedMultifractal(pp * 100.0, 2.0));
    p = point * (colorDistFreq * 0.005) + vec3(fr);
    p += Fbm3D(p * 0.38) * 1.2;
    vary = Fbm(p) * 0.35 + 0.245;
    climate += vary * beach * saturate(1.0 - 3.0 * slope) * saturate(1.0 - 1.333 * climate);

    // Dunes must be made of sand only
    //climate = mix(0.0, climate, dunes);

    // Color texture distortion
    noiseOctaves = 5.0;
    p = point * colorDistFreq * 0.371;
    p += Fbm3D(p * 0.5) * 1.2;
    vary = saturate(Fbm(p) * 0.7 + 0.5);

    // Shield volcano lava
    vec2 volcMask = vec2(0.0);
    if (volcanoOctaves > 0)
    {
        // Global volcano activity mask
        noiseOctaves = 3.0;
        float volcActivity = saturate((Fbm(point * 1.37 + Randomize) - 1.0 + volcanoActivity) * 5.0);
        // Lava in volcano caldera and flows
	    volcMask = VolcanoGlowNoise(point);
        volcMask.x *= volcActivity;
    }

    // Model lava as rocks texture
	climate = mix(climate, 0.375, volcMask.x);
	slope   = mix(slope,   1.0,   volcMask.x);

    surf = GetSurfaceColor(climate, slope, vary);

    // Sedimentary layers
    noiseOctaves = 4.0;
    float layers = Fbm(vec3(height * 168.4 + 0.17 * vary, 0.43 * (p.x + p.y), 0.43 * (p.z - p.y)));
    //layers *= smoothstep(0.75, 0.8, climate) * (1.0 - smoothstep(0.825, 0.875, climate)); // only rock texture
    layers *= smoothstep(0.5, 0.55, slope);     // only steep slopes
    layers *= step(surf.color.a, 0.01);         // do not make layers on snow
    layers *= saturate(1.0 - 5.0 * volcMask.x); // do not make layers on lava
    layers *= saturate(1.0 - 5.0 * volcMask.y); // do not make layers on volcanos
    surf.color.rgb *= vec3(1.0) - vec3(0.0, 0.5, 1.0) * layers;

    // Global albedo variations
    noiseOctaves = 8.0;
    distort = Fbm3D((point + Randomize) * 0.07) * 1.5;
    noiseOctaves = 5.0;
    vary = 1.0 - Fbm((point + distort) * 0.78);

    // Ice cracks
    float mask = 1.0;
    if (cracksOctaves > 0.0)
        vary *= mix(1.0, CrackColorNoise(point, mask), iceCap);

    // Apply albedo variations
    surf.color *= mix(vec4(0.67, 0.58, 0.36, 0.00), vec4(1.0), vary);

#ifdef VISUALIZE_BIOMES
    surf.color = mix(surf.color, colorOverlay * biomeScale, 0.25);
    //surf.color.rg *= lithoCells;
#endif

    if (surfClass <= 3)   // water mask for planets with oceans
        surf.color.a += saturate((seaLevel - height) * 200.0);

    return surf.color;
}

//-----------------------------------------------------------------------------

void main()
{
    vec3  point = GetSurfacePoint();
    float height, slope;
    GetSurfaceHeightAndSlope(height, slope);
    OutColor = ColorMapTerra(point, height, slope);
}

//-----------------------------------------------------------------------------

#endif
