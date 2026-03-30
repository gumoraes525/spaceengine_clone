#version 330 core
#extension GL_EXT_gpu_shader4 : enable
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
uniform mat4x4  ModelViewMatrix;    // modelview  matrix
uniform mat4x4  ProjectionMatrix;	// projection matrix
uniform mat4x4  ModelViewOldMatrix; // modelview  matrix form the previous frame

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
out vec3 gColor;

void main()
{
    gl_Position = vec4(uPosition, 1.0);
    gLumRad.x = uLumRad.x * Param.x;
    gLumRad.y = uLumRad.y;
    gColor = uColor.rgb;
}

#endif
#ifdef _GEOMETRY_

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

in  vec2 gLumRad[];
in  vec3 gColor[];

out vec4 fColorSize;
out vec4 fSpriteCenter;

void main ()
{
    vec4  viewPosN = ModelViewMatrix    * gl_in[0].gl_Position;
    vec4  viewPosO = ModelViewOldMatrix * gl_in[0].gl_Position;
    viewPosN.z = min(viewPosN.z + gLumRad[0].y, -0.009); // move particle in front of the object's mesh
    viewPosO.z = min(viewPosO.z + gLumRad[0].y, -0.009); // move particle in front of the object's mesh

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

    float Dist2, Dist, mag, gaussR2, flareR2, size, RadiusPix, fade;
    vec4  offs = vec4(0.0);
    vec4  ColorSize;

    // "new" (leading) vertices
    Dist2 = dot(viewPosN.xyz, viewPosN.xyz);
    Dist = sqrt(Dist2);
    mag = blurFade * gLumRad[0].x / Dist2;
    RadiusPix = gLumRad[0].y / (Dist * Param2.y);
    if (mag > magLimit) mag = pow(magLimit, 0.75) * pow(mag, 0.25);
    mag *= smoothstep(Param2.x, 1.0, RadiusPix);
    ColorSize.rgb = gColor[0] * mag * clamp(Param.w * (mag - Param.y), 0.0, 1.0);

    mag *= magInvCutoff;
    gaussR2 = log(mag) * Param.z;
	flareR2 = pow((flareBright * mag * Param.z - 1.0) / flareDecay, 1.0 / flarePower);
    ColorSize.w = max(max(gaussR2, flareR2), 0.0);
	size = sqrt(ColorSize.w) * (-viewPosN.z) * Param2.y;

    // vertex 0
    fColorSize = ColorSize;
    fSpriteCenter = SpriteCenter;
	offs.x =  line.y - line.x;
	offs.y = -line.x - line.y;
    gl_Position = ProjectionMatrix * (viewPosN + offs * size);
    EmitVertex();

	// vertex 1
    fColorSize = ColorSize;
    fSpriteCenter = SpriteCenter;
	offs.x =  line.y + line.x;
	offs.y = -line.x + line.y;
    gl_Position = ProjectionMatrix * (viewPosN + offs * size);
    EmitVertex();

    // "old" (trailing) vertices
    Dist2 = dot(viewPosO.xyz, viewPosO.xyz);
    Dist = sqrt(Dist2);
    mag = blurFade * gLumRad[0].x / Dist2;
    RadiusPix = gLumRad[0].y / (Dist * Param2.y);
    if (mag > magLimit) mag = pow(magLimit, 0.75) * pow(mag, 0.25);
    mag *= smoothstep(Param2.x, 1.0, RadiusPix);
    ColorSize.rgb = gColor[0] * mag * clamp(Param.w * (mag - Param.y), 0.0, 1.0);

    mag *= magInvCutoff;
    gaussR2 = log(mag) * Param.z;
	flareR2 = pow((flareBright * mag * Param.z - 1.0) / flareDecay, 1.0 / flarePower);
    ColorSize.w = max(max(gaussR2, flareR2), 0.0);
	size = sqrt(ColorSize.w) * (-viewPosO.z) * Param2.y;

	// vertex 2
    fColorSize = ColorSize;
    fSpriteCenter = SpriteCenter;
	offs.x = -line.y - line.x;
	offs.y =  line.x - line.y;
    gl_Position = ProjectionMatrix * (viewPosO + offs * size);
    EmitVertex();

	// vertex 3
    fColorSize = ColorSize;
    fSpriteCenter = SpriteCenter;
	offs.x = -line.y + line.x;
	offs.y =  line.x + line.y;
    gl_Position = ProjectionMatrix * (viewPosO + offs * size);
    EmitVertex();

    EndPrimitive();
}

#endif
#ifdef _FRAGMENT_

in vec4 fColorSize;
in vec4 fSpriteCenter;

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
    const vec3 toGray = vec3(0.299, 0.587, 0.114);

    float r2 = LineDist2(gl_FragCoord.xy * Param2.zw, fSpriteCenter.xy, fSpriteCenter.zw);
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
