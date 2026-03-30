#version 330 core
#extension GL_EXT_gpu_shader4 : enable
#auto_defines

uniform vec4    Param;    // GalMagnCoef, GalMagnMin, 2*sigma^2, GalParticleFadeOut
uniform vec4    Param2;   // GalMaxParticleRadiusPix, 1.0 / (GalMaxParticleRadiusPix - 1.0), 1/SpriteScale, Horizon
uniform vec4    ViewPort; // x, y, 0.5*width, 0.5*height
uniform vec2    Aspect;   // xAspect, yAspect
uniform mat4x4  ModelViewMatrix;    // modelview  matrix
uniform mat4x4  ProjectionMatrix;	// projection matrix

const float cutoff = 0.002;

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
    float Dist = sqrt(Dist2);
    float HorDist = Dist / Param2.w;

    float mag = Param.x * vLumRad.x / Dist2;
    float RadiusPix = vLumRad.y / (Dist * Param2.z);
    mag *= clamp((Param2.x - RadiusPix) * Param2.y, 0.0, 1.0);
    float fade = clamp(Param.w * (mag - Param.y), 0.0, 1.0);

    mag = sqrt(mag);
    vec3 Reddening = clamp(vec3(1.0) - vec3(1.0, 2.0, 4.0) * HorDist, 0.0, 1.0);
    gColorSize.rgb = vColor.rgb * Reddening * mag * fade;

    gColorSize.w = mag / cutoff;
	gSpriteCenterSize.z = (sqrt(gColorSize.w) - 1.0) * (-gViewPos.z) * Param.z * Param2.z;
}

#endif
#ifdef _GEOMETRY_

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

in  vec4 gViewPos[];
in  vec3 gSpriteCenterSize[];
in  vec4 gColorSize[];

out vec4 fColorSize;
out vec2 fSpriteCenter;

void main ()
{
    vec4 offs = vec4(0.0);

    // vertex 0
    fColorSize = gColorSize[0];
    fSpriteCenter = gSpriteCenterSize[0].xy;
	offs.x =  gSpriteCenterSize[0].z;
	offs.y = -gSpriteCenterSize[0].z;
    gl_Position = ProjectionMatrix * (gViewPos[0] + offs);
    EmitVertex();

	// vertex 1
    fColorSize = gColorSize[0];
    fSpriteCenter = gSpriteCenterSize[0].xy;
	offs.x =  gSpriteCenterSize[0].z;
	offs.y =  gSpriteCenterSize[0].z;
    gl_Position = ProjectionMatrix * (gViewPos[0] + offs);
    EmitVertex();

	// vertex 2
    fColorSize = gColorSize[0];
    fSpriteCenter = gSpriteCenterSize[0].xy;
	offs.x = -gSpriteCenterSize[0].z;
	offs.y = -gSpriteCenterSize[0].z;
    gl_Position = ProjectionMatrix * (gViewPos[0] + offs);
    EmitVertex();

	// vertex 3
    fColorSize = gColorSize[0];
    fSpriteCenter = gSpriteCenterSize[0].xy;
	offs.x = -gSpriteCenterSize[0].z;
	offs.y =  gSpriteCenterSize[0].z;
    gl_Position = ProjectionMatrix * (gViewPos[0] + offs);
    EmitVertex();

    EndPrimitive();
}

#endif
#ifdef _FRAGMENT_

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
    //OutColor.g += 0.05;
}

#endif
