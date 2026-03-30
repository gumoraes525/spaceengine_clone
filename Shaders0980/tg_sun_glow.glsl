#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

void main()
{
    vec3  point = GetSurfacePoint();
    float surfTemp = GlowMapSun(point);
	surfTemp *= surfTemperature; // in thousand Kelvins
	OutColor = vec4(UnitToColor24(log(surfTemp) * 0.188 + 0.1316), 1.0);
}

//-----------------------------------------------------------------------------

#endif
