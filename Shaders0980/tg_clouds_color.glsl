#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

void main()
{
    float height = GetSurfaceHeight();
    float modulate = saturate(height * height * 3.5 + height);
    OutColor = GetCloudsColor(height) * modulate;
}

//-----------------------------------------------------------------------------

#endif
