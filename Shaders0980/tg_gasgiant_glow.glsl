#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

void main()
{
    float surfTemp = (1.0 - 0.2 * GetSurfaceHeight()) * surfTemperature;
	OutColor = vec4(UnitToColor24(log(surfTemp) * 0.188 + 0.1316), 1.0);
}

//-----------------------------------------------------------------------------

#endif
