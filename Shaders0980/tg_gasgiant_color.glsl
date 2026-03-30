#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

float   HeightMapFogGasGiant(vec3 point)
{
    return 0.75 + 0.3 * Noise(point * vec3(0.2, 6.0, 0.2));
}

//-----------------------------------------------------------------------------

void main()
{
    if (cloudsLayer == 0.0)
    {
        float height = GetSurfaceHeight();
        OutColor.rgb = height * GetGasGiantCloudsColor(height).rgb;
        OutColor.a = 5.0 * dot(OutColor.rgb, vec3(0.299, 0.587, 0.114));
    }
    else
    {
        float height = HeightMapFogGasGiant(GetSurfacePoint());
        OutColor.rgb = height * GetGasGiantCloudsColor(1.0).rgb;
        OutColor.a = 1.0;
    }
}

//-----------------------------------------------------------------------------

#endif
