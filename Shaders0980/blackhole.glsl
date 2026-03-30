#version 330 core
#auto_defines

// Uncomment to see the coordinate grid on star surface
//#define GRID

uniform sampler2D   Frame;
uniform samplerCube EnvMap;
uniform sampler2D   NoiseTex;
uniform sampler1D   PlanckFunction;

uniform mat4x4      MVP;            // modelview * provection matrix
uniform mat3x3      SkyRot;         // skybox rotation matrix
uniform vec4        EyePos;         // (eye position, eye distance)
uniform vec4        Params;         // (screen width, screen height, 0, 1/(1-oblateness), frame to envmap blending)
uniform vec4        Radiuses;       // (disk inner radius, disk outer radius, black hole Rg, grav lens scale)
uniform vec4        DiskParams1;    // (disk max temperature, disk twist, star animation time, disk animation time)
uniform vec4        DiskParams2;    // (temperature shift, disk brightness, disk opacity, star rotation angle)
uniform vec4        StarParams;     // (surface temperature, surface radius in Rg units, equator velocity v/c, surf brightness)

// some defines to make the code more clear
#define EyeDist     EyePos.w
#define screenW     Params.x
#define screenH     Params.y
#define oblateness  Params.z
#define blendFactor Params.w
#define innerRadius Radiuses.x
#define outerRadius Radiuses.y
#define gravRadius  Radiuses.z
#define gravScale   Radiuses.w
#define diskTemp    DiskParams1.x
#define diskTwist   DiskParams1.y
#define starTime    DiskParams1.z
#define diskTime    DiskParams1.w
#define tempShift   DiskParams2.x
#define diskBright  DiskParams2.y
#define diskOpacity DiskParams2.z
#define starRotAng  DiskParams2.w
#define starTemp    StarParams.x
#define starRadius  StarParams.y
#define starEqSpeed StarParams.z
#define starBright  StarParams.w

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

const float pi = 3.14159265358;

float gravRadiusScaled;

#if 1

// Fast LUT based noise
float noise(vec3 p)
{
    vec3 ip = floor(p);
    p = fract(p);
    p = p*p*(3.0-2.0*p);
    vec2 uv = (ip.xy + vec2(11.0, 5.0) * ip.z) + p.xy;
    uv = textureLod(NoiseTex, (uv+0.5)/16.0, 0.0).xy;
    return mix(uv.y, uv.x, p.z);
}

#else

float ring(float x, float m) { return (x >= 0) ? x - floor(x / m) * m : x + floor(-x / m) * m; }
float hash(float n) { return fract(sin(n)*753.5453123); }
float noise(in vec3 x)
{
    x.x = ring(x.x, 256.0);
    x.y = ring(x.y, 256.0);
    x.z = ring(x.z, 256.0);

    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f*f*(3.0-2.0*f);

    float n = p.x + p.y*157.0 + 113.0*p.z;
    return mix(mix(mix(hash(n+  0.0), hash(n+  1.0),f.x),
                   mix(hash(n+157.0), hash(n+158.0),f.x),f.y),
               mix(mix(hash(n+113.0), hash(n+114.0),f.x),
                   mix(hash(n+270.0), hash(n+271.0),f.x),f.y),f.z);
}

#endif

float Fbm(vec3 x)
{
    float summ = 0.0;
    float ampl = 1.0;
    for (int i=0; i<8; ++i)
    {
        summ += ampl * noise(x);
        ampl *= 0.7;
        x *= vec3(2.0, 2.0, 2.0);
    }
    return summ;
}

mat2x2  Rotate(float Angle)
{
    float cosa = cos(Angle);
    float sina = sin(Angle);
    return mat2x2(cosa, sina, -sina, cosa);
}

