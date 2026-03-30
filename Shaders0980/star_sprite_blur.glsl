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
uniform mat4x4    ModelViewOldMatrix; // modelview  matrix form the previous frame

#define magInvCutoff 500.0
#define magLimit     100.0
#define flarePower   1.0
#define flareBright  Param3.x
#define flareDecay   Param3.y

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

out vec2 gLumRad;
out vec4 gColor;

void main()
{
    gl_Position = vec4(vPosition, 1.0);
	gLumRad.x = vLumRad.x * Param.x;
	gLumRad.y = vLumRad.y;
    gColor = vColor;
}

#endif
#ifdef _GEOMETRY_

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

in  vec2 gLumRad[];
in  vec4 gColor[];

out vec4 fSpriteCenter;
out vec4 fColorSize;

void main ()
{
    vec4  viewPosN = ModelViewMatrix    * gl_in[0].gl_Position;
    vec4  viewPosO = ModelViewOldMatrix * gl_in[0].gl_Position;
    viewPosN.z = min(viewPosN.z, -0.009);
    viewPosO.z = min(viewPosO.z, -0.009);

    vec4 projPos, SpriteCenter;
    projPos = ProjectionMatrix * viewPosN;
    SpriteCenter.xy = (projPos.xy / projPos.w + 1.0) * ViewPort.zw + ViewPort.xy;
    projPos = ProjectionMatrix * viewPosO;
    SpriteCenter.zw = (projPos.xy / projPos.w + 1.0) * ViewPort.zw + ViewPort.xy;

    vec3  ray  = viewPosN.xyz - viewPosO.xyz;
    vec2  ray2 = SpriteCenter.xy - SpriteCenter.zw;
    float rayLen = dot(ray2, ray2);
    float blurFade = 1.0 / (sqrt(rayLen) * 0.1 + 1.0);
    vec2  line;
    if (rayLen == 0.0)
    {
        line = vec2(0.0, 1.0);
        viewPosO = viewPosN;
    }
	else
		line = normalize(cross(ray, viewPosN.xyz)).xy;

    float Dist2, mag, Bright, GrayLevel, GrayColor, gaussR2, flareR2, size;
    vec4  ColorSize;
    vec4  offs = vec4(0.0);

    // "new" (leading) vertices
    Dist2 = dot(viewPosN.xyz, viewPosN.xyz);
    mag = blurFade * gLumRad[0].x / Dist2;
    mag *= step(gLumRad[0].y * Param2.x, Dist2);
    if (mag > magLimit) mag = pow(magLimit, 0.75) * pow(mag, 0.25);
	
    Bright    = mag * clamp(Param.w * (mag - Param.y), 0.0, 1.0);
	GrayLevel = pow(clamp(mag * Param2.y, 0.0, 1.0), 3);
    GrayColor = dot(gColor[0].rgb, vec3(0.299, 0.587, 0.114));
    ColorSize.rgb = mix(vec3(GrayColor), gColor[0].rgb, GrayLevel) * Bright;

    mag *= magInvCutoff;
	gaussR2 = log(mag) * Param.z;
	flareR2 = pow((flareBright * mag * Param.z - 1.0) / flareDecay, 1.0 / flarePower);
    ColorSize.w = max(max(gaussR2, flareR2), 0.0);
	size = sqrt(ColorSize.w) * (-viewPosN.z) * Param2.z;

    // vertex 0
    fSpriteCenter = SpriteCenter;
    fColorSize = ColorSize;
	offs.x =  line.y - line.x;
	offs.y = -line.x - line.y;
    gl_Position = ProjectionMatrix * (viewPosN + offs * size);
    EmitVertex();

	// vertex 1
    fSpriteCenter = SpriteCenter;
    fColorSize = ColorSize;
	offs.x =  line.y + line.x;
	offs.y = -line.x + line.y;
    gl_Position = ProjectionMatrix * (viewPosN + offs * size);
    EmitVertex();

    // "old" (trailing) vertices
    Dist2 = dot(viewPosO.xyz, viewPosO.xyz);
    mag = blurFade * gLumRad[0].x / Dist2;
    mag *= step(gLumRad[0].y * Param2.x, Dist2);
    if (mag > magLimit) mag = pow(magLimit, 0.75) * pow(mag, 0.25);
	
    Bright    = mag * clamp(Param.w * (mag - Param.y), 0.0, 1.0);
	GrayLevel = pow(clamp(mag * Param2.y, 0.0, 1.0), 3);
    GrayColor = dot(gColor[0].rgb, vec3(0.299, 0.587, 0.114));
    ColorSize.rgb = mix(vec3(GrayColor), gColor[0].rgb, GrayLevel) * Bright;

    mag *= magInvCutoff;
	gaussR2 = log(mag) * Param.z;
	flareR2 = pow((flareBright * mag * Param.z - 1.0) / flareDecay, 1.0 / flarePower);
    ColorSize.w = max(max(gaussR2, flareR2), 0.0);
	size = sqrt(ColorSize.w) * (-viewPosO.z) * Param2.z;

	// vertex 2
    fSpriteCenter = SpriteCenter;
    fColorSize = ColorSize;
	offs.x = -line.y - line.x;
	offs.y =  line.x - line.y;
    gl_Position = ProjectionMatrix * (viewPosO + offs * size);
    EmitVertex();

	// vertex 3
    fSpriteCenter = SpriteCenter;
    fColorSize = ColorSize;
	offs.x = -line.y + line.x;
	offs.y =  line.x + line.y;
    gl_Position = ProjectionMatrix * (viewPosO + offs * size);
    EmitVertex();

    EndPrimitive();
}

#endif
#ifdef _FRAGMENT_

in vec4 fSpriteCenter;
in vec4 fColorSize;

layout(location = 0) out vec4  OutColor;

float LineDist2(in vec2 P, in vec2 A, in vec2 B)
{
    vec2  ba = B - A;
    vec2  pa = P - A;
    vec2  pb = P - B;
    float d = dot(pa, ba);
    float l = dot(ba, ba);
    if (d <= 0.0)
        return dot(pa, pa);
    else if (d >= l)
        return dot(pb, pb);
    else
    {
        pa -= ba * (d/l);
        return dot(pa, pa);
    }
}

void main()
{
    float r2 = LineDist2(gl_FragCoord.xy * Aspect, fSpriteCenter.xy, fSpriteCenter.zw);
	float gauss = exp(-r2 / Param.z);
	float flare = flareBright * Param.z / (flareDecay * pow(r2, flarePower) + 1.0);
    flare *= smoothstep(0.0, 0.3, 1.0 - r2 / fColorSize.w);
    if (flare == 0.0) discard;

	OutColor.rgb = (gauss + flare) * fColorSize.rgb;
    OutColor.a = dot(clamp(OutColor.rgb, 0.0, 1.0), vec3(0.299, 0.587, 0.114));
    //OutColor.r += 0.2;
}

#endif
