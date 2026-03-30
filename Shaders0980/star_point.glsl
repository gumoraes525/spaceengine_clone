#version 330 core
#auto_defines

uniform vec4      Param;    // StarBrightCoef, StarBrightMin, 2*sigma^2, StarPointParticleFadeOut
uniform vec3      Param2;   // StarDist2FOVFactor, 1/GrayBright, 1/SpriteScale
uniform vec4      Param3;   // flareBright, flareDecay
uniform vec4      ViewPort; // x, y, 0.5*width, 0.5*height
uniform vec2      Aspect;   // xAspect, yAspect
uniform mat4x4    ModelViewMatrix;  // modelview  matrix
uniform mat4x4    ProjectionMatrix;	// projection matrix

#define magInvCutoff 500.0
#define magLimit     100.0
#define flarePower   1.0
#define flareBright  Param3.x
#define flareDecay   Param3.y

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

out vec2 fSpriteCenter;
out vec4 fColorSize;

void main()
{
    vec4 viewPos = ModelViewMatrix * vec4(vPosition, 1.0);
    gl_Position = ProjectionMatrix * viewPos;
    fSpriteCenter = (gl_Position.xy / gl_Position.w + 1.0) * ViewPort.zw + ViewPort.xy;

    float Dist2 = dot(viewPos.xyz, viewPos.xyz);
    float mag = Param.x * vLumRad.x / Dist2;
    mag *= step(vLumRad.y * Param2.x, Dist2);
    if (mag > magLimit) mag = pow(magLimit, 0.75) * pow(mag, 0.25);

    float Bright    = mag * clamp(Param.w * (mag - Param.y), 0.0, 1.0);
    float GrayLevel = pow(clamp(mag * Param2.y, 0.0, 1.0), 3);
    float GrayColor = dot(vColor.rgb, vec3(0.299, 0.587, 0.114));
    fColorSize.rgb = mix(vec3(GrayColor), vColor.rgb, GrayLevel) * Bright;

    mag *= magInvCutoff;
    float gaussR2 = log(mag) * Param.z;
	float flareR2 = pow((flareBright * mag * Param.z - 1.0) / flareDecay, 1.0 / flarePower);
    fColorSize.w = max(max(gaussR2, flareR2), 0.0);
    gl_PointSize = 2.0 * sqrt(fColorSize.w);
}

#else

in vec2 fSpriteCenter;
in vec4 fColorSize;

layout(location = 0) out vec4  OutColor;

void main()
{
	vec2  p = gl_FragCoord.xy * Aspect - fSpriteCenter;
	float r2 = dot(p, p);
	float gauss = exp(-r2 / Param.z);
	float flare = flareBright * Param.z / (flareDecay * pow(r2, flarePower) + 1.0);
    flare *= smoothstep(0.0, 0.3, 1.0 - r2 / fColorSize.w);
    if (flare == 0.0) discard;

	OutColor.rgb = (gauss + flare) * fColorSize.rgb;
    OutColor.a = dot(clamp(OutColor.rgb, 0.0, 1.0), vec3(0.299, 0.587, 0.114));
    //OutColor.b += 0.2;
}

#endif
