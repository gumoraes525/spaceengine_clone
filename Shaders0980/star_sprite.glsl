#version 330 core
#extension GL_EXT_gpu_shader4 : enable
#auto_defines

uniform vec4      Param;    // StarBrightCoef, StarBrightMin, 2*sigma^2, StarPointParticleFadeOut
uniform vec3      Param2;   // StarDist2FOVFactor, 1/GrayBright, 1/SpriteScale
uniform vec4      Param3;   // flareBright, flareDecay
uniform vec4      ViewPort; // x, y, 0.5*width, 0.5*height
uniform vec2      Aspect;   // xAspect, yAspect
uniform mat4x4    ModelViewMatrix;    // modelview  matrix
uniform mat4x4    ProjectionMatrix;	  // projection matrix

#define magInvCutoff 500.0
#define magLimit     100.0
#define flarePower   1.0
#define flareBright  Param3.x
#define flareDecay   Param3.y

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

out vec4 gViewPos;
out vec3 gSpriteCenterSize;
out vec4 gColorSize;

void main()
{
    gViewPos = ModelViewMatrix * vec4(vPosition, 1.0);
    vec4 projPos = ProjectionMatrix * gViewPos;
    gSpriteCenterSize.xy = (projPos.xy / projPos.w + 1.0) * ViewPort.zw + ViewPort.xy;

    float Dist2 = dot(gViewPos.xyz, gViewPos.xyz);
    float mag = Param.x * vLumRad.x / Dist2;
    mag *= step(vLumRad.y * Param2.x, Dist2);
    if (mag > magLimit) mag = pow(magLimit, 0.75) * pow(mag, 0.25);

    float Bright    = mag * clamp(Param.w * (mag - Param.y), 0.0, 1.0);
	float GrayLevel = pow(clamp(mag * Param2.y, 0.0, 1.0), 3);
    float GrayColor = dot(vColor.rgb, vec3(0.299, 0.587, 0.114));
    gColorSize.rgb = mix(vec3(GrayColor), vColor.rgb, GrayLevel) * Bright;

    mag *= magInvCutoff;
	float gaussR2 = log(mag) * Param.z;
	float flareR2 = pow((flareBright * mag * Param.z - 1.0) / flareDecay, 1.0 / flarePower);
    gColorSize.w = max(max(gaussR2, flareR2), 0.0);
	gSpriteCenterSize.z  = sqrt(gColorSize.w) * (-gViewPos.z) * Param2.z;
}

#endif
#ifdef _GEOMETRY_

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

in  vec4 gViewPos[];
in  vec3 gSpriteCenterSize[];
in  vec4 gColorSize[];

out vec2 fSpriteCenter;
out vec4 fColorSize;

void main ()
{
    vec4 offs = vec4(0.0);

    // vertex 0
    fSpriteCenter = gSpriteCenterSize[0].xy;
    fColorSize = gColorSize[0];
	offs.x =  gSpriteCenterSize[0].z;
	offs.y = -gSpriteCenterSize[0].z;
    gl_Position = ProjectionMatrix * (gViewPos[0] + offs);
    EmitVertex();

	// vertex 1
    fSpriteCenter = gSpriteCenterSize[0].xy;
    fColorSize = gColorSize[0];
	offs.x =  gSpriteCenterSize[0].z;
	offs.y =  gSpriteCenterSize[0].z;
    gl_Position = ProjectionMatrix * (gViewPos[0] + offs);
    EmitVertex();

	// vertex 2
    fSpriteCenter = gSpriteCenterSize[0].xy;
    fColorSize = gColorSize[0];
	offs.x = -gSpriteCenterSize[0].z;
	offs.y = -gSpriteCenterSize[0].z;
    gl_Position = ProjectionMatrix * (gViewPos[0] + offs);
    EmitVertex();

	// vertex 3
    fSpriteCenter = gSpriteCenterSize[0].xy;
    fColorSize = gColorSize[0];
	offs.x = -gSpriteCenterSize[0].z;
	offs.y =  gSpriteCenterSize[0].z;
    gl_Position = ProjectionMatrix * (gViewPos[0] + offs);
    EmitVertex();

    EndPrimitive();
}

#endif
#ifdef _FRAGMENT_

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
    //OutColor.g += 0.2;
}

#endif
