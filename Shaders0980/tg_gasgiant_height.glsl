#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

void main()
{
    if (cloudsLayer == 0.0)
    {
        vec3  point = GetSurfacePoint();
        float height = HeightMapCloudsGasGiant(point);
        OutColor = vec4(height);
    }
    else
        OutColor = vec4(0.0);
}

//-----------------------------------------------------------------------------

#endif
