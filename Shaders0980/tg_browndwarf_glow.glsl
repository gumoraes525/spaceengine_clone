#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

void main()
{
    vec3  point = GetSurfacePoint();
    float surfTempS = GlowMapSun(point); // in thousand Kelvins

    float height = GetSurfaceHeight();
    float surfTempB = mix(1.0, GetGasGiantCloudsColor(height).a, cloudsLayer);
    surfTempB *= (1.0 - 0.2 * height);

    float surfTemp = mix(surfTempB, surfTempS, erosion) * surfTemperature;

	OutColor = vec4(UnitToColor24(log(surfTemp) * 0.188 + 0.1316), 1.0);
}

//-----------------------------------------------------------------------------

#endif
