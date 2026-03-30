#version 330 core
#auto_defines

#ifdef MODULATE
uniform sampler2D   ModTexture;
#endif

uniform vec3    uPosition;
uniform vec2    uLumRad;
uniform vec3    uColor;
uniform vec4    Param;    // PlanMagnCoef, PlanMagnMin, 2*sigma^2, PlanParticleFadeOut
uniform vec4    Param2;   // PlanMaxParticleRadiusPix, 1/SpriteScale, xAspect, yAspect
uniform vec4    Param3;   // flareBright, flareDecay
uniform vec4    ViewPort; // x, y, 0.5*width, 0.5*height
uniform mat4x4  ModelViewMatrix;  // modelview  matrix
uniform mat4x4  ProjectionMatrix; // projection matrix

#define magInvCutoff 500.0
#define magLimit     100.0
#define flarePower   1.0
#define flareBright  Param3.x
#define flareDecay   Param3.y

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

out vec4 fColorSize;
out vec2 fSpriteCenter;

void main()
{
    vec4 viewPos = ModelViewMatrix * vec4(uPosition, 1.0);
    viewPos.z += vLumRad.y;    // move particle in front of the object's mesh
    gl_Position = ProjectionMatrix * viewPos;
    fSpriteCenter = (gl_Position.xy / gl_Position.w + 1.0) * ViewPort.zw + ViewPort.xy;

    float Dist2 = dot(viewPos.xyz, viewPos.xyz);
    float Dist = sqrt(Dist2);

    float mag = Param.x * uLumRad.x / Dist2;
    float RadiusPix = uLumRad.y / (Dist * Param2.y);
    if (mag > magLimit) mag = pow(magLimit, 0.75) * pow(mag, 0.25);
    mag *= smoothstep(Param2.x, 1.0, RadiusPix);
    fColorSize.rgb = uColor.rgb * mag * clamp(Param.w * (mag - Param.y), 0.0, 1.0);

    mag *= magInvCutoff;
    float gaussR2 = log(mag) * Param.z;
	float flareR2 = pow((flareBright * mag * Param.z - 1.0) / flareDecay, 1.0 / flarePower);
    fColorSize.w  = max(max(gaussR2, flareR2), 0.0);
    gl_PointSize  = 2.0 * sqrt(fColorSize.w);
}

#else

in vec4 fColorSize;
in vec2 fSpriteCenter;

layout(location = 0) out vec4  OutColor;

void main()
{
    const vec3 toGray = vec3(0.299, 0.587, 0.114);

    vec2  p = gl_FragCoord.xy * Param2.zw - fSpriteCenter;
	float r2 = dot(p, p);
	float gauss = exp(-r2 / Param.z);
	float flare = flareBright * Param.z / (flareDecay * pow(r2, flarePower) + 1.0);
    flare *= smoothstep(0.0, 0.3, 1.0 - r2 / fColorSize.w);
    if (flare == 0.0) discard;

	OutColor.rgb = (gauss + flare) * fColorSize.rgb;

#ifdef MODULATE
	vec4  modColor = texelFetch(ModTexture, ivec2(0, 0), 0);
    float bright = dot(modColor.rgb, toGray);
    modColor *= clamp(1.0 - modColor.a, 0.0, 1.0) / max(bright, 0.001);
    OutColor.rgb *= modColor.rgb;
#endif

    OutColor.a = dot(clamp(OutColor.rgb, 0.0, 1.0), toGray);
    //OutColor.r += 0.2;
}

#endif
