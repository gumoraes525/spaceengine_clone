#version 330 core
#auto_defines

uniform vec4    Param;    // GalMagnCoef, GalMagnMin, 2*sigma^2, GalParticleFadeOut
uniform vec4    Param2;   // GalMaxParticleRadiusPix, 1.0 / (GalMaxParticleRadiusPix - 1.0), 1/SpriteScale, Horizon
uniform vec4    ViewPort; // x, y, 0.5*width, 0.5*height
uniform vec2    Aspect;   // xAspect, yAspect
uniform mat4x4  ModelViewMatrix;  // modelview  matrix
uniform mat4x4  ProjectionMatrix; // projection matrix

const float cutoff = 0.002;

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

out vec4 fColorSize;
out vec2 fSpriteCenter;

void main()
{
    vec4 viewPos = ModelViewMatrix * vec4(vPosition, 1.0);
    gl_Position = ProjectionMatrix * viewPos;
    fSpriteCenter = (gl_Position.xy / gl_Position.w + 1.0) * ViewPort.zw + ViewPort.xy;

    float Dist2 = dot(viewPos.xyz, viewPos.xyz);
    float Dist = sqrt(Dist2);
    float HorDist = Dist / Param2.w;

    float mag = Param.x * vLumRad.x / Dist2;
    float RadiusPix = vLumRad.y / (Dist * Param2.z);
    mag *= clamp((Param2.x - RadiusPix) * Param2.y, 0.0, 1.0);
    float fade = clamp(Param.w * (mag - Param.y), 0.0, 1.0);

    mag = sqrt(mag);
    vec3 Reddening = clamp(vec3(1.0) - vec3(1.0, 2.0, 4.0) * HorDist, 0.0, 1.0);
    fColorSize.rgb = vColor.rgb * Reddening * mag * fade;

    fColorSize.w = mag / cutoff;
	gl_PointSize = 2.0 * (sqrt(fColorSize.w) - 1.0) * Param.z;
}

#else

in vec4 fColorSize;
in vec2 fSpriteCenter;

layout(location = 0) out vec4  OutColor;

void main()
{
	float r2 = 1.0 + distance(gl_FragCoord.xy * Aspect, fSpriteCenter) / Param.z;
    r2 *= r2;
    float bright = smoothstep(0.0, 0.4, 1.0 - r2 / fColorSize.w) / r2;
    if (bright == 0.0) discard;
	OutColor.rgb = bright * fColorSize.rgb;
    OutColor.a = 0.0;
    //OutColor.b += 0.05;
}

#endif
