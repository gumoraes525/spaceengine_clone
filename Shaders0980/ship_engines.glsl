#version 330 core
#auto_defines

uniform sampler2D NoiseTex;
uniform mat4x4 Mvp;
uniform mat4x4 MvpNS;
uniform mat4x4 Modelview;
uniform vec2   Params;     // viewport parameters
uniform vec4   ViewPort;   // viewport parameters
uniform vec4   EyePosTime; // eye position, time
uniform vec4   ScaleStep;  // bbox size, integration step
uniform vec3   Color;      // exhaust color

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;
layout(location = 2) in  vec4  VertexNormal;
                     out vec4  fPosition;

void main()
{
    gl_Position = Mvp * VertexPos;
    fPosition = MvpNS * VertexPos;
    fPosition.x *= Params.y;
}

#else

                     in  vec4  fPosition;
layout(location = 0) out vec4  OutColor;

#if 1

// Fast LUT based noise
float noise(vec3 p)
{
    vec3 ip = floor(p);
    p = fract(p);
    p = p*p*(3.0-2.0*p);
    vec2 uv = (ip.xy + vec2(37.0, 17.0) * ip.z) + p.xy;
    uv = texture(NoiseTex, (uv+0.5)/256.0, -100.0).xy;
    return mix(uv.y, uv.x, p.z);
}

#else

// Hash based Perlin noise
float hash(float n) { return fract(sin(n)*43758.5453123); }
float noise(vec3 x)
{
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f*f*(3.0-2.0*f);
	
    float n = p.x + p.y*157.0 + 113.0*p.z;
    return mix(mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
                   mix( hash(n+157.0), hash(n+158.0),f.x),f.y),
               mix(mix( hash(n+113.0), hash(n+114.0),f.x),
                   mix( hash(n+270.0), hash(n+271.0),f.x),f.y),f.z);
}

#endif

#ifdef TYPE_FUSION
float   exhaustDensity(vec3 pos)
{
    // Cylindric coordinates of the point
    float r2 = dot(pos.xy, pos.xy);
	float r = sqrt(r2);
	float l = 0.5 - 0.5 * pos.z;

    // Noise to modulate exhaust core
    float Noise = 1.0;
    if ((r2 * l < 0.04) && (l > 0.25)) // condition may speedup execution on some hardware
    {
        vec3 npos = pos;
        npos.xy *= 6.7;
        npos.z += EyePosTime.w;
        Noise -= noise(npos) * sqrt(max(l - 0.25, 0.0) * 1.333);
    }

    // Exhaust intensity
    float core     = exp(-8.0 * r2) * exp(-8.0 * l) * l * (1.0 - smoothstep(0.01, 0.04, r2 * l));
    float envelope = exp(-4.0 * r2) * exp(-4.0 * l) * smoothstep(0.0, 0.49, r2) * smoothstep(1.0, 0.9, l);

    return core * 40.0 * Noise + envelope;
}
#endif

#ifdef TYPE_ION
float   exhaustDensity(vec3 pos)
{
    // Cylindric coordinates of the point
    float r2 = dot(pos.xy, pos.xy);
	float r = sqrt(r2);
	float l = 0.5 - 0.5 * pos.z;

    // Noise to modulate exhaust core
    float Noise = 1.0;
    if (l > 0.25) // condition may speedup execution on some hardware
    {
        vec3 npos = pos;
        npos.xy *= 6.7;
        npos.z += EyePosTime.w;
        Noise -= noise(npos) * sqrt(max(l - 0.25, 0.0) * 1.333);
    }

    // Exhaust intensity
    float core = exp(-4.0 * r2) * exp(-4.0 * l) * smoothstep(0.0, 0.49, r2) * smoothstep(1.0, 0.9, l);

    return core * Noise;
}
#endif

#ifdef TYPE_AEROSPIKE
float   exhaustDensity(vec3 pos)
{
    const vec2 NJets = vec2(15.0, 2.0);
    vec3  ppos = pos * vec3(0.5, 0.5, -0.5) + vec3(0.5, 0.5, 0.5);
    ppos.xy = abs(fract(ppos.xy * NJets) * 2.0 - vec2(1.0));
    float r2 = dot(ppos.xy, ppos.xy);

    // Noise to modulate exhaust core
    float Noise = 1.0;
    if (ppos.z > 0.25) // condition may speedup execution on some hardware
    {
        vec3 npos = pos;
        npos.xy *= 16.7;
        npos.z += EyePosTime.w;
        Noise = max(0.0, 1.0 - noise(npos) * sqrt(max(ppos.z - 0.25, 0.0) * 2.333));
    }

    // Exhaust intensity
    float core     = exp(-5.6 * ppos.z) * exp(-4.0 * r2) * (1.0 - ppos.z) * Noise;
    float envelope = exp(-4.0 * ppos.z) * smoothstep(1.0, 0.9, ppos.z) * 0.1;

    return core + envelope;
}
#endif

