#version 330 core
#extension GL_EXT_gpu_shader4 : enable
#auto_defines

uniform sampler2D Texture;
uniform vec4    Param;    // StarBrightCoef, LabelBrightMin, LabelFadeOut, 1/SpriteScale
uniform vec4    Color;    // Line color
uniform vec4    Clip;     // Center, Radius^2
uniform vec4    NormFade; // Normal to grid plane, fade
uniform vec4    ViewPort; // x, y, 0.5*width, 0.5*height
uniform mat4x4  ModelViewMatrix;     // modelview matrix
uniform mat4x4  ProjectionMatrix;    // projection matrix
uniform mat4x4  ModelViewProjMatrix; // mvp matrix
uniform vec2    MarkRad;             // Star mark radius, Base mark radius

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

out vec4  gPosSprite;
out vec4  gPosBase;
out vec4  gColor;
out vec2  gSize;

void main()
{
    vec3  Vector = vPosition - Clip.xyz;
    float Dist2 = dot(Vector, Vector);
    float fade = (1.0 - smoothstep(0.95, 1.0, Dist2 / Clip.w)) * NormFade.w;

    gPosSprite = ModelViewMatrix * vec4(vPosition, 1.0);
    gPosBase = vec4(vPosition - dot(Vector, NormFade.xyz) * NormFade.xyz, 1.0);

    Dist2 = dot(gPosSprite.xyz, gPosSprite.xyz);
    float mag  = Param.x * max(vLumRad.x, 1.0e-4) / Dist2;
    fade *= clamp(Param.z * (mag - Param.y), 0.0, 1.0);

    gColor.a   = fade;
    gColor.rgb = (vColor.w != 0.0) ? vColor.rgb : vec3(1.0, 0.0, 1.0);
    gColor.rgb *= fade;

    gSize.x = -Param.w * MarkRad.x * gPosSprite.z;
    gSize.y = -Param.w * MarkRad.y * (ModelViewMatrix * gPosBase).z;
}

#endif
#ifdef _GEOMETRY_

layout (points) in;
layout (triangle_strip, max_vertices = 8) out;

in  vec4  gPosSprite[];
in  vec4  gPosBase[];
in  vec4  gColor[];
in  vec2  gSize[];

out vec4  fColor;
out vec2  fTexCoord;
 
void main ()
{
	vec4 offset = vec4(0.0);

    fColor = gColor[0];
	fTexCoord = vec2(0.0, 1.0);
	offset.x = -gSize[0].x;
    offset.y = -gSize[0].x;
    gl_Position = ProjectionMatrix * (gPosSprite[0] + offset);
    EmitVertex();

	fColor = gColor[0];
	fTexCoord = vec2(0.0, 0.0);
	offset.x = -gSize[0].x;
    offset.y =  gSize[0].x;
    gl_Position = ProjectionMatrix * (gPosSprite[0] + offset);
    EmitVertex();

	fColor = gColor[0];
	fTexCoord = vec2(1.0, 1.0);
	offset.x =  gSize[0].x;
    offset.y = -gSize[0].x;
    gl_Position = ProjectionMatrix * (gPosSprite[0] + offset);
    EmitVertex();
	
	fColor = gColor[0];
	fTexCoord = vec2(1.0, 0.0);
	offset.x =  gSize[0].x;
    offset.y =  gSize[0].x;
    gl_Position = ProjectionMatrix * (gPosSprite[0] + offset);
    EmitVertex();

    EndPrimitive();

    vec4 ColorBase = Color * gColor[0].a;
	vec3 cen = normalize(Clip.xyz - gPosBase[0].xyz);
    vec3 up  = cross(NormFade.xyz, cen);
	mat4x4 Rot = mat4x4(vec4(up, 0), vec4(cen, 0), vec4(NormFade.xyz, 0), vec4(0, 0, 0, 1));

	fColor = ColorBase;
	fTexCoord = vec2(0.0, 0.0);
	offset.x = -gSize[0].y;
    offset.y = -gSize[0].y;
    gl_Position = ModelViewProjMatrix * (gPosBase[0] + Rot * offset);
    EmitVertex();

	fColor = ColorBase;
	fTexCoord = vec2(0.0, 1.0);
	offset.x = -gSize[0].y;
    offset.y =  gSize[0].y;
    gl_Position = ModelViewProjMatrix * (gPosBase[0] + Rot * offset);
    EmitVertex();

	fColor = ColorBase;
	fTexCoord = vec2(1.0, 0.0);
	offset.x =  gSize[0].y;
    offset.y = -gSize[0].y;
    gl_Position = ModelViewProjMatrix * (gPosBase[0] + Rot * offset);
    EmitVertex();

	fColor = ColorBase;
	fTexCoord = vec2(1.0, 1.0);
	offset.x =  gSize[0].y;
    offset.y =  gSize[0].y;
    gl_Position = ModelViewProjMatrix * (gPosBase[0] + Rot * offset);
    EmitVertex();

    EndPrimitive();
}

#endif
#ifdef _FRAGMENT_

in vec4 fColor;
in vec2 fTexCoord;

layout(location = 0) out vec4  OutColor;

void main()
{
    OutColor.rgb = fColor.rgb * texture(Texture, fTexCoord).rgb;
	OutColor.a = fColor.a;
}

#endif
