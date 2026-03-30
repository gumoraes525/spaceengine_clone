#version 330 core
#extension GL_EXT_gpu_shader4 : enable
#auto_defines

uniform vec4    Param;    // GalMagnCoef, GalMagnMin, 2*sigma^2, GalParticleFadeOut
uniform vec4    Param2;   // GalMaxParticleRadiusPix, 1.0 / (GalMaxParticleRadiusPix - 1.0), 1/SpriteScale, Horizon
uniform vec4    ViewPort; // x, y, 0.5*width, 0.5*height
uniform vec2    Aspect;   // xAspect, yAspect
uniform mat4x4  ModelViewMatrix;    // modelview  matrix
uniform mat4x4  ProjectionMatrix;	// projection matrix
uniform mat4x4  ModelViewOldMatrix; // modelview  matrix form the previous frame

const float cutoff = 0.002;

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

out vec2 gLumRad;
out vec3 gColor;

void main()
{
    gl_Position = vec4(vPosition, 1.0);
    gLumRad = vLumRad;
    gLumRad.x *= Param.x;
    gColor = vColor.rgb;
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

    float Dist2, Dist, HorDist, mag, size, RadiusPix, fade;
    vec4  offs = vec4(0.0);
    vec4  ColorSize;
    vec3  Reddening;

    // "new" (leading) vertices
    Dist2 = dot(viewPosN.xyz, viewPosN.xyz);
    Dist = sqrt(Dist2);
    HorDist = Dist / Param2.w;
    mag = blurFade * gLumRad[0].x / Dist2;
    RadiusPix = gLumRad[0].y / (Dist * Param2.z);
    mag *= clamp((Param2.x - RadiusPix) * Param2.y, 0.0, 1.0);
    fade = clamp(Param.w * (mag - Param.y), 0.0, 1.0);

    mag = sqrt(mag);
    Reddening = clamp(vec3(1.0) - vec3(1.0, 2.0, 4.0) * HorDist, 0.0, 1.0);
    ColorSize.rgb = gColor[0] * Reddening * mag * fade;
    ColorSize.w = mag / cutoff;
	size = (sqrt(ColorSize.w) - 1.0) * (-viewPosN.z) * Param.z * Param2.z;

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
    HorDist = Dist / Param2.w;
    mag = blurFade * gLumRad[0].x / Dist2;
    RadiusPix = gLumRad[0].y / (Dist * Param2.z);
    mag *= clamp((Param2.x - RadiusPix) * Param2.y, 0.0, 1.0);
    fade = clamp(Param.w * (mag - Param.y), 0.0, 1.0);

    mag = sqrt(mag);
    Reddening = clamp(vec3(1.0) - vec3(1.0, 2.0, 4.0) * HorDist, 0.0, 1.0);
    ColorSize.rgb = gColor[0] * Reddening * mag * fade;
    ColorSize.w = mag / cutoff;
	size = (sqrt(ColorSize.w) - 1.0) * (-viewPosN.z) * Param.z * Param2.z;

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
    float r2 = 1.0 + sqrt(LineDist2(gl_FragCoord.xy * Aspect, fSpriteCenter.xy, fSpriteCenter.zw)) / Param.z;
    r2 *= r2;
    float bright = smoothstep(0.0, 0.4, 1.0 - r2 / fColorSize.w) / r2;
    if (bright == 0.0) discard;
	OutColor.rgb = bright * fColorSize.rgb;
    OutColor.a = 0.0;
    //OutColor.r += 0.05;
}

#endif
