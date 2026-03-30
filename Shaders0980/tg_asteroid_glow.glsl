#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

vec4    GlowMapAsteroid(vec3 point, float height, float slope)
{
	// Thermal emission temperature (in thousand Kelvins)
    noiseOctaves = 5;
    vec3  p = point * 600.0 + Randomize;
    float dist = 10.0 * colorDistMagn * Fbm(p * 0.2);
    noiseOctaves = 3;
	float globTemp = 0.95 - abs(Fbm((p + dist) * 0.01)) * 0.08;
    noiseOctaves = 8;
	float varyTemp = abs(Fbm(p + dist));

	// Global surface melting
	float surfTemp = surfTemperature *
		(globTemp + varyTemp * 0.08) *
		saturate(2.0 * (lavaCoverage * 0.4 + 0.4 - 0.8 * height));

	return vec4(UnitToColor24(log(surfTemp) * 0.188 + 0.1316), 1.0);
}

//-----------------------------------------------------------------------------

void main()
{
    vec3  point = GetSurfacePoint();
    float height, slope;
    GetSurfaceHeightAndSlope(height, slope);
    OutColor = GlowMapAsteroid(point, height, slope);
}

//-----------------------------------------------------------------------------

#endif
