#version 330 core
#auto_defines

uniform vec4      Param;    // StarBrightCoef, StarBrightMin, 2*sigma^2, StarPointParticleFadeOut
uniform vec2      Param2;   // StarDist2FOVFactor, 1/GrayBright
uniform vec4      ViewPort; // x, y, 0.5*width, 0.5*height
uniform vec2      Aspect;   // xAspect, yAspect
uniform vec4      Clip;     // Center, Radius^2
uniform mat4x4    ModelViewMatrix;  // modelview  matrix
uniform mat4x4    ProjectionMatrix;	// projection matrix

const float cutoff = 1.0 / 256.0;

#ifdef _VERTEX_

layout(location = 0) in  vec3   vPosition;
layout(location = 1) in  vec2   vLumRad;
layout(location = 2) in  vec4   vColor;

out vec2 fSpriteCenter;
out vec3 fColor;

void main()
{
    vec3  Vector = vPosition - Clip.xyz;
    float Dist2 = dot(Vector, Vector);
    float fade = 1.0 - smoothstep(0.95, 1.0, Dist2 / Clip.w);

	vec4 viewPos = ModelViewMatrix * vec4(vPosition, 1.0);
	gl_Position = ProjectionMatrix * viewPos;
	fSpriteCenter = (gl_Position.xy / gl_Position.w + 1.0) * ViewPort.zw + ViewPort.xy;

	Dist2 = dot(viewPos.xyz, viewPos.xyz);
	float mag = Param.x * max(vLumRad.x, 1.0e-4) / Dist2;
    mag *= step(vLumRad.y * Param2.x, Dist2);

	float Bright    = mag * fade * clamp(Param.w * (mag - Param.y), 0.0, 1.0);
	float GrayLevel = pow(clamp(mag * Param2.y, 0.0, 1.0), 3);
    float GrayColor = dot(vColor.rgb, vec3(0.299, 0.587, 0.114));
    fColor = mix(vec3(GrayColor), vColor.rgb, GrayLevel) * Bright;

    float gaussR2 = -log(cutoff / mag) * Param.z;
	gl_PointSize = 2.0 * sqrt(max(gaussR2, 0.0));
}

#else

in vec2 fSpriteCenter;
in vec3 fColor;

layout(location = 0) out vec4  OutColor;

void main()
{
	vec2  p = gl_FragCoord.xy * Aspect - fSpriteCenter;
	float r2 = dot(p, p);
	float gauss = exp(-r2 / Param.z);
	OutColor.rgb = gauss * fColor;
    OutColor.a = dot(clamp(OutColor.rgb, 0.0, 1.0), vec3(0.299, 0.587, 0.114));
    //OutColor.b += 0.2;
}

#endif
