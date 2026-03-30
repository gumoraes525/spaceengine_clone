#version 330 core
#auto_defines

uniform sampler2D   Frame;
uniform samplerCube EnvMap;

uniform mat4x4      MVP;            // modelview * provection matrix
uniform mat3x3      SkyRot;         // skybox rotation matrix
uniform vec4        EyePos;         // (eye position, eye distance)
uniform vec4        Params;         // (strength, bubble radius, -bubble thickness ^ 2, frame to envmap blending)

// some defines to make the code more clear
#define EyeDist     EyePos.w

#ifdef _VERTEX_

layout(location = 0) in  vec3  VertexPos;
layout(location = 1) in  vec2  VertexTexCoord;
layout(location = 2) in  vec3  VertexTangent;
                     out vec3  vPosition;

void main()
{
    gl_Position = MVP * vec4(VertexPos, 1);
    vPosition = VertexPos;
}

#else

                     in  vec3  vPosition;
layout(location = 0) out vec4  OutColor;

// Gravitational acceleration of hyperdrive rings
vec3    RingsAcceleration(vec3 pos)
{
    float  r = abs(length(pos) - Params.y);
    float  GM = Params.x * pos.x;
    return pos * (GM / (r * r + 0.00001)) * exp(Params.z*r*r);
}

// Gravitational potential of hyperdrive rings
float   RingsPotential(vec3 pos)
{
    float  r = abs(length(pos) - Params.y);
    float  GM = Params.x * pos.x;
    return (GM / (r * r + 0.00001)) * exp(Params.z*r*r);
}

// Fake gravitational redshift/blueshift
void    SkyFreqShift(inout vec3 color, vec3 pos)
{
    float Z = clamp(-RingsPotential(pos) * 0.1, -1.0, 1.0);
    float flux = 1.0 + Z;
	flux = flux * flux;
    flux = flux * flux; // (1+Z)^4

    if (Z > 0)  // blueshift
    {
        float shift = 2.0 * Z;
        const float r2g = 0.299 / 0.587;
        const float g2b = 0.587 / 0.114;
        color = mix(color, vec3(0.3*color.r, color.r*r2g, color.g*g2b), clamp(shift,     0.0, 1.0));
        color = mix(color, vec3(0.7*color.r, color.r*r2g, color.g*g2b), clamp(shift-1.0, 0.0, 1.0));
    }
    else        // redshift
    {
        float shift = -2.0 * Z;
        const float g2r = 0.587 / 0.299;
        const float b2g = 0.114 / 0.587;
        color = mix(color, vec3(color.g*g2r, color.b*b2g, color.b*0.3), clamp(shift,     0.0, 1.0));
        color = mix(color, vec3(color.g*g2r, color.b*b2g, color.b*0.1), clamp(shift-1.0, 0.0, 1.0));
    }
    color *= flux;
}

void    main()
{
    // initial setups for raymarching
    vec3  rayPos = EyePos.xyz;
    vec3  rayDir = vPosition - EyePos.xyz;
    vec4  color  = vec4(0.0, 0.0, 0.0, 0.0);
    vec4  transm = vec4(1.0, 1.0, 1.0, 1.0);
    const float step = 0.2;
    float rayDist, objDist;
    vec3  rayAccel;

    // perform raymarching
    for (int i=0; i<50; i++)
    {
        rayDist = length(rayPos);

        rayAccel = RingsAcceleration(rayPos);
        rayAccel *= smoothstep(0.0, 1.0, 1.0 - rayDist); // smooth transition between warp effect and non-warped background image

        rayDir = normalize(rayDir * step + rayAccel);
        rayPos = rayPos + rayDir * step * rayDist;
    }

    // calculate fragment position for the background frame texture
    vec4 fragPos = MVP * vec4(rayDir + EyePos.xyz, 1.0);
    vec2 rayDirF = fragPos.xy / fragPos.w * 0.5 + 0.5;

#ifdef ENV_MAP
    // obtain color from the skybox and the frame texture
    vec4 colorSkyE = texture(EnvMap, SkyRot * rayDir);// colorSkyE.r += 0.1;
    vec4 colorSkyF = texture(Frame, rayDirF);

    // if pixel is outside the frame edges, or camera is close to the event horizon, use the skybox
    float blendZone = 0.05 * clamp((0.2 - EyeDist) * 10.0, 0.0001, 1.0);
    vec2  d = (rayDirF - clamp(rayDirF, blendZone, 1.0 - blendZone)) / blendZone;
    float blend = clamp(1.0 - dot(d, d), 0.0, 1.0) * Params.w;

    // mix skybox and frame color based on distance to make smooth transition
    color = mix(colorSkyE, colorSkyF, blend);
#else
    // obtain color from the frame texture only, mirror-repeated to fill gaps
    color = texture(Frame, rayDirF);
#endif

    // fake blueshift the sky image based on proximity to the event horizon
    SkyFreqShift(color.rgb, EyePos.xyz);

    OutColor = color;
}

#endif
