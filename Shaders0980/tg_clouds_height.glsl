#include "tg_common.glsl"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

void main()
{
    vec3  point  = GetSurfacePoint();
    float height = HeightMapCloudsTerra(point);
    OutColor = vec4(height);
}

//-----------------------------------------------------------------------------

#endif
