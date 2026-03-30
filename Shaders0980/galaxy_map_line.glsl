#version 330 core
#extension GL_EXT_gpu_shader4 : enable
#auto_defines

uniform vec3    Param;    // GalBrightCoef, LabelBrightMin, LabelFadeOut
uniform vec3    Param2;   // GalMaxParticleRadiusPix, 1.0 / (GalMaxParticleRadiusPix - 1.0), 1/SpriteScale
uniform vec4    Color;    // Line color
uniform vec4    Clip;     // Center, Radius^2
uniform vec4    NormFade; // Normal to grid plane, fade
uniform vec4    ViewPort; // x, y, 0.5*width, 0.5*height
uniform mat4x4  ModelViewMatrix;     // modelview matrix
uniform mat4x4  ProjectionMatrix;    // mvp matrix

const float LineWidth2 = 2.0;
const float cutoff = 1.0 / 256.0;
#define SMOOTH_LINES

#ifdef SMOOTH_LINES

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

out vec4  gPosSprite;
out vec4  gPosBase;
out vec4  gColor;
out float gSize;

void main()
{
    vec3  Vector = vPosition - Clip.xyz;
    float Dist2 = dot(Vector, Vector);
    float fade = 1.0 - smoothstep(0.95, 1.0, Dist2 / Clip.w);

	gPosSprite = ModelViewMatrix * vec4(vPosition, 1.0);
    gPosBase = ModelViewMatrix * vec4(vPosition - dot(Vector, NormFade.xyz) * NormFade.xyz, 1.0);

    Dist2 = dot(gPosSprite.xyz, gPosSprite.xyz);
    float mag  = Param.x * vLumRad.x / Dist2;
    float RadiusPix = vLumRad.y / (sqrt(Dist2) * Param2.z);

    gColor.a   = NormFade.w * fade * clamp(Param.z * (mag - Param.y), 0.0, 1.0) * clamp((Param2.x - RadiusPix) * Param2.y, 0.0, 1.0);
    gColor.rgb = vColor.rgb * gColor.a * 0.5;

    mag = sqrt(mag);
    float gaussR2 = -log(cutoff / mag) * LineWidth2;
    gSize = sqrt(max(gaussR2, 0.0) * Dist2) * Param2.z;
}

#endif
#ifdef _GEOMETRY_

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

in  vec4  gPosSprite[];
in  vec4  gPosBase[];
in  vec4  gColor[];
in  float gSize[];

out vec4 fColor;
out vec4 fLineEnds;

void main ()
{
    vec4  viewPosSprite = gPosSprite[0];
    vec4  viewPosBase   = gPosBase[0];

    vec4 projPos, LineEnds;
    projPos = ProjectionMatrix * viewPosSprite;
    LineEnds.xy = (projPos.xy / projPos.w + 1.0) * ViewPort.zw + ViewPort.xy;
    projPos = ProjectionMatrix * viewPosBase;
    LineEnds.zw = (projPos.xy / projPos.w + 1.0) * ViewPort.zw + ViewPort.xy;

    vec3  ray  = viewPosSprite.xyz - viewPosBase.xyz;
    vec2  ray2 = LineEnds.xy - LineEnds.zw;
    float rayLen = dot(ray2, ray2);
    vec2  line;
    if (rayLen == 0.0)
    {
        line = vec2(0.0, 1.0);
        viewPosBase = viewPosSprite;
    }
	else
		line = normalize(cross(ray, viewPosSprite.xyz)).xy;


    vec4 offs = vec4(0.0);

    // vertex 0
    fColor = gColor[0];
    fLineEnds = LineEnds;
	offs.x =  line.y - line.x;
	offs.y = -line.x - line.y;
    gl_Position = ProjectionMatrix * (viewPosSprite + offs * gSize[0]);
    EmitVertex();

	// vertex 1
    fColor = gColor[0];
    fLineEnds = LineEnds;
	offs.x =  line.y + line.x;
	offs.y = -line.x + line.y;
    gl_Position = ProjectionMatrix * (viewPosSprite + offs * gSize[0]);
    EmitVertex();

	// vertex 2
    fColor = Color * gColor[0].a;
    fLineEnds = LineEnds;
	offs.x = -line.y - line.x;
	offs.y =  line.x - line.y;
    gl_Position = ProjectionMatrix * (viewPosBase + offs * gSize[0]);
    EmitVertex();

	// vertex 3
    fColor = Color * gColor[0].a;
    fLineEnds = LineEnds;
	offs.x = -line.y + line.x;
	offs.y =  line.x + line.y;
    gl_Position = ProjectionMatrix * (viewPosBase + offs * gSize[0]);
    EmitVertex();

    EndPrimitive();
}

#endif
#ifdef _FRAGMENT_

in vec4 fColor;
in vec4 fLineEnds;

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
    float r2 = LineDist2(gl_FragCoord.xy, fLineEnds.xy, fLineEnds.zw);
	float gauss = exp(-r2 / LineWidth2);
	OutColor = gauss * fColor;
    //OutColor.r += 0.2;
}

#endif

#else // SMOOTH_LINES

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

out vec4  gColor;
out vec4  gPosSprite;
out vec4  gPosBase;

void main()
{
    vec3  Vector = vPosition - Clip.xyz;
    float Dist2 = dot(Vector, Vector);

    if (Dist2 <= Clip.w)
    {
		gPosSprite = ModelViewMatrix * vec4(vPosition, 1.0);
        gPosBase   = ModelViewMatrix * vec4(vPosition - dot(Vector, NormFade.xyz) * NormFade.xyz, 1.0);

        Dist2 = dot(gPosSprite.xyz, gPosSprite.xyz);
        float mag  = Param.x * vLumRad.x / Dist2;
        float RadiusPix = vLumRad.y / (sqrt(Dist2) * Param2.z);

        gColor.a = clamp(Param.z * (mag - Param.y), 0.0, 1.0) * NormFade.w * clamp((Param2.x - RadiusPix) * Param2.y, 0.0, 1.0);
        gColor.rgb = vColor.rgb * gColor.a * 0.5;
    }
    else
	{
        gPosSprite = vec4(0, 0, 0, 1);
		gPosBase   = vec4(0, 0, 0, 1);
		gColor     = vec4(0, 0, 0, 0);
	}
}

#endif
#ifdef _GEOMETRY_

layout (points) in;
layout (line_strip, max_vertices = 2) out;

in  vec4  gColor[];
in  vec4  gPosSprite[];
in  vec4  gPosBase[];

out vec4  fColor;
 
void main ()
{
	fColor = gColor[0];
    gl_Position = ProjectionMatrix * gPosSprite[0];
    EmitVertex();

	fColor = Color * gColor[0].a;
    gl_Position = ProjectionMatrix * gPosBase[0];
    EmitVertex();

    EndPrimitive();
}

#endif
#ifdef _FRAGMENT_

in vec4 fColor;

layout(location = 0) out vec4  OutColor;

void main()
{
    OutColor = fColor;
}

#endif

#endif // SMOOTH_LINES