void AccretionDisk(vec3 rayPos, vec3 rayDir, float rayDist, inout vec4 color, inout vec4 transm)
{
    // find precise intersection with the disk
    if (abs(rayDir.y) < 1.0e-5) return;
    float dist = -rayPos.y / rayDir.y;
    if ((dist < 0.0) || (dist >= rayDist)) return;
    vec3 pos = rayPos + dist * rayDir;
    float rho = length(pos);
    if ((rho < innerRadius) || (rho > outerRadius)) return;

    // calculate physical parameters of the point in the disk (based on "alpha-disk" model with alpha = 1)
    float r = rho / gravRadius;
    float beta = sqrt(0.5 / (r - 1.0));        // velocity in units of c (v/c = sqrt(Rg / 2(R-Rg)))
    float f    = 1.0 - 1.73205 * inversesqrt(r);
    float temp = 5.1293  * pow(f, 0.3)  * pow(r, -0.75);    // temperature in units of maximum temperature (reached at 4.32 Rg)
    float dens = 40.6163 * pow(f, 0.55) * pow(r, -1.875);   // density in units of maximum density (reached at 3.94453 Rg)
    if (r < 4.32)    temp = smoothstep(1.0, 4.32,    r);    // smooth inner edge
    if (r < 3.94453) dens = smoothstep(1.0, 3.94453, r);    // smooth inner edge

    // fade values to make smooth edges
    float rf = clamp((rho - innerRadius) / (outerRadius - innerRadius), 0.0, 1.0);
    float fadeEmiss = 1.0 - rf * rf;
    float fadeTrans = fadeEmiss * fadeEmiss * smoothstep(2.5, 3.0, r);// * smoothstep(0.05, 0.1, rf);

    // modulate disk density using noise function
    float rr = sqrt(r) * diskTwist + diskTime * 16.0;
    float teta = atan(pos.x, pos.z);
    teta = teta * (128.0 / pi) + 1024.0 * beta * (1.0 - 100.0 * rho);
    //float turbulence = noise(vec3(pos.xy * 160.0, diskTime) * 16.0) * 0.75;
    float turbulence = Fbm(vec3(rr, teta, diskTime) / 16.0) * 0.75;

    // gravitational and doppler redshift
    float onePlusZ = sqrt((rho * (EyeDist - gravRadius)) / (EyeDist * (rho - gravRadius)));
    float cost = dot(rayDir, normalize(vec3(pos.z, 0.0, -pos.x)));
    onePlusZ *= (1.0 - beta * cost) * inversesqrt(1.0 - beta * beta);

    // compute Plank temperature and brightness of the disk point
    temp *= diskTemp * turbulence * pow(onePlusZ, -1.25);
    vec3 emissColor = texture(PlanckFunction, log(temp * 0.001 + tempShift) * 0.188 + 0.1316).rgb * fadeEmiss * diskBright;

    // take into account transmittance of the previous object
    color += transm * vec4(emissColor, 0.0);

    // compute and accumulate new transmittance
    transm *= exp((dens * turbulence * fadeTrans * diskOpacity) * vec4(-5.0, -8.0, -10.0, 0.0));
}

bool StarSurface(vec3 rayPos, vec3 rayDir, float stepSize, inout vec4 color, in vec4 transm)
{
    // find precise intersection with the sphere
    float p = dot(rayPos, rayDir);
    float d = p * p + starRadius * starRadius - dot(rayPos, rayPos);
    if (d < 0.0) return false;
    vec3 pos = normalize(rayPos - (p + sqrt(d)) * rayDir);

    // gravitational redshift
    float onePlusZ = sqrt((starRadius * (EyeDist - gravRadius)) / (EyeDist * (starRadius - gravRadius)));
    // doppler redshift
    float cost = dot(rayDir, normalize(vec3(pos.z, 0.0, pos.x)));
    onePlusZ *= (1.0 - starEqSpeed * cost) * inversesqrt(1.0 - starEqSpeed * starEqSpeed);

    // surface temperature variability
    pos.xz = pos.xz * Rotate(starRotAng);

#ifdef GRID
    vec2 grid = vec2(sin(atan(pos.z, pos.x) * 36.0), cos(pos.y * 90.0));
    grid = step(abs(1.0 - grid), vec2(0.05));
#endif

    float lat = abs(pos.y);
    pos.y = lat * lat - starTime + step(0, pos.y);
    //float temp = mix(diskTemp * 1.25, starTemp * (Fbm(pos * 4.0) * 0.25 + 0.75), clamp(lat * 4.0 - 0.5, 0.0, 1.0)) * 0.75;
    float temp = mix(starTemp * 1.25, starTemp * (Fbm(pos * 4.0) * 0.25 + 0.75), clamp(lat * 4.0 - 0.5, 0.0, 1.0)) * 0.75;
    temp *= pow(onePlusZ, -1.25);

#ifdef GRID
    temp *= 1.0 - max(grid.x, grid.y);
#endif

    // compute Plank temperature and brightness of the star disk
    vec3 emissColor = texture(PlanckFunction, log(temp * 0.001 + tempShift) * 0.188 + 0.1316).rgb * starBright;

    // take into account transmittance of the previous object
    color += transm * vec4(emissColor, 0.0);

    return true;
}