#ifdef TYPE_ION2 // Filled ion
float   exhaustDensity(vec3 pos)
{
    // Cylindric coordinates of the point
    float r2 = dot(pos.xy, pos.xy);
	float r = sqrt(r2);
	float l = 0.5 - 0.5 * pos.z;

    // Noise to modulate exhaust core
    float Noise = 1.0;
    if (l > 0.25) // condition may speedup execution on some hardware
    {
        vec3 npos = pos;
        npos.xy *= 6.7;
        npos.z += EyePosTime.w;
        Noise -= noise(npos) * sqrt(max(l - 0.25, 0.0) * 1.333);
    }

    // Exhaust intensity
    float core = exp(-4.0 * r2) * exp(-4.0 * l) * smoothstep(0.0, 0.0, r2 * 0.01) * smoothstep(1.0, 0.9, l);

    return core * Noise;
}
#endif

#ifdef TYPE_SQUARE
float   exhaustDensity(vec3 pos)
{
    // Cylindric coordinates of the point
    float r2 = dot(pos.xy, pos.xy);
	float r = sqrt(r2);
	float l = 0.5 - 0.5 * pos.z;

    // Noise to modulate exhaust core
    float Noise = 1.0;
    if (l > 0.25) // condition may speedup execution on some hardware
    {
        vec3 npos = pos;
        npos.xy *= 6.7;
        npos.z += EyePosTime.w;
        Noise -= noise(npos) * sqrt(max(l - 0.25, 0.0) * 1.333);
    }

    // Exhaust intensity
    float core = 0.5 * exp(-4.0 * l) * smoothstep(0.0, 0.0, r2 * 0.01) * smoothstep(1.0, 0.9, l);

    return core * Noise;
}
#endif

#ifdef TYPE_CHEMICAL
float   exhaustDensity(vec3 pos)
{
    // Cylindric coordinates of the point
    float r2 = 1.0 / dot(pos.xy, pos.xy);
    float r = sqrt(r2);
    float l = max(0.5 - 0.5 * pos.z, 0.0);

    // Noise to modulate exhaust core
    float Noise = 2.0;
    if (l > 0.25) // condition may speedup execution on some hardware
    {
        vec3 npos = pos;
        npos.xy *= 6.7;
        npos.z += EyePosTime.w;
        Noise -= noise(npos) * sqrt(max(l - 0.25, 0.0) * 1.333);
    }

    // Exhaust intensity
    float core = 2.0 - 2.0 * pow(l, 0.25);
    core = 0.6 * smoothstep(0.5, 3.0, r2 * (l + 0.05)) * core * core * core;

    return core * Noise;
}
#endif

// Placeholders for future effects

#ifdef TYPE_CUSTOM01
float   exhaustDensity(vec3 pos) { return 0.1; }
#endif

#ifdef TYPE_CUSTOM02
float   exhaustDensity(vec3 pos) { return 0.1; }
#endif

#ifdef TYPE_CUSTOM03
float   exhaustDensity(vec3 pos) { return 0.1; }
#endif

#ifdef TYPE_CUSTOM04
float   exhaustDensity(vec3 pos) { return 0.1; }
#endif

#ifdef TYPE_CUSTOM05
float   exhaustDensity(vec3 pos) { return 0.1; }
#endif

#ifdef TYPE_CUSTOM06
float   exhaustDensity(vec3 pos) { return 0.1; }
#endif

#ifdef TYPE_CUSTOM07
float   exhaustDensity(vec3 pos) { return 0.1; }
#endif

#ifdef TYPE_CUSTOM08
float   exhaustDensity(vec3 pos) { return 0.1; }
#endif

#ifdef TYPE_CUSTOM09
float   exhaustDensity(vec3 pos) { return 0.1; }
#endif

#ifdef TYPE_CUSTOM10
float   exhaustDensity(vec3 pos) { return 0.1; }
#endif

void main()
{
    vec3 rayDir = vec3(fPosition.xy / fPosition.w, Params.x);
    rayDir = (vec4(rayDir, 0) * Modelview).xyz;
    rayDir = normalize(rayDir) / ScaleStep.xyz;

    // Find the ray-BBox intersection points
    vec3 invR = -1.0 / rayDir;
    vec3 tbot = invR * (EyePosTime.xyz + vec3(1.0));
    vec3 ttop = invR * (EyePosTime.xyz - vec3(1.0));
    vec3 tmin = min(ttop, tbot);
    vec3 tmax = max(ttop, tbot);
    tbot.xy = max(tmin.xx, tmin.yz);
    ttop.xy = min(tmax.xx, tmax.yz);
    vec3 rayStart = EyePosTime.xyz + rayDir * max(tbot.x, tbot.y);
    vec3 rayStop  = EyePosTime.xyz + rayDir * min(ttop.x, ttop.y);

    // Init variables for ray marching
    rayDir = rayStop - rayStart;
    float travel  = length(rayDir);
    vec3  rayPos  = rayStart;
    vec3  rayStep = rayDir * (ScaleStep.w / travel);
    vec3  pos;
    float intensity = 0.0;

    // Add some noise to the first step to fix banding
    //rayPos *= vec3(1.0) + (noise(vec3(gl_FragCoord.xy, EyePosTime.w)) - vec3(0.5)) * ScaleStep.w * 20.0;
    //rayPos = min(rayPos, rayStart);

    // Perform the ray marching
    for (int i = 0; (i < 50) && (travel > 0.0); i++, rayPos += rayStep, travel -= ScaleStep.w)
        intensity += exhaustDensity(rayPos) * ScaleStep.w;

    OutColor.rgb = intensity * Color;
    OutColor.a = 0.0;

    // Visualize BBox
    //OutColor.rgb += 0.1 * rayStart;
}

#endif
