#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

void main()
{
    vec3  point   = GetSurfacePoint();
    float heightS = HeightMapSun(point);
    float heightB = HeightMapCloudsGasGiant(point);
    float height  = mix(heightB, heightS, erosion);
    OutColor = vec4(height);
}

//-----------------------------------------------------------------------------

#endif
