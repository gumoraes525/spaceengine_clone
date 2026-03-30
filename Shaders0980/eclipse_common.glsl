// The include file for SpaceEngine's planetary surface shaders

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

float   EclipseValue(float lightRadius, float casterRadius, float Dist)
{
    float sumRadius = lightRadius + casterRadius;

    // No intersection
    if (Dist >= sumRadius) return 0.0;

    float minRadius;
    float maxPhase;
    if (lightRadius < casterRadius)
    {
        minRadius = lightRadius;
        maxPhase = 1.0;
    }
    else
    {
        minRadius = casterRadius;
        if (lightRadius < 0.001)
            maxPhase = (casterRadius * casterRadius) / (lightRadius * lightRadius);
        else
            maxPhase = (1.0 - cos(casterRadius)) / (1.0 - cos(lightRadius));
    }

    // Full intersection
    if (Dist <= max(lightRadius, casterRadius) - minRadius) return maxPhase;

    float Diff = abs(lightRadius - casterRadius);

    // Partial intersection
    return maxPhase * smoothstep(0.0, 1.0, 1.0 - clamp((Dist-Diff)/(sumRadius-Diff), 0.0, 1.0));
}

//-----------------------------------------------------------------------------

float   EclipseShadow(mat4x4 LightCasters, vec3 FragPosS, vec3 lightVec, float lightAngularRadius)
{
    float  Shadow = 1.0;
    for (int i=0; i<4; ++i)
    {
        if (LightCasters[i].w <= 0.0) break;
        vec3  lightCasterPos = LightCasters[i].xyz - FragPosS;
        float lightCasterInvDist  = inversesqrt(dot(lightCasterPos, lightCasterPos));
        float casterAngularRadius = asin(clamp(LightCasters[i].w * lightCasterInvDist, 0.0, 1.0));
        float lightToCasterAngle  = asin(clamp(length(cross(lightVec, lightCasterPos * lightCasterInvDist)), 0.0, 1.0));
        Shadow *= clamp(1.0 - EclipseValue(lightAngularRadius, casterAngularRadius, lightToCasterAngle), 0.0, 1.0);
    }
    return 1.0 - Shadow;
}

//-----------------------------------------------------------------------------

#endif