// Fake gravitational blueshift
void    SkyBlueShift(inout vec3 color)
{
    float onePlusZ = inversesqrt(1.0 - gravRadius / EyeDist);
	float onePlusZ2 = onePlusZ * onePlusZ;
    float flux = onePlusZ2 * onePlusZ2;
    float shift = (onePlusZ - 1.0) * 2.0;

    const float r2g = 0.299 / 0.587;
    const float g2b = 0.587 / 0.114;
    color = mix(color, vec3(0.3*color.r, color.r*r2g, color.g*g2b), clamp(shift,     0.0, 1.0));
    color = mix(color, vec3(0.7*color.r, color.r*r2g, color.g*g2b), clamp(shift-1.0, 0.0, 1.0));

    color *= flux;
}

void main()
{
    // initial setups for raymarching
    vec3  rayPos = EyePos.xyz;
    vec3  rayDir = vPosition - EyePos.xyz;
    vec4  color  = vec4(0.0, 0.0, 0.0, 0.0);
    vec4  transm = vec4(1.0, 1.0, 1.0, 1.0);
    bool  hitSky = true;
    const float step = 0.2;
    float rayDist, rayDistNext, gravPot;
    vec3  rayPosNext;

    // approximation of Schwarzschild black hole potential
    // by Paczynski  and  Wiita  (1980):
    // F = -G * M / (R - Rg)^2

    gravRadiusScaled = gravRadius * gravScale;
    float gravRadius2 = gravRadiusScaled * (2.0/3.0);
    float blackholeGrav = -0.033 * gravRadius2; // -Rg * c^2 / 2 === G * M

    // perform raymarching
    for (int i=0; i<50; i++)
    {
        rayDist = length(rayPos) - gravRadius2;

        // calculate gravitational acceleration of the ray
        gravPot  = blackholeGrav / (rayDist  * rayDist);
        gravPot *= smoothstep(0.0, 1.0, 1.0 - rayDist); // smooth transition between warp effect and non-warped background image

        // bend the ray towards the black hole
        rayDir = normalize(rayDir * step + rayPos * gravPot);
        rayDist *= step;
        rayPosNext = rayPos + rayDir * rayDist;
        rayDistNext = length(rayPosNext);

#ifdef STAR
        // ray hit the neutron star / white dwarf surface
        if (rayDistNext <= starRadius)
        {
            StarSurface(rayPos, rayDir, rayDist, color, transm);
            hitSky = false;
            break;
        }
#else
#ifndef WORMHOLE
        // ray hit the black hole's event horizon
        if (rayDistNext <= gravRadius)
        {
            hitSky = false;
            break;
        }
#endif
#endif

#ifdef ACCR_DISK
        // if ray hit the accreation disk, accumulate its emission and absorption
        AccretionDisk(rayPos, rayDir, rayDist, color, transm);
#endif

        rayPos = rayPosNext;
    }

    // if ray didn't hit the black hole or star, then it hit the skybox
    if (hitSky)
    {
        // calculate fragment position for the background frame texture
        vec4 fragPos = MVP * vec4(rayDir + EyePos.xyz, 1.0);
        vec2 rayDirF = fragPos.xy / fragPos.w * 0.5 + 0.5;

#ifdef ENV_MAP
        // obtain color from the skybox and the frame texture
        vec4 colorSkyE = texture(EnvMap, SkyRot * rayDir);
        vec4 colorSkyF = texture(Frame, rayDirF);

        // if pixel is outside the frame edges, or camera is close to the event horizon, use the skybox
        float blendZone = 0.05 * clamp((0.2 - EyeDist) * 10.0, 0.0001, 1.0);
        vec2  d = (rayDirF - clamp(rayDirF, blendZone, 1.0 - blendZone)) / blendZone;
        float blend = clamp(1.0 - dot(d, d), 0.0, 1.0) * blendFactor;

        // mix skybox and frame color based on distance to make smooth transition
        vec4 colorSky = mix(colorSkyE, colorSkyF, blend);
#else
        // obtain color from the frame texture only, mirror-repeated to fill gaps
        vec4 colorSky = texture(Frame, rayDirF);
#endif

#ifndef WORMHOLE
        // fake blueshift the sky image based on proximity to the event horizon
        SkyBlueShift(colorSky.rgb);
#endif

        // take into account absorption of the accretion disk
        color += transm * colorSky;
    }

    OutColor = color;
}

#endif
