#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

float   HeightMapTerra(vec3 point)
{
    // Assign a climate type
    noiseOctaves = (surfClass == 1.0) ? 5.0 : 12.0;
    noiseH          = 0.5;
    noiseLacunarity = 2.218281828459;
    noiseOffset     = 0.8;
    float climate, latitude;
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

    // Global landscape
    vec3 p = point * mainFreq + Randomize;
    noiseOctaves = 5;
    vec3  distort = 0.35 * Fbm3D(p * 0.73);
    noiseOctaves = 4;
    distort += 0.005 * (1.0 - abs(Fbm3D(p * 132.3)));
    float global = 1.0 - Cell3Noise(p + distort);

    // Venus-like structure
    float venus = 0.0;
    if (venusMagn > 0.05)
    {
        noiseOctaves = 4;
        distort = Fbm3D(point * 0.3) * 1.5;
        noiseOctaves = 6;
        venus = Fbm((point + distort) * venusFreq) * venusMagn;
    }

    global = (global + venus - seaLevel) * 0.5 + seaLevel;
    float shore = saturate(70.0 * (global - seaLevel));

    // Biome domains
    noiseOctaves = 6;
    p = p * 2.3 + 13.5 * Fbm3D(p * 0.06);
    vec4  col;
    vec2  cell = Cell3Noise2Color(p, col);
    float biome = col.r;
    float biomeScale = saturate(2.0 * (pow(abs(cell.y - cell.x), 0.7) - 0.05));
    float terrace = col.g;
    float terraceLayers = max(col.b * 10.0 + 3.0, 3.0);
    terraceLayers += Fbm(p * 5.41);

    float montRage = saturate(DistNoise(point * 22.6 + Randomize, 2.5) + 0.5);
    montRage *= montRage;
    float montBiomeScale = min(pow(2.2 * biomeScale, 2.5), 1.0) * montRage;

    float inv2montesSpiky = 1.0 /(montesSpiky*montesSpiky);
    float heightD = 0.0;
    float height = 0.0;
    float dist;

    if (biome < dunesFraction)
    {
        // Dunes
        noiseOctaves = 2.0;
        dist = dunesFreq + Fbm(p * 1.21);
        //heightD = max(Fbm(p * dist * 0.3) + 0.7, 0.0);
        //heightD = biomeScale * dunesMagn * (heightD + DunesNoise(point, 3));
        heightD = 0.2 * max(Fbm(p * dist * 0.3) + 0.7, 0.0);
        heightD = biomeScale * dunesMagn * (heightD + DunesNoise(point, 3));
    }
    else if (biome < hillsFraction)
    {
        // "Eroded" hills
        noiseOctaves = 10.0;
        noiseH       = 1.0;
        noiseOffset  = 1.0;
        height = biomeScale * hillsMagn * (1.5 - RidgedMultifractal(point * hillsFreq + Randomize, 2.0));
    }
    else if (biome < hills2Fraction)
    {
        // "Eroded" hills 2
        noiseOctaves = 10.0;
        noiseLacunarity = 2.0;
        height = biomeScale * hillsMagn * JordanTurbulence(point * hillsFreq + Randomize, 0.8, 0.5, 0.6, 0.35, 1.0, 0.8, 1.0);
    }
    else if (biome < canyonsFraction)
    {
        // Canyons
        noiseOctaves = 5.0;
        noiseH       = 0.9;
        noiseLacunarity = 4.0;
        noiseOffset  = montesSpiky;
        height = -canyonsMagn * montRage * RidgedMultifractalErodedDetail(point * 4.0 * canyonsFreq * inv2montesSpiky + Randomize, 2.0, erosion, montBiomeScale);

        //if (terrace < terraceProb)
        {
            terraceLayers *= 5.0;
            float h = height * terraceLayers;
            height = (floor(h) + smoothstep(0.1, 0.9, fract(h))) / terraceLayers;
        }
    }
    else
    {
        // Mountains
        noiseOctaves = 10.0;
        noiseH       = 1.0;
        noiseLacunarity = 2.0;
        noiseOffset  = montesSpiky;
        height = montesMagn * montRage * RidgedMultifractalErodedDetail(point * montesFreq * inv2montesSpiky + Randomize, 2.0, erosion, montBiomeScale);

        if (terrace < terraceProb)
        {
            float h = height * terraceLayers;
            height = (floor(h) + smoothstep(0.0, 1.0, fract(h))) / terraceLayers;
            height *= 0.75; // terracing made slopes too steep; reduce overall mountains height to reduce this effect
        }
    }

    // Mare
    float mare = global;
    float mareFloor = global;
    float mareSuppress = 1.0;
    if (mareSqrtDensity > 0.05)
    {
        //noiseOctaves = 2;
        //mareFloor = 0.6 * (1.0 - Cell3Noise(0.3*p));
        noiseH           = 0.5;
        noiseLacunarity  = 2.218281828459;
        noiseOffset      = 0.8;
        craterDistortion = 1.0;
        noiseOctaves     = 6.0;  // Mare roundness distortion
        mare = MareNoise(point, global, 0.0, mareSuppress);
        //lithoCells *= 1.0 - saturate(20.0 * mare);
    }

    height *= saturate(20.0 * mare);        // suppress mountains, canyons and hill (but not dunes) inside mare
    height = (height + heightD) * shore;    // suppress all landforms inside seas
    //height *= lithoCells;                   // suppress all landforms inside lava seas

    // Ice caps
    float oceaniaFade = (surfClass == 1.0) ? 0.1 : 1.0;
    float iceCap = saturate((latitude / latIceCaps - 1.0) * 50.0 * oceaniaFade);

    // Ice cracks
    float mask = 1.0;
    if (cracksOctaves > 0.0)
        height += CrackNoise(point, mask) * iceCap;

    // Craters
    float crater = 0.0;
    if (craterSqrtDensity > 0.05)
    {
        heightFloor = -0.1;
        heightPeak  =  0.6;
        heightRim   =  1.0;
        crater = CraterNoise(point, 0.5 * craterMagn, craterFreq, craterSqrtDensity, craterOctaves);
        noiseOctaves    = 10.0;
        noiseLacunarity = 2.0;
        crater = 0.25 * crater + 0.05 * crater * iqTurbulence(point * montesFreq + Randomize, 0.55);
    }

    height += mare + crater;

    // Pseudo rivers
    if (riversOctaves > 0)
    {
        noiseOctaves    = riversOctaves;
        noiseLacunarity = 2.218281828459;
        noiseH          = 0.5;
        noiseOffset     = 0.8;
        p = point * mainFreq + Randomize;
        distort = 0.350 * Fbm3D(p * riversSin) +
                  0.035 * Fbm3D(p * riversSin * 5.0) +
                  0.010 * Fbm3D(p * riversSin * 25.0);
        cell = Cell3Noise2(riversFreq * p + distort);
        float pseudoRivers = 1.0 - saturate(abs(cell.y - cell.x) * riversMagn);
        pseudoRivers = smoothstep(0.0, 1.0, pseudoRivers);
        pseudoRivers *= 1.0 - smoothstep(0.06, 0.10, global - seaLevel); // disable rivers inside continents
        pseudoRivers *= 1.0 - smoothstep(0.00, 0.01, seaLevel - height); // disable rivers inside oceans
        height = mix(height, seaLevel-0.02, pseudoRivers);
    }

    // Shield volcano
    if (volcanoOctaves > 0)
        height = VolcanoNoise(point, global, height);

    // Mountain glaciers
    /*noiseOctaves = 5.0;
    noiseLacunarity = 3.5;
    float vary = Fbm(point * 1700.0 + Randomize);
    float snowLine = (height + 0.25 * vary - snowLevel) / (1.0 - snowLevel);
    height += 0.0005 * smoothstep(0.0, 0.2, snowLine);*/

    // Apply ice caps
    height = height * oceaniaFade + icecapHeight * smoothstep(0.0, 1.0, iceCap);

    return height;
}

//-----------------------------------------------------------------------------

void main()
{
    vec3  point = GetSurfacePoint();
    float height = HeightMapTerra(point);
    OutColor = vec4(height);
}

//-----------------------------------------------------------------------------

#endif
