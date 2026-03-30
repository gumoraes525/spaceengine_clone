#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

void main()
{
    float height = GetSurfaceHeight();
    float a = cloudsLayer - height;
    OutColor.a = exp(-55.0 * a * a) * cloudsCoverage;
    OutColor.rgb = GetGasGiantCloudsColor(height).rgb;
}

//-----------------------------------------------------------------------------

#endif
