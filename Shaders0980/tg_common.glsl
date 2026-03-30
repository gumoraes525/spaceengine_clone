// Procedural planet generator
// Copyright (C) 2012-2015  Vladimir Romanyuk
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. Neither the name of the copyright holders nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION)HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
// THE POSSIBILITY OF SUCH DAMAGE.
//
// This is include file for the procedural planet generator shaders

#version 330 core
#auto_defines

//-----------------------------------------------------------------------------

#ifdef _VERTEX_

layout(location = 0) in  vec4  VertexPos;
layout(location = 1) in  vec4  VertexTexCoord;
                     out vec4  TexCoord;

void main()
{
    gl_Position = VertexPos;
    TexCoord = VertexTexCoord;
}

#else

                     in  vec4  TexCoord;
layout(location = 0) out vec4  OutColor;

//-----------------------------------------------------------------------------
// tiles blending method:
// 0 - hard mix (no blending)
// 1 - soft blending
// 2 - "smart" blening (based on atlas heightmap texture)
#define TILE_BLEND_MODE 2
//-----------------------------------------------------------------------------
// tiling fix method:
// 0 - no tiling fix
// 1 - sampling texture 2 times at different scales
// 2 - voronoi random offset
// 3 - voronoi random offset and rotation
#define TILING_FIX_MODE 3
//-----------------------------------------------------------------------------
// Uniforms

uniform vec3    Randomize;      // Randomize
uniform vec4    faceParams;     // (x0,             y0,             size,                face)
uniform vec4    scaleParams;    // (offsU,          offsV,          scale,               0.0)
uniform vec4    mainParams;     // (mainFreq,       terraceProb,    surfClass,           tidalLock)
uniform vec4    colorParams;    // (colorDistMagn,  colorDistFreq,  latIceCaps,          latTropic)
uniform vec4    climateParams;  // (climatePole,    climateTropic,  climateEquator,      tropicWidth)
uniform vec4    mareParams;     // (seaLevel,       mareFreq,       sqrt(mareDensity),   icecapHeight)
uniform vec4    montesParams;   // (montesMagn,     montesFreq,     montesFraction,      montesSpiky)
uniform vec4    dunesParams;    // (dunesMagn,      dunesFreq,      dunesDensity,        drivenDarkening)
uniform vec4    hillsParams;    // (hillsMagn,      hillsFreq,      hillsDensity,        hills2Density)
uniform vec4    canyonsParams;  // (canyonsMagn,    canyonsFreq,    canyonsFraction,     erosion)
uniform vec4    riversParams;   // (riversMagn,     riversFreq,     riversSin,           riversOctaves)
uniform vec4    cracksParams;   // (cracksMagn,     cracksFreq,     cracksOctaves,       craterRayedFactor)
uniform vec4    craterParams;   // (craterMagn,     craterFreq,     sqrt(craterDensity), craterOctaves)
uniform vec4    volcanoParams1; // (volcanoMagn,    volcanoFreq,    volcanoDensity,      volcanoOctaves)
uniform vec4    volcanoParams2; // (volcanoActivity,volcanoFlows,   volcanoRadius,       volcanoTemp)
uniform vec4    lavaParams;		// (lavaCoverage,   snowLevel,      surfTemperature,     heightTempGrad)
uniform vec4    textureParams;  // (texScale,       texColorConv,   venusMagn,           venusFreq)
uniform vec4    cloudsParams1;  // (cloudsFreq,     cloudsOctaves,  stripeZones,         stripeTwist)
uniform vec4    cloudsParams2;  // (cloudsLayer,    cloudsNLayers,  stripeFluct,         cloudsCoverage)
uniform vec4    cycloneParams;  // (cycloneMagn,    cycloneFreq,    cycloneDensity,      cycloneOctaves)

uniform sampler3D   NoiseSampler;       // precomputed noise texture
uniform sampler2D   PermSampler;        // permutation table for Perlin noise
uniform sampler1D   PermGradSampler;    // permutted gradient table for Perlin noise
uniform sampler2D   NormalMap;          // normals map to calculate slope
uniform sampler2D   MaterialTable;      // material parameters table
uniform sampler1D   CloudsColorTable;   // clouds color table
uniform sampler2D   AtlasDiffSampler;   // detail texture diffuse atlas

//-----------------------------------------------------------------------------
const float pi  = 3.14159265358;
//-----------------------------------------------------------------------------
//#define IMPROVED_TEX_PERLIN 1
#define NOISE_TEX_3D_SIZE   64.0
#define PACKED_NORMALS      1
//-----------------------------------------------------------------------------
#define ATLAS_RES_X         8
#define ATLAS_RES_Y         16
#define ATLAS_TILE_RES      256
#define ATLAS_TILE_RES_LOG2 8
//-----------------------------------------------------------------------------
#define     mainFreq            mainParams.x
#define     terraceProb         mainParams.y
#define     surfClass           mainParams.z
#define     tidalLock           mainParams.w
#define     colorDistMagn       colorParams.x
#define     colorDistFreq       colorParams.y
#define     latIceCaps          colorParams.z
#define     latTropic           colorParams.w
#define     climatePole         climateParams.x
#define     climateTropic       climateParams.y
#define     climateEquator      climateParams.z
#define     tropicWidth         climateParams.w
#define     seaLevel            mareParams.x
#define     mareFreq            mareParams.y
#define     mareSqrtDensity     mareParams.z
#define     icecapHeight        mareParams.w
#define     montesMagn          montesParams.x
#define     montesFreq          montesParams.y
#define     montesFraction      montesParams.z
#define     montesSpiky         montesParams.w
#define     dunesMagn           dunesParams.x
#define     dunesFreq           dunesParams.y
#define     dunesFraction       dunesParams.z
#define     drivenDarkening     dunesParams.w
#define     hillsMagn           hillsParams.x
#define     hillsFreq           hillsParams.y
#define     hillsFraction       hillsParams.z
#define     hills2Fraction      hillsParams.w
#define     canyonsMagn         canyonsParams.x
#define     canyonsFreq         canyonsParams.y
#define     canyonsFraction     canyonsParams.z
#define     erosion             canyonsParams.w
#define     riversMagn          riversParams.x
#define     riversFreq          riversParams.y
#define     riversSin           riversParams.z
#define     riversOctaves       riversParams.w
#define     cracksMagn          cracksParams.x
#define     cracksFreq          cracksParams.y
#define     cracksOctaves       cracksParams.z
#define     craterRayedFactor   cracksParams.w
#define     craterMagn          craterParams.x
#define     craterFreq          craterParams.y
#define     craterSqrtDensity   craterParams.z
#define     craterOctaves       craterParams.w
#define     volcanoMagn         volcanoParams1.x
#define     volcanoFreq         volcanoParams1.y
#define     volcanoDensity      volcanoParams1.z
#define     volcanoOctaves      volcanoParams1.w
#define     volcanoActivity     volcanoParams2.x
#define     volcanoFlows        volcanoParams2.y
#define     volcanoRadius       volcanoParams2.z
#define     volcanoTemp         volcanoParams2.w
#define     lavaCoverage        lavaParams.x
#define     snowLevel           lavaParams.y
#define     surfTemperature     lavaParams.z
#define     heightTempGrad      lavaParams.w
#define     texScale            textureParams.x
#define     texColorConv        textureParams.y
#define     venusMagn           textureParams.z
#define     venusFreq           textureParams.w
#define     cloudsFreq          cloudsParams1.x
#define     cloudsOctaves       cloudsParams1.y
#define     stripeZones         cloudsParams1.z
#define     stripeTwist         cloudsParams1.w
#define     cloudsLayer         cloudsParams2.x
#define     cloudsNLayers       cloudsParams2.y
#define     stripeFluct         cloudsParams2.z
#define     cloudsCoverage      cloudsParams2.w
#define     cycloneMagn         cycloneParams.x
#define     cycloneFreq         cycloneParams.y
#define     cycloneDensity      cycloneParams.z
#define     cycloneOctaves      cycloneParams.w
//-----------------------------------------------------------------------------




//-----------------------------------------------------------------------------
#define     saturate(x) clamp(x, 0.0, 1.0)
//-----------------------------------------------------------------------------
// polynomial smooth min (k = 0.1)

float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b-a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

//-----------------------------------------------------------------------------
// exponential soft max/min (k = 32 - max, k = -32 - min)

float softExpMaxMin(float a, float b, float k)
{
    float res = exp(k*a) + exp(k*b);
    return log(res) / k;
}

//-----------------------------------------------------------------------------

vec3    Rotate(float Angle, vec3 Axis, vec3 Vector)
{
    float cosa = cos(Angle);
    float sina = sin(Angle);
    float t = 1.0 - cosa;

    mat3x3 M = mat3x3(
        t * Axis.x * Axis.x + cosa,
        t * Axis.x * Axis.y - sina * Axis.z,
        t * Axis.x * Axis.z + sina * Axis.y,
        t * Axis.x * Axis.y + sina * Axis.z,
        t * Axis.y * Axis.y + cosa,
        t * Axis.y * Axis.z - sina * Axis.x,
        t * Axis.x * Axis.z - sina * Axis.y,
        t * Axis.y * Axis.z + sina * Axis.x,
        t * Axis.z * Axis.z + cosa);

    return Vector * M;
}

//-----------------------------------------------------------------------------

vec3    SphericalToCartesian(vec2 spherical)
{
    vec2 alpha = vec2(sin(spherical.x), cos(spherical.x));
    vec2 delta = vec2(sin(spherical.y), cos(spherical.y));
    return vec3(delta.y*alpha.x, delta.x, delta.y*alpha.y);
}

//-----------------------------------------------------------------------------

vec3    GetSurfacePoint()
{
    vec2 spherical;
    if (faceParams.w == 6.0)    // global
    {
        spherical.x = (TexCoord.x * 2.0 - 0.5) * pi;
        spherical.y = (0.5 - TexCoord.y) * pi;
        vec2 alpha = vec2(sin(spherical.x), cos(spherical.x));
        vec2 delta = vec2(sin(spherical.y), cos(spherical.y));
        return vec3(delta.y*alpha.x, delta.x, delta.y*alpha.y);
    }
    else                        // cubemap
    {
        spherical = TexCoord.xy * faceParams.z + faceParams.xy;
        vec3 p = normalize(vec3(spherical, 1.0));
        if (faceParams.w == 0.0)
            return vec3( p.z, -p.y, -p.x);  // neg_x
        else if (faceParams.w == 1.0)
            return vec3(-p.z, -p.y,  p.x);  // pos_x
        else if (faceParams.w == 2.0)
            return vec3( p.x, -p.z, -p.y);  // neg_y
        else if (faceParams.w == 3.0)
            return vec3( p.x,  p.z,  p.y);  // pos_y
        else if (faceParams.w == 4.0)
            return vec3(-p.x, -p.y, -p.z);  // neg_z
        else
            return vec3( p.x, -p.y,  p.z);  // pos_z
    }
}

//-----------------------------------------------------------------------------

vec3    rgb2hsl(vec3 rgb)
{
/*
    float Max = max(rgb.r, max(rgb.g, rgb.b));
    float Min = min(rgb.r, min(rgb.g, rgb.b));

    vec3  hsl = vec3(0.0);
    hsl.z = (Min + Max) * 0.5;
    if (hsl.z <= 0.0) return hsl;

    float delta = Max - Min;
    if (delta == 0.0)
    {
        hsl.x = 0.0; // undefined (gray color)
        hsl.y = 0.0;
    }
    else
    {
        if (hsl.z <= 0.5) hsl.y = delta / (Max + Min);
        else              hsl.y = delta / (2.0 - Max - Min);

        vec3 rgb2 = (vec3(Max)- rgb) / delta;

        if      (rgb.r == Max) hsl.x = (Min == rgb.g) ? 5.0 + rgb2.b : 1.0 - rgb2.g;
        else if (rgb.g == Max) hsl.x = (Min == rgb.b) ? 1.0 + rgb2.r : 3.0 - rgb2.b;
        else                   hsl.x = (Min == rgb.r) ? 3.0 + rgb2.g : 5.0 - rgb2.r;

        hsl.x *= 1.0/6.0;
    }

    return hsl;
/**/
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(rgb.bg, K.wz), vec4(rgb.gb, K.xy), step(rgb.b, rgb.g));
    vec4 q = mix(vec4(p.xyw, rgb.r), vec4(rgb.r, p.yzx), step(p.x, rgb.r));
    float d = q.x - min(q.w, q.y);
    const float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
/**/
}

//-----------------------------------------------------------------------------

vec3    hsl2rgb(vec3 hsl)
{
/*
    vec3  rgb;
    float q = (hsl.z <= 0.5) ? (hsl.z * (1.0 + hsl.y)) : (hsl.z + hsl.y - hsl.z * hsl.y);

    if (q <= 0)
    {
        rgb = vec3(hsl.z);
    }
    else
    {
        float p  = 2.0 * hsl.z - q;
        float tr = 6.0 * fract(hsl.x + 1.0/3.0);
        float tg = 6.0 * fract(hsl.x);
        float tb = 6.0 * fract(hsl.x - 1.0/3.0);

        if      (tr < 1.0) rgb.r = p + (q-p)*tr;
        else if (tr < 3.0) rgb.r = q;
        else if (tr < 4.0) rgb.r = p + (q-p)*(4.0-tr);
        else               rgb.r = p;

        if      (tg < 1.0) rgb.g = p + (q-p)*tg;
        else if (tg < 3.0) rgb.g = q;
        else if (tg < 4.0) rgb.g = p + (q-p)*(4.0-tg);
        else               rgb.g = p;

        if      (tb < 1.0) rgb.b = p + (q-p)*tb;
        else if (tb < 3.0) rgb.b = q;
        else if (tb < 4.0) rgb.b = p + (q-p)*(4.0-tb);
        else               rgb.b = p;
    }

    return rgb;
/**/
    const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(hsl.xxx + K.xyz) * 6.0 - K.www);
    return hsl.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), hsl.y);
/**/
}

//-----------------------------------------------------------------------------

vec3  UnitToColor24(in float unit)
{
    const vec3  factor = vec3(1.0, 255.0, 65025.0);
    const float mask = 1.0 / 256.0;
    vec3 color = unit * factor.rgb;
    color.gb = fract(color.gb);
    color.rg -= color.gb * mask;
    return clamp(color, 0.0, 1.0);
}
 
//-----------------------------------------------------------------------------

float ColorToUnit24(in vec3 color)
{
    return dot(color, vec3(1.0, 1.0/255.0, 1.0/65025.0));
}

//-----------------------------------------------------------------------------
#ifndef PACKED_NORMALS

float   GetSurfaceHeight()
{
    vec2  texCoord = TexCoord.xy * scaleParams.z + scaleParams.xy;
    return texture(NormalMap, texCoord).a;
}

void    GetSurfaceHeightAndSlope(inout float height, inout float slope)
{
    vec2  texCoord = TexCoord.xy * scaleParams.z + scaleParams.xy;
    vec4  bumpData = texture(NormalMap, texCoord);
    vec3  norm = 2.0 * bumpData.xyz - 1.0;
    slope  = clamp(1.0 - pow(norm.z, 6.0), 0.0, 1.0);
    height = bumpData.a;
}

void    GetSurfaceHeightAndSlopeAndNormal(inout float height, inout float slope, inout vec3 norm)
{
    vec2  texCoord = TexCoord.xy * scaleParams.z + scaleParams.xy;
    vec4  bumpData = texture(NormalMap, texCoord);
    norm = 2.0 * bumpData.xyz - 1.0;
    slope  = clamp(1.0 - pow(norm.z, 6.0), 0.0, 1.0);
    height = bumpData.a;
}

#else

float   GetSurfaceHeight()
{
    vec2  texCoord = TexCoord.xy * scaleParams.z + scaleParams.xy;
    vec4  bumpData = texture(NormalMap, texCoord);
    return dot(bumpData.zw, vec2(0.00390625, 1.0));
}

void    GetSurfaceHeightAndSlope(inout float height, inout float slope)
{
    vec2  texCoord = TexCoord.xy * scaleParams.z + scaleParams.xy;
    vec4  bumpData = texture(NormalMap, texCoord);
    vec2  norm = 2.0 * bumpData.xy - 1.0;
    slope  = 1.0 - dot(norm.xy, norm.xy);
    slope  = clamp(1.0 - pow(slope, 3.0), 0.0, 1.0);
    height = dot(bumpData.zw, vec2(0.00390625, 1.0));
}

void    GetSurfaceHeightAndSlopeAndNormal(inout float height, inout float slope, inout vec3 norm)
{
    vec2  texCoord = TexCoord.xy * scaleParams.z + scaleParams.xy;
    vec4  bumpData = texture(NormalMap, texCoord);
    norm.xy = 2.0 * bumpData.xy - 1.0;
    slope  = 1.0 - dot(norm.xy, norm.xy);
    norm.z = sqrt(slope);
    slope  = clamp(1.0 - pow(slope, 3.0), 0.0, 1.0);
    height = dot(bumpData.zw, vec2(0.00390625, 1.0));
}

#endif
//-----------------------------------------------------------------------------
#define     GetCloudsColor(height)           texture(CloudsColorTable, height)
#define     GetGasGiantCloudsColor(height)   texture(MaterialTable, vec2(height, 0.0))
//-----------------------------------------------------------------------------

struct  Surface
{
    vec4  color;
    float height;
};

//-----------------------------------------------------------------------------

Surface Blend(Surface s0, Surface s1, float t)
{
    return Surface(mix(s0.color, s1.color, t), mix(s0.height, s1.height, t));
}

//-----------------------------------------------------------------------------

Surface BlendSmart(Surface s0, Surface s1, float t)
{
    float a0 = s0.height + 1.0 - t;
    float a1 = s1.height + t;
    float ma = max(a0, a1) - 0.5;
    float b0 = max(a0 - ma, 0);
    float b1 = max(a1 - ma, 0);
    ma = 1.0 / (b0 + b1);
    b0 *= ma;
    b1 *= ma;
    Surface res;
    res.color  = s0.color  * b0 + s1.color  * b1;
    res.height = s0.height * b0 + s1.height * b1;
    return res;
}
//-----------------------------------------------------------------------------
float   hash1(float p) { return fract(sin(p) * 158.5453123); }
vec3    hash3(vec2  p) { return fract(sin(vec3( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)), dot(p,vec2(419.2,371.9)) )) * 43758.5453); }
vec4    hash4(vec2  p) { return fract(sin(vec4( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)), dot(p,vec2(419.2,371.9)), dot(p,vec2(398.1,176.7)) )) * 43758.5453); }
//-----------------------------------------------------------------------------
// Texture atlas sampling function
// height, slope defines the tile based on MaterialTable texture
// vary sets one of 4 different tiles of the same material

#if (TILING_FIX_MODE <= 1)

Surface    GetSurfaceColorAtlas(float height, float slope, float vary)
{
    const vec4  PackFactors = vec4(1.0/ATLAS_RES_X, 1.0/ATLAS_RES_Y, ATLAS_TILE_RES, ATLAS_TILE_RES_LOG2);
    slope = saturate(slope * 0.5);

    vec4  IdScale = texture(MaterialTable, vec2(height, slope + 0.5));
    int   materialID = min(int(IdScale.x) + int(vary), int(ATLAS_RES_X * ATLAS_RES_Y - 1));
    vec2  tileOffs = vec2(materialID % ATLAS_RES_X, materialID / ATLAS_RES_X) * PackFactors.xy;

    Surface res;
    vec2  tileUV = (TexCoord.xy * faceParams.z + faceParams.xy) * texScale * IdScale.y;
    vec2  dx = dFdx(tileUV * PackFactors.z);
    vec2  dy = dFdy(tileUV * PackFactors.z);
    float lod = clamp(0.5 * log2(max(dot(dx, dx), dot(dy, dy))), 0.0, PackFactors.w);
    vec2  invSize = vec2(pow(2.0, lod - PackFactors.w)) * PackFactors.xy;
    vec2  uv = tileOffs + fract(tileUV) * (PackFactors.xy - invSize) + 0.5 * invSize;

#if   (TILING_FIX_MODE == 0)
    res.color = textureLod(AtlasDiffSampler, uv, lod);
#elif (TILING_FIX_MODE == 1)
    vec2  uv2 = tileOffs + fract(-0.173 * tileUV) * (PackFactors.xy - invSize) + 0.5 * invSize;
    res.color = mix(textureLod(AtlasDiffSampler, uv, lod), textureLod(AtlasDiffSampler, uv2, lod), 0.5);
#endif

    res.height = res.color.a;

    vec4 adjust = texture(MaterialTable, vec2(height, slope));
    adjust.xyz *= texColorConv;
    vec3 hsl = rgb2hsl(res.color.rgb);
    hsl.x  = fract(hsl.x  + adjust.x);
    hsl.yz = clamp(hsl.yz + adjust.yz, 0.0, 1.0);
    res.color.rgb = hsl2rgb(hsl);

    res.color.a = adjust.a;
    return  res;
}

#else

Surface    GetSurfaceColorAtlas(float height, float slope, float vary)
{
    const vec4  PackFactors = vec4(1.0/ATLAS_RES_X, 1.0/ATLAS_RES_Y, ATLAS_TILE_RES, ATLAS_TILE_RES_LOG2);
    slope = saturate(slope * 0.5);

    vec4  IdScale = texture(MaterialTable, vec2(height, slope + 0.5));
    int   materialID = min(int(IdScale.x) + int(vary), int(ATLAS_RES_X * ATLAS_RES_Y - 1));
    vec2  tileOffs = vec2(materialID % ATLAS_RES_X, materialID / ATLAS_RES_X) * PackFactors.xy;

    vec2  tileUV = (TexCoord.xy * faceParams.z + faceParams.xy) * texScale * IdScale.y;
    vec2  dx = dFdx(tileUV * PackFactors.z);
    vec2  dy = dFdy(tileUV * PackFactors.z);
    float lod = clamp(0.5 * log2(max(dot(dx, dx), dot(dy, dy))), 0.0, PackFactors.w);
    vec2  invSize = vec2(pow(2.0, lod - PackFactors.w)) * PackFactors.xy;

    // Voronoi-based random offset and rotation for tile texture coordinates
    const float magOffs = 1.0; // magnitude of the texture coordinates offset
    vec2  uvo = tileOffs + 0.5 * invSize;
    vec2  uvs = PackFactors.xy - invSize;
    vec2  p   = floor(tileUV);
    vec2  f   = fract(tileUV) - 0.5;
	vec4  color = vec4(0.0);
	float weight = 0.0;

    vec4  adjust = texture(MaterialTable, vec2(height, slope));
    adjust.xyz *= texColorConv;

    for(int j=-1; j<1; j++)
    {
        for(int i=-1; i<1; i++)
        {
            vec2   g = vec2(float(i), float(j));
		    vec4   o = hash4(p + g);
		    vec2   r = g - f + o.xy * 0.66666667; // reduce a jitter to fix artefacts
		    float  d = dot(r, r);
            float  w = pow(1.0 - smoothstep(0.0, 2.0, d*d), 1.0 + 16.0 * magOffs);

#if   (TILING_FIX_MODE == 2)
            vec2   uv = fract(tileUV + magOffs * o.zy);
#elif (TILING_FIX_MODE == 3)
            float  a   = o.w * IdScale.z; // magnitude of the texture coordinates rotation (zero for sand tiles)
            vec2   sc  = vec2(sin(a), cos(a));
            mat2x2 rot = mat2x2(sc.y, sc.x, -sc.x, sc.y);
            vec2   uv  = fract(rot * (tileUV + magOffs * o.zy));
#endif

            // color conversion must be done before summarize, because hls color space is not additive
            vec4 rgb = textureLod(AtlasDiffSampler, uv * uvs + uvo, lod);
            vec3 hsl = rgb2hsl(rgb.rgb);
            hsl.x    = fract(hsl.x  + adjust.x);
            hsl.yz   = clamp(hsl.yz + adjust.yz, 0.0, 1.0);
            rgb.rgb  = hsl2rgb(hsl);
            //rgb.r = d;
            //rgb.b = o.w;

            color  += w * rgb;
		    weight += w;
        }
    }
	
    Surface res;
    res.color = color / weight;
    res.height = res.color.a;
    res.color.a = adjust.a;

    return  res;
}

#endif
//-----------------------------------------------------------------------------
// Planet surface color function (uses the texture atlas sampling function)
// 'height' and 'slope' defines the tile based on MaterialTable texture
// 'vary' sets one of 4 different tiles of the same material

#if (TILE_BLEND_MODE == 0)

Surface GetSurfaceColor(float height, float slope, float vary)
{
    return GetSurfaceColorAtlas(height, slope, vary * 4.0);
}

#elif (TILE_BLEND_MODE == 1)

Surface GetSurfaceColor(float height, float slope, float vary)
{
    height = clamp(height - 0.0625, 0.0, 1.0);
    slope  = clamp(slope  + 0.1250, 0.0, 1.0);
    float h0 = floor(height * 8.0) * 0.125;
    float h1 = h0 + 0.125;
    float dh = (height - h0) * 8.0;
    float s0 = floor(slope  * 4.0) * 0.25;
    float s1 = s0 - 0.25;
    float ds = 1.0 - (slope - s0) * 4.0;
    float v0 = floor(vary * 16.0) * 0.25;
    float v1 = v0 - 0.25;
    float dv = 1.0 - (vary * 4.0 - v0) * 4.0;

    Surface surfH0, surfH1;
    Surface surfS0, surfS1;
    Surface surfV0, surfV1;

    surfH0 = GetSurfaceColorAtlas(h0, s0, v0);
    surfH1 = GetSurfaceColorAtlas(h1, s0, v0);
    surfS0 = Blend(surfH0, surfH1, dh);

    surfH0 = GetSurfaceColorAtlas(h0, s1, v0);
    surfH1 = GetSurfaceColorAtlas(h1, s1, v0);
    surfS1 = Blend(surfH0, surfH1, dh);

    surfV0 = Blend(surfS0, surfS1, ds);

    surfH0 = GetSurfaceColorAtlas(h0, s0, v1);
    surfH1 = GetSurfaceColorAtlas(h1, s0, v1);
    surfS0 = Blend(surfH0, surfH1, dh);

    surfH0 = GetSurfaceColorAtlas(h0, s1, v1);
    surfH1 = GetSurfaceColorAtlas(h1, s1, v1);
    surfS1 = Blend(surfH0, surfH1, dh);

    surfV1 = Blend(surfS0, surfS1, ds);

    return   Blend(surfV0, surfV1, dv);
}

#elif (TILE_BLEND_MODE == 2)

Surface GetSurfaceColor(float height, float slope, float vary)
{
    height = clamp(height - 0.0625, 0.0, 1.0);
    slope  = clamp(slope  + 0.1250, 0.0, 1.0);
    float h0 = floor(height * 8.0) * 0.125;
    float h1 = h0 + 0.125;
    float dh = (height - h0) * 8.0;
    float s0 = floor(slope  * 4.0) * 0.25;
    float s1 = s0 - 0.25;
    float ds = 1.0 - (slope - s0) * 4.0;
    float v0 = floor(vary * 16.0) * 0.25;
    float v1 = v0 - 0.25;
    float dv = 1.0 - (vary * 4.0 - v0) * 4.0;

    Surface surfH0, surfH1;
    Surface surfS0, surfS1;
    Surface surfV0, surfV1;

    surfH0 = GetSurfaceColorAtlas(h0, s0, v0);
    surfH1 = GetSurfaceColorAtlas(h1, s0, v0);
    surfS0 = BlendSmart(surfH0, surfH1, dh);

    surfH0 = GetSurfaceColorAtlas(h0, s1, v0);
    surfH1 = GetSurfaceColorAtlas(h1, s1, v0);
    surfS1 = BlendSmart(surfH0, surfH1, dh);

    surfV0 = BlendSmart(surfS0, surfS1, ds);

    surfH0 = GetSurfaceColorAtlas(h0, s0, v1);
    surfH1 = GetSurfaceColorAtlas(h1, s0, v1);
    surfS0 = BlendSmart(surfH0, surfH1, dh);

    surfH0 = GetSurfaceColorAtlas(h0, s1, v1);
    surfH1 = GetSurfaceColorAtlas(h1, s1, v1);
    surfS1 = BlendSmart(surfH0, surfH1, dh);

    surfV1 = BlendSmart(surfS0, surfS1, ds);

    return   BlendSmart(surfV0, surfV1, dv);
}

#endif

//-----------------------------------------------------------------------------
#ifdef IMPROVED_TEX_PERLIN
// Improved Perlin noise with derivatives
// http://www.iquilezles.org/www/articles/morenoise/morenoise.htm
//-----------------------------------------------------------------------------

// 3D Perlin noise
float   Noise(vec3 p)
{
    const float one = 1.0 / 256.0;

    // Find unit cube that contains point
    // Find relative x,y,z of point in cube
    vec3 P = mod(floor(p), 256.0) * one;
    p -= floor(p);

    // Compute fade curves for each of x,y,z
    vec3 ff = p * p * p * (p * (p * 6.0 - 15.0) + 10.0);

    // Hash coordinates of the 8 cube corners
    vec4 AA = texture(PermSampler, P.xy) + P.z;

    float a = dot(texture(PermGradSampler, AA.x      ).rgb,  p);
    float b = dot(texture(PermGradSampler, AA.z      ).rgb,  p + vec3(-1,  0,  0));
    float c = dot(texture(PermGradSampler, AA.y      ).rgb,  p + vec3( 0, -1,  0));
    float d = dot(texture(PermGradSampler, AA.w      ).rgb,  p + vec3(-1, -1,  0));
    float e = dot(texture(PermGradSampler, AA.x + one).rgb,  p + vec3( 0,  0, -1));
    float f = dot(texture(PermGradSampler, AA.z + one).rgb,  p + vec3(-1,  0, -1));
    float g = dot(texture(PermGradSampler, AA.y + one).rgb,  p + vec3( 0, -1, -1));
    float h = dot(texture(PermGradSampler, AA.w + one).rgb,  p + vec3(-1, -1, -1));

    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return k0 + k1*ff.x + k2*ff.y + k3*ff.z + k4*ff.x*ff.y + k5*ff.y*ff.z + k6*ff.z*ff.x + k7*ff.x*ff.y*ff.z;
}

//-----------------------------------------------------------------------------

// 3D Perlin noise with derivatives, returns vec4(xderiv, yderiv, zderiv, noise)
vec4    NoiseDeriv(vec3 p)
{
    const float one = 1.0 / 256.0;

    // Find unit cube that contains point
    // Find relative x,y,z of point in cube
    vec3 P = mod(floor(p), 256.0) * one;
    p -= floor(p);

    // Compute fade curves for each of x,y,z
    vec3 df = 30.0 * p * p * (p * (p - 2.0) + 1.0);
    vec3 ff = p * p * p * (p * (p * 6.0 - 15.0) + 10.0);

    // Hash coordinates of the 8 cube corners
    vec4 AA = texture(PermSampler, P.xy) + P.z;

    float a = dot(texture(PermGradSampler, AA.x      ).rgb,  p);
    float b = dot(texture(PermGradSampler, AA.z      ).rgb,  p + vec3(-1,  0,  0));
    float c = dot(texture(PermGradSampler, AA.y      ).rgb,  p + vec3( 0, -1,  0));
    float d = dot(texture(PermGradSampler, AA.w      ).rgb,  p + vec3(-1, -1,  0));
    float e = dot(texture(PermGradSampler, AA.x + one).rgb,  p + vec3( 0,  0, -1));
    float f = dot(texture(PermGradSampler, AA.z + one).rgb,  p + vec3(-1,  0, -1));
    float g = dot(texture(PermGradSampler, AA.y + one).rgb,  p + vec3( 0, -1, -1));
    float h = dot(texture(PermGradSampler, AA.w + one).rgb,  p + vec3(-1, -1, -1));

    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return vec4(df.x * (k1 + k4*ff.y + k6*ff.z + k7*ff.y*ff.z),
                df.y * (k2 + k5*ff.z + k4*ff.x + k7*ff.z*ff.x),
                df.z * (k3 + k6*ff.x + k5*ff.y + k7*ff.x*ff.y),
                k0 + k1*ff.x + k2*ff.y + k3*ff.z + k4*ff.x*ff.y + k5*ff.y*ff.z + k6*ff.z*ff.x + k7*ff.x*ff.y*ff.z);
}

//-----------------------------------------------------------------------------
#else
//	Brian Sharpe
//	brisharpe CIRCLE_A yahoo DOT com
//	http://briansharpe.wordpress.com
//	https://github.com/BrianSharpe
//-----------------------------------------------------------------------------

// Generates 3 random numbers for each of the 8 cell corners
void FastHash3D(vec3 gridcell,
                out vec4 lowz_hash_0,
                out vec4 lowz_hash_1,
                out vec4 lowz_hash_2,
                out vec4 highz_hash_0,
                out vec4 highz_hash_1,
                out vec4 highz_hash_2)
{
    // gridcell is assumed to be an integer coordinate
    const vec2  OFFSET = vec2(50.0, 161.0);
    const float DOMAIN = 69.0;
    const vec3  SOMELARGEFLOATS = vec3(635.298681, 682.357502, 668.926525);
    const vec3  ZINC = vec3(48.500388, 65.294118, 63.934599);

    //	truncate the domain
    gridcell.xyz = gridcell.xyz - floor(gridcell.xyz * (1.0 / DOMAIN)) * DOMAIN;
    vec3 gridcell_inc1 = mix(gridcell + vec3(1.0), vec3(0.0), greaterThan(gridcell, vec3(DOMAIN - 1.5)));

    //	calculate the noise
    vec4 P = vec4(gridcell.xy, gridcell_inc1.xy) + OFFSET.xyxy;
    P *= P;
    P = P.xzxz * P.yyww;
    lowz_hash_2.xyzw = vec4(1.0) / (SOMELARGEFLOATS.xyzx + vec2(gridcell.z, gridcell_inc1.z).xxxy * ZINC.xyzx);
    highz_hash_2.xy  = vec2(1.0) / (SOMELARGEFLOATS.yz + gridcell_inc1.zz * ZINC.yz);
    lowz_hash_0  = fract(P *  lowz_hash_2.xxxx);
    highz_hash_0 = fract(P *  lowz_hash_2.wwww);
    lowz_hash_1  = fract(P *  lowz_hash_2.yyyy);
    highz_hash_1 = fract(P * highz_hash_2.xxxx);
    lowz_hash_2  = fract(P *  lowz_hash_2.zzzz);
    highz_hash_2 = fract(P * highz_hash_2.yyyy);
}

//-----------------------------------------------------------------------------

// Generates a random number for each of the 8 cell corners
void FastHash3D(vec3 gridcell, out vec4 lowz_hash, out vec4 highz_hash)
{
	// gridcell is assumed to be an integer coordinate
	const vec2 OFFSET = vec2(50.0, 161.0);
	const float DOMAIN = 69.0;
	const float SOMELARGEFLOAT = 635.298681;
	const float ZINC = 48.500388;

	//	truncate the domain
	gridcell.xyz = gridcell.xyz - floor(gridcell.xyz * (1.0 / DOMAIN)) * DOMAIN;
	vec3 gridcell_inc1 = step(gridcell, vec3(DOMAIN - 1.5)) * (gridcell + 1.0);

	//	calculate the noise
	vec4 P = vec4(gridcell.xy, gridcell_inc1.xy) + OFFSET.xyxy;
	P *= P;
	P = P.xzxz * P.yyww;
	highz_hash.xy = vec2(1.0 / (SOMELARGEFLOAT + vec2(gridcell.z, gridcell_inc1.z) * ZINC));
	lowz_hash  = fract(P * highz_hash.xxxx );
	highz_hash = fract(P * highz_hash.yyyy );
}

//-----------------------------------------------------------------------------
vec3 InterpC2(vec3 x) { return x * x * x * (x * (x * 6.0 - 15.0) + 10.0); }
//-----------------------------------------------------------------------------

// 3D Perlin noise without lookup textures
float   Noise(vec3 p)
{
    // Establish our grid cell and unit position
    vec3 Pi = floor(p);
    vec3 Pf = p - Pi;
    vec3 Pf_min1 = Pf - 1.0;

#if 1
    // Classic noise. Requires 3 random values per point.
    // With an efficent hash function will run faster than improved noise.

    // Calculate the hash
    vec4 hashx0, hashy0, hashz0, hashx1, hashy1, hashz1;
    FastHash3D(Pi, hashx0, hashy0, hashz0, hashx1, hashy1, hashz1);

    // Calculate the gradients
    const vec4 C = vec4(0.49999);
    vec4 grad_x0 = hashx0 - C;
    vec4 grad_y0 = hashy0 - C;
    vec4 grad_z0 = hashz0 - C;
    vec4 grad_x1 = hashx1 - C;
    vec4 grad_y1 = hashy1 - C;
    vec4 grad_z1 = hashz1 - C;
    vec4 grad_results_0 = inversesqrt(grad_x0 * grad_x0 + grad_y0 * grad_y0 + grad_z0 * grad_z0) * (vec2(Pf.x, Pf_min1.x).xyxy * grad_x0 + vec2(Pf.y, Pf_min1.y).xxyy * grad_y0 + Pf.zzzz * grad_z0);
    vec4 grad_results_1 = inversesqrt(grad_x1 * grad_x1 + grad_y1 * grad_y1 + grad_z1 * grad_z1) * (vec2(Pf.x, Pf_min1.x).xyxy * grad_x1 + vec2(Pf.y, Pf_min1.y).xxyy * grad_y1 + Pf_min1.zzzz * grad_z1);

    // Classic Perlin Interpolation
    vec3 blend = InterpC2(Pf);
    vec4 res0 = mix(grad_results_0, grad_results_1, blend.z);
    vec2 res1 = mix(res0.xy, res0.zw, blend.y);
    float final = mix(res1.x, res1.y, blend.x);
    final *= 1.1547005383792515290182975610039; // (optionally) scale things to a strict -1.0->1.0 rang *= 1.0/sqrt(0.75)
    return final;
#else
    // Improved noise. Requires 1 random value per point.
    // Will run faster than classic noise if a slow hashing function is used.

    // Calculate the hash
    vec4 hash_lowz, hash_highz;
    FastHash3D(Pi, hash_lowz, hash_highz);

#if 0
    // This will implement Ken Perlins "improved" classic noise using the 12 mid-edge gradient points.
    // NOTE: mid-edge gradients give us a nice strict -1.0->1.0 range without additional scaling.
    // [1,1,0] [-1,1,0] [1,-1,0] [-1,-1,0]
    // [1,0,1] [-1,0,1] [1,0,-1] [-1,0,-1]
    // [0,1,1] [0,-1,1] [0,1,-1] [0,-1,-1]
    hash_lowz *= 3.0;
    vec4 grad_results_0_0 = mix(vec2(Pf.y, Pf_min1.y).xxyy, vec2(Pf.x, Pf_min1.x).xyxy, lessThan(hash_lowz, vec4(2.0)));
    vec4 grad_results_0_1 = mix(Pf.zzzz, vec2(Pf.y, Pf_min1.y).xxyy, lessThan(hash_lowz, vec4(1.0)));
    hash_lowz = fract(hash_lowz) - 0.5;
    vec4 grad_results_0 = grad_results_0_0 * sign(hash_lowz) + grad_results_0_1 * sign(abs(hash_lowz) - vec4(0.25));

    hash_highz *= 3.0;
    vec4 grad_results_1_0 = mix(vec2(Pf.y, Pf_min1.y).xxyy, vec2(Pf.x, Pf_min1.x).xyxy, lessThan(hash_highz, vec4(2.0)));
    vec4 grad_results_1_1 = mix(Pf_min1.zzzz, vec2(Pf.y, Pf_min1.y).xxyy, lessThan(hash_highz, vec4(1.0)));
    hash_highz = fract(hash_highz) - 0.5;
    vec4 grad_results_1 = grad_results_1_0 * sign(hash_highz) + grad_results_1_1 * sign(abs(hash_highz) - vec4(0.25));

    // Blend the gradients and return
    vec3 blend = InterpC2(Pf);
    vec4 res0 = mix(grad_results_0, grad_results_1, blend.z);
    vec2 res1 = mix(res0.xy, res0.zw, blend.y);
    return mix(res1.x, res1.y, blend.x);
#else
    // "Improved" noise using 8 corner gradients. Faster than the 12 mid-edge point method.
    // Ken mentions using diagonals like this can cause "clumping", but we'll live with that.
    // [1,1,1]  [-1,1,1]  [1,-1,1]  [-1,-1,1]
    // [1,1,-1] [-1,1,-1] [1,-1,-1] [-1,-1,-1]
    hash_lowz -= vec4(0.5);
    vec4 grad_results_0_0 = vec2(Pf.x, Pf_min1.x).xyxy * sign(hash_lowz);
    hash_lowz = abs(hash_lowz) - vec4(0.25);
    vec4 grad_results_0_1 = vec2(Pf.y, Pf_min1.y).xxyy * sign(hash_lowz);
    vec4 grad_results_0_2 = Pf.zzzz * sign(abs(hash_lowz) - vec4(0.125));
    vec4 grad_results_0 = grad_results_0_0 + grad_results_0_1 + grad_results_0_2;

    hash_highz -= vec4(0.5);
    vec4 grad_results_1_0 = vec2(Pf.x, Pf_min1.x).xyxy * sign(hash_highz);
    hash_highz = abs(hash_highz) - vec4(0.25);
    vec4 grad_results_1_1 = vec2(Pf.y, Pf_min1.y).xxyy * sign(hash_highz);
    vec4 grad_results_1_2 = Pf_min1.zzzz * sign(abs(hash_highz) - vec4(0.125));
    vec4 grad_results_1 = grad_results_1_0 + grad_results_1_1 + grad_results_1_2;

    // Blend the gradients and return
    vec3 blend = InterpC2(Pf);
    vec4 res0 = mix(grad_results_0, grad_results_1, blend.z);
    vec2 res1 = mix(res0.xy, res0.zw, blend.y);
    return mix(res1.x, res1.y, blend.x) * (2.0 / 3.0);   // (optionally) mult by (2.0/3.0)to scale to a strict -1.0->1.0 range
#endif

#endif
}

//-----------------------------------------------------------------------------

// 3D Perlin noise with derivatives, returns vec4(xderiv, yderiv, zderiv, noise)
vec4    NoiseDeriv(vec3 p)
{
    //	establish our grid cell and unit position
    vec3 Pi = floor(p);
    vec3 Pf = p - Pi;
    vec3 Pf_min1 = Pf - 1.0;

    //	calculate the hash
    //	(various hashing methods listed in order of speed)
    vec4 hashx0, hashy0, hashz0, hashx1, hashy1, hashz1;
    FastHash3D(Pi, hashx0, hashy0, hashz0, hashx1, hashy1, hashz1);

    //	calculate the gradients
    const vec4 C = vec4(0.49999);
    vec4 grad_x0 = hashx0 - C;
    vec4 grad_y0 = hashy0 - C;
    vec4 grad_z0 = hashz0 - C;
    vec4 norm_0 = inversesqrt(grad_x0 * grad_x0 + grad_y0 * grad_y0 + grad_z0 * grad_z0);
    grad_x0 *= norm_0;
    grad_y0 *= norm_0;
    grad_z0 *= norm_0;
    vec4 grad_x1 = hashx1 - C;
    vec4 grad_y1 = hashy1 - C;
    vec4 grad_z1 = hashz1 - C;
    vec4 norm_1 = inversesqrt(grad_x1 * grad_x1 + grad_y1 * grad_y1 + grad_z1 * grad_z1);
    grad_x1 *= norm_1;
    grad_y1 *= norm_1;
    grad_z1 *= norm_1;
    vec4 grad_results_0 = vec2(Pf.x, Pf_min1.x).xyxy * grad_x0 + vec2(Pf.y, Pf_min1.y).xxyy * grad_y0 + Pf.zzzz * grad_z0;
    vec4 grad_results_1 = vec2(Pf.x, Pf_min1.x).xyxy * grad_x1 + vec2(Pf.y, Pf_min1.y).xxyy * grad_y1 + Pf_min1.zzzz * grad_z1;

    //	get lengths in the x+y plane
    vec3 Pf_sq = Pf*Pf;
    vec3 Pf_min1_sq = Pf_min1*Pf_min1;
    vec4 vecs_len_sq = vec2(Pf_sq.x, Pf_min1_sq.x).xyxy + vec2(Pf_sq.y, Pf_min1_sq.y).xxyy;

    //	evaluate the surflet
    vec4 m_0 = vecs_len_sq + Pf_sq.zzzz;
    m_0 = max(1.0 - m_0, 0.0);
    vec4 m2_0 = m_0 * m_0;
    vec4 m3_0 = m_0 * m2_0;

    vec4 m_1 = vecs_len_sq + Pf_min1_sq.zzzz;
    m_1 = max(1.0 - m_1, 0.0);
    vec4 m2_1 = m_1 * m_1;
    vec4 m3_1 = m_1 * m2_1;

    //	calculate the derivatives
    vec4  temp_0 = -6.0 * m2_0 * grad_results_0;
    float xderiv_0 = dot(temp_0, vec2(Pf.x, Pf_min1.x).xyxy) + dot(m3_0, grad_x0);
    float yderiv_0 = dot(temp_0, vec2(Pf.y, Pf_min1.y).xxyy) + dot(m3_0, grad_y0);
    float zderiv_0 = dot(temp_0, Pf.zzzz) + dot(m3_0, grad_z0);

    vec4  temp_1 = -6.0 * m2_1 * grad_results_1;
    float xderiv_1 = dot(temp_1, vec2(Pf.x, Pf_min1.x).xyxy) + dot(m3_1, grad_x1);
    float yderiv_1 = dot(temp_1, vec2(Pf.y, Pf_min1.y).xxyy) + dot(m3_1, grad_y1);
    float zderiv_1 = dot(temp_1, Pf_min1.zzzz) + dot(m3_1, grad_z1);

    const float FINAL_NORMALIZATION = 2.3703703703703703703703703703704;	//	scales the final result to a strict (-1.0, 1.0) range
    return  vec4(vec3(xderiv_0, yderiv_0, zderiv_0) + vec3(xderiv_1, yderiv_1, zderiv_1),
                 dot(m3_0, grad_results_0) + dot(m3_1, grad_results_1)) * FINAL_NORMALIZATION;
}

//-----------------------------------------------------------------------------
#endif
//-----------------------------------------------------------------------------

vec4 permute (vec4 x) { return mod((x * 34.0 + 1.0) * x, 289.0); }
vec3 permute3(vec3 x) { return mod((x * 34.0 + 1.0) * x, 289.0); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

// 3D simplex noise
float sNoise(vec3 v)
{
    v *= 0.25;

    const vec2  C = vec2(1.0/6.0, 1.0/3.0);
    const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

    // First corner
    vec3 i  = floor(v + dot(v, C.yyy));
    vec3 x0 =   v - i + dot(i, C.xxx);

    // Other corners
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    //   x0 = x0 - 0.0 + 0.0 * C.xxx;
    //   x1 = x0 - i1  + 1.0 * C.xxx;
    //   x2 = x0 - i2  + 2.0 * C.xxx;
    //   x3 = x0 - 1.0 + 3.0 * C.xxx;
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
    vec3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

    // Permutations
    i = mod(i, 289.0); 
    vec4 p = permute(permute(permute(
          i.z + vec4(0.0, i1.z, i2.z, 1.0))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    // Gradients: 7x7 points over a square, mapped onto an octahedron.
    // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
    float n_ = 0.142857142857; // 1.0/7.0
    vec3  ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);    // mod(j,N)

    vec4 x = x_ *ns.x + ns.yyyy;
    vec4 y = y_ *ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    //vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
    //vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 p0 = vec3(a0.xy,h.x);
    vec3 p1 = vec3(a0.zw,h.y);
    vec3 p2 = vec3(a1.xy,h.z);
    vec3 p3 = vec3(a1.zw,h.w);

    //Normalise gradients
    vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // Mix final noise value
    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

//-----------------------------------------------------------------------------

const vec3 vyd = vec3(3.33, 5.71, 1.96);
const vec3 vzd = vec3(7.77, 2.65, 4.37);
const vec3 vwd = vec3(1.13, 2.73, 6.37);

vec2    NoiseVec2    (vec3 p){ return vec2(Noise(p), Noise(p + vyd)); }
vec3    NoiseVec3    (vec3 p){ return vec3(Noise(p), Noise(p + vyd), Noise(p + vzd)); }
vec4    NoiseVec4    (vec3 p){ return vec4(Noise(p), Noise(p + vyd), Noise(p + vzd), Noise(p + vwd)); }
float   NoiseU       (vec3 p){ return Noise    (p) * 0.5 + 0.5; }
vec3    NoiseUVec3   (vec3 p){ return NoiseVec3(p) * 0.5 + vec3(0.5); }
vec4    NoiseUVec4   (vec3 p){ return NoiseVec4(p) * 0.5 + vec4(0.5); }

//-----------------------------------------------------------------------------

#define NoiseNearestU    (p)    texture(NoiseSampler, p).r
#define NoiseNearestUVec3(p)    texture(NoiseSampler, p).rgb
#define NoiseNearestUVec4(p)    texture(NoiseSampler, p)

//-----------------------------------------------------------------------------

float   DistNoise  (vec3 p, float d)    {   return Noise    (p + NoiseVec3(p + 0.5) * d);   }
vec3    DistNoise3D(vec3 p, float d)    {   return NoiseVec3(p + NoiseVec3(p + 0.5) * d);   }
vec4    DistNoise4D(vec3 p, float d)    {   return NoiseVec4(p + NoiseVec3(p + 0.5) * d);   }
float   FiltNoise      (vec3 p, float w)          { return Noise    (p) * (1 - smoothstep(0.2, 0.6, w)); }
vec3    FiltNoise3D    (vec3 p, float w)          { return NoiseVec3(p) * (1 - smoothstep(0.2, 0.6, w)); }
vec4    FiltNoise4D    (vec3 p, float w)          { return NoiseVec4(p) * (1 - smoothstep(0.2, 0.6, w)); }
float   FiltDistNoise  (vec3 p, float w, float d) { return DistNoise  (p, d) * (1 - smoothstep(0.2, 0.6, w)); }
vec3    FiltDistNoise3D(vec3 p, float w, float d) { return DistNoise3D(p, d) * (1 - smoothstep(0.2, 0.6, w)); }
vec4    FiltDistNoise4D(vec3 p, float w, float d) { return DistNoise4D(p, d) * (1 - smoothstep(0.2, 0.6, w)); }

//-----------------------------------------------------------------------------




//-----------------------------------------------------------------------------
float   noiseOctaves     = 4.0;
float   noiseLacunarity  = 2.218281828459;
float   noiseH           = 0.5;
float   noiseOffset      = 0.8;
float   noiseRidgeSmooth = 0.0001;
//-----------------------------------------------------------------------------

float   Fbm(vec3 point)
{
    float summ = 0.0;
	float ampl = 1.0;
	float gain = pow(noiseLacunarity, -noiseH);
    for (int i=0; i<noiseOctaves; ++i)
    {
        summ  += Noise(point) * ampl;
		ampl  *= gain;
        point *= noiseLacunarity;
    }
    return summ;
}

//-----------------------------------------------------------------------------

vec3    Fbm3D(vec3 point)
{
    vec3  summ = vec3(0.0);
	float ampl = 1.0;
	float gain = pow(noiseLacunarity, -noiseH);
    for (int i=0; i<noiseOctaves; ++i)
    {
        summ  += NoiseVec3(point) * ampl;
		ampl  *= gain;
        point *= noiseLacunarity;
    }
    return summ;
}

//-----------------------------------------------------------------------------

float   FbmClouds(vec3 point)
{
    float summ = 0.0;
    float ampl = 1.0;
    for (int i=0; i<cloudsOctaves; ++i)
    {
        summ += Noise(point) * ampl;
        ampl  *= 0.333;
        point *= 3.1416;
    }
    return summ;
}

//-----------------------------------------------------------------------------

vec3    FbmClouds3D(vec3 point)
{
    vec3  summ = vec3(0.0);
    float ampl = 1.0;
    for (int i=0; i<cloudsOctaves; ++i)
    {
        summ += NoiseVec3(point) * ampl;
        ampl  *= 0.333;
        point *= 3.1416;
    }
    return summ;
}

//-----------------------------------------------------------------------------

float   DistFbm(vec3 point, float dist)
{
    float summ = 0.0;
	float ampl = 1.0;
	float gain = pow(noiseLacunarity, -noiseH);
    for (int i=0; i<noiseOctaves; ++i)
    {
        summ  += DistNoise(point, dist) * ampl;
		ampl  *= gain;
        point *= noiseLacunarity;
    }
    return summ;
}

//-----------------------------------------------------------------------------

vec3    DistFbm3D(vec3 point, float dist)
{
    vec3  summ = vec3(0.0);
	float ampl = 1.0;
	float gain = pow(noiseLacunarity, -noiseH);
    for (int i=0; i<noiseOctaves; ++i)
    {
        summ  += DistNoise3D(point, dist) * ampl;
		ampl  *= gain;
        point *= noiseLacunarity;
    }
    return summ;
}

//-----------------------------------------------------------------------------

float   RidgedMultifractal(vec3 point, float gain)
{
    float signal = 1.0;
    float summ   = 0.0;
    float frequency = 1.0;
    float weight;
    for (int i=0; i<noiseOctaves; ++i)
    {
        weight = saturate(signal * gain);
        signal = Noise(point * frequency);
        signal = noiseOffset - sqrt(noiseRidgeSmooth + signal*signal);
        signal *= signal * weight;
        summ += signal * pow(frequency, -noiseH);
        frequency *= noiseLacunarity;
    }
    return summ;
}

//-----------------------------------------------------------------------------

float   RidgedMultifractalDetail(vec3 point, float gain, float firstOctaveValue)
{
    float signal = firstOctaveValue;
    float summ   = firstOctaveValue;
    float frequency = noiseLacunarity;
    float weight;
    for (int i=1; i<noiseOctaves; ++i)
    {
        weight = saturate(signal * gain);
        signal = Noise(point * frequency);
        signal = noiseOffset - sqrt(noiseRidgeSmooth + signal*signal);
        signal *= signal * weight;
        summ += signal * pow(frequency, -noiseH);
        frequency *= noiseLacunarity;
    }
    return summ;
}

//-----------------------------------------------------------------------------
// Ridged multifractal with "procedural erosion" by Giliam de Carpentier
// http://www.decarpentier.nl/scape-procedural-extensions

float   RidgedMultifractalEroded(vec3 point, float gain, float warp)
{
    float frequency = 1.0;
    float amplitude = 1.0;
    float summ = 0.0;
    float signal = 1.0;
    float weight;
    vec3  dsum = vec3(0.0);
    vec4  noiseDeriv;
    for (int i=0; i<noiseOctaves; ++i)
    {
        noiseDeriv = NoiseDeriv((point + warp * dsum) * frequency);
        weight = saturate(signal * gain);
        signal = noiseOffset - sqrt(noiseRidgeSmooth + noiseDeriv.w*noiseDeriv.w);
        signal *= signal * weight;
        amplitude = pow(frequency, -noiseH);
        summ += signal * amplitude;
        frequency *= noiseLacunarity;
        dsum -= amplitude * noiseDeriv.xyz * noiseDeriv.w;
    }
    return summ;
}

//-----------------------------------------------------------------------------
// Ridged multifractal with "procedural erosion" by Giliam de Carpentier
// http://www.decarpentier.nl/scape-procedural-extensions

float   RidgedMultifractalErodedDetail(vec3 point, float gain, float warp, float firstOctaveValue)
{
    float frequency = 1.0;
    float amplitude = 1.0;
    float summ   = firstOctaveValue;
    float signal = firstOctaveValue;
    float weight;
    vec3  dsum = vec3(0.0);
    vec4  noiseDeriv;
    for (int i=0; i<noiseOctaves; ++i)
    {
        noiseDeriv = NoiseDeriv((point + warp * dsum) * frequency);
        weight = saturate(signal * gain);
        signal = noiseOffset - sqrt(noiseRidgeSmooth + noiseDeriv.w*noiseDeriv.w);
        signal *= signal * weight;
        amplitude = pow(frequency, -noiseH);
        summ += signal * amplitude;
        frequency *= noiseLacunarity;
        dsum -= amplitude * noiseDeriv.xyz * noiseDeriv.w;
    }
    return summ;
}

//-----------------------------------------------------------------------------
// "Jordan turbulence" function by Giliam de Carpentier
// http://www.decarpentier.nl/scape-procedural-extensions

float   JordanTurbulence(vec3 point,
                         float gain0, float gain,
                         float warp0, float warp,
                         float damp0, float damp,
                         float dampScale)
{
    vec4  noiseDeriv = NoiseDeriv(point);
    vec4  noiseDeriv2 = noiseDeriv * noiseDeriv.w;
    float summ = noiseDeriv2.w;
    vec3  dsumWarp = warp0 * noiseDeriv2.xyz;
    vec3  dsumDamp = damp0 * noiseDeriv2.xyz;

    float amp = gain0;
    float freq = noiseLacunarity;
    float dampedAmp = amp * gain;

    for(int i=1; i<noiseOctaves; ++i)
    {
        noiseDeriv = NoiseDeriv(point * freq + dsumWarp.xyz);
        noiseDeriv2 = noiseDeriv * noiseDeriv.w;
        summ += dampedAmp * noiseDeriv2.w;
        dsumWarp += warp * noiseDeriv2.xyz;
        dsumDamp += damp * noiseDeriv2.xyz;
        freq *= noiseLacunarity;
        amp  *= gain;
        dampedAmp = amp * (1.0 - dampScale / (1.0 + dot(dsumDamp, dsumDamp)));
    }
    return summ;
}

//-----------------------------------------------------------------------------
// "iqTurbulence" function by Inigo Quilez
// http://www.iquilezles.org , http://www.decarpentier.nl/scape-procedural-basics

float iqTurbulence(vec3 point, float gain)
{
    vec4  n;
    float summ = 0.5;
    float freq = 1.0;
    float amp  = 1.0;
    vec2  dsum = vec2(0.0, 0.0);
    for (int i=0; i<noiseOctaves; i++)
    {
        n = NoiseDeriv(point * freq);
        dsum += n.yz;
        summ += amp * n.x / (1 + dot(dsum, dsum));
        freq *= noiseLacunarity;
        amp  *= gain;
    }
    return summ;
}

//-----------------------------------------------------------------------------
// iqTurbulence with faded octave 2 mudulates octaves oct to noiseOctaves

float iqTurbulence2(vec3 point, float gain, int oct)
{
    // octave 2
    vec4 n = NoiseDeriv(point * noiseLacunarity * noiseLacunarity);
    float oct0 = 0.5 + n.x / (1 + dot(n.yz, n.yz));

    // octaves oct to noiseOctaves
    float summ = 0.5;
    float freq = pow(noiseLacunarity, noiseOctaves - oct);
    float amp  = 1.0;
    vec2  dsum = vec2(0.0, 0.0);
    for (int i=oct; i<noiseOctaves; i++)
    {
        n = NoiseDeriv(point * freq);
        dsum += n.yz;
        summ += amp * n.x / (1 + dot(dsum, dsum));
        freq *= noiseLacunarity;
        amp  *= gain;
    }

    // modulate noise with octave 2
    return summ * oct0;
}

//-----------------------------------------------------------------------------




//-----------------------------------------------------------------------------

float   Cell2Noise(vec3 p)
{
    vec3  cell = floor(p);
    vec3  offs = p - cell - vec3(0.5);
    vec3  pos;
    vec3  rnd;
    vec3  d;
    float dist;
    float distMin = 1.0e38;
    for (d.z=-1.0; d.z<1.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<1.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<1.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE).xyz + d;
                //rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE).xyz;
                //rnd = CellularWeightSamples3(rnd) * 0.166666666 + d;
                pos = rnd - offs;
                dist = dot(pos, pos);
                distMin = min(distMin, dist);
            }
        }
    }
    return sqrt(distMin);
}

//-----------------------------------------------------------------------------

vec2    Cell2Noise2(vec3 p)
{
    vec3  cell = floor(p);
    vec3  offs = p - cell - vec3(0.5);
    vec3  pos;
    vec3  rnd;
    vec3  d;
    float dist;
    float distMin1 = 1.0e38;
    float distMin2 = 1.0e38;
    for (d.z=-1.0; d.z<1.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<1.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<1.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE).xyz + d;
                pos = rnd - offs;
                dist = dot(pos, pos);
                if (dist < distMin1)
                {
                    distMin2 = distMin1;
                    distMin1 = dist;
                }
                else
                    distMin2 = min(distMin2, dist);
            }
        }
    }
    return sqrt(vec2(distMin1, distMin2));
}

//-----------------------------------------------------------------------------

vec4    Cell2NoiseVec(vec3 p, float jitter)
{
    vec3  cell = floor(p);
    vec3  offs = p - cell - vec3(0.5);
    vec3  pos;
    vec3  point = vec3(0.0);
    vec3  rnd;
    vec3  d;
    float distMin = 1.0e38;
    float dist;
    for (d.z=-1.0; d.z<1.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<1.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<1.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE).xyz * jitter + d;
                pos = rnd - offs;
                dist = dot(pos, pos);
                if (distMin > dist)
                {
                    distMin = dist;
                    point = rnd;
                }
            }
        }
    }
    point = normalize(point + cell + vec3(0.5));
    return vec4(point, sqrt(distMin));
    //return vec4(point, sqrt(distMin));
}

//-----------------------------------------------------------------------------

float   Cell2NoiseColor(vec3 p, out vec4 color)
{
    vec3  cell = floor(p);
    vec3  offs = p - cell - vec3(0.5);
    vec3  pos;
    vec4  rndM = vec4(1.0);
    vec4  rnd;
    vec3  d;
    float distMin = 1.0e38;
    float dist;
    for (d.z=-1.0; d.z<1.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<1.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<1.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE);
                pos = rnd.xyz + d - offs;
                dist = dot(pos, pos);
                if (distMin > dist)
                {
                    distMin = dist;
                    rndM = rnd;
                }
            }
        }
    }
    color = rndM;
    return sqrt(distMin);
}

//-----------------------------------------------------------------------------

vec4    Cell2NoiseSphere(vec3 p, float Radius)
{
    p *= Radius;
    vec3  cell = floor(p);
    vec3  offs = p - cell - vec3(0.5);
    vec3  pos;
    vec3  point = vec3(0.0);
    vec3  rnd;
    vec3  d;
    float distMin = 1.0e38;
    float dist;
    for (d.z=-1.0; d.z<1.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<1.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<1.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE).xyz + d;
                pos = rnd - offs;
                dist = dot(pos, pos);
                if (distMin > dist)
                {
                    distMin = dist;
                    point = rnd;
                }
            }
        }
    }
    point = normalize(point + cell + vec3(0.5));
    return vec4(point, length(point * Radius - p));
}

//-----------------------------------------------------------------------------

void    Cell2Noise2Sphere(vec3 p, float Radius, out vec4 point1, out vec4 point2)
{
    p *= Radius;
    vec3  cell = floor(p);
    vec3  offs = p - cell - vec3(0.5);
    vec3  pos;
    vec3  rnd;
    vec3  d;
    float distMin1 = 1.0e38;
    float distMin2 = 1.0e38;
    float dist;
    for (d.z=-1.0; d.z<1.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<1.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<1.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE).xyz + d;
                pos = rnd - offs;
                dist = dot(pos, pos);
                if (dist < distMin1)
                {
                    distMin2 = distMin1;
                    distMin1 = dist;
                    point1.xyz = rnd;
                }
                else if (dist < distMin2)
                {
                    distMin2 = dist;
                    point2.xyz = rnd;
                }
            }
        }
    }
    point1.xyz = normalize(point1.xyz + cell + vec3(0.5));
    point1.w = distMin1;
    //point1.w = length(point1.xyz * Radius - p);
    point2.xyz = normalize(point2.xyz + cell + vec3(0.5));
    point2.w = distMin2;
    //point2.w = length(point2.xyz * Radius - p);
}

//-----------------------------------------------------------------------------

vec4    Cell2NoiseVecSphere(vec3 p, float Radius)
{
    p *= Radius;
    vec3  cell = floor(p);
    vec3  offs = p - cell - vec3(0.5);
    vec3  pos;
    vec3  point = vec3(0.0);
    vec3  rnd;
    vec3  d;
    float distMin = 1.0e38;
    float dist;
    for (d.z=-1.0; d.z<1.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<1.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<1.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE).xyz + d;
                pos = rnd - offs;
                dist = dot(pos, pos);
                if (distMin > dist)
                {
                    distMin = dist;
                    point = rnd;
                }
            }
        }
    }
    point = normalize(point + cell + vec3(0.5));
    return vec4(point, length(point * Radius - p));
}

//-----------------------------------------------------------------------------

float   Cell3Noise(vec3 p)
{
    vec3  cell = floor(p);
    vec3  offs = p - cell;
    vec3  pos;
    vec3  rnd;
    vec3  d;
    float dist;
    float distMin = 1.0e38;
    for (d.z=-1.0; d.z<2.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<2.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<2.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE).xyz + d;
                pos = rnd - offs;
                dist = dot(pos, pos);
                distMin = min(distMin, dist);
            }
        }
    }
    return sqrt(distMin);
}

//-----------------------------------------------------------------------------

float   Cell3NoiseSmooth(vec3 p, float falloff)
{
    vec3  cell = floor(p);
    vec3  offs = p - cell;
    vec3  pos;
    vec4  rnd;
    vec3  d;
    float dist;
    float res = 0.0;
    for (d.z=-1.0; d.z<2.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<2.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<2.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE);
                pos = rnd.xyz + d - offs;
                dist = dot(pos, pos);
                res += pow(dist, -falloff);
            }
        }
    }
    return pow(res, -0.5/falloff);
}

//-----------------------------------------------------------------------------

vec2    Cell3Noise2(vec3 p)
{
    vec3  cell = floor(p);
    vec3  offs = p - cell;
    vec3  pos;
    vec3  rnd;
    vec3  d;
    float dist;
    float distMin1 = 1.0e38;
    float distMin2 = 1.0e38;
    for (d.z=-1.0; d.z<2.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<2.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<2.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE).xyz + d;
                pos = rnd - offs;
                dist = dot(pos, pos);
                if (dist < distMin1)
                {
                    distMin2 = distMin1;
                    distMin1 = dist;
                }
                else
                    distMin2 = min(distMin2, dist);
            }
        }
    }
    return sqrt(vec2(distMin1, distMin2));
}

//-----------------------------------------------------------------------------

vec4    Cell3NoiseVec(vec3 p, float jitter)
{
    vec3  cell = floor(p);
    vec3  offs = p - cell;
    vec3  pos;
    vec3  point = vec3(0.0);
    vec3  rnd;
    vec3  d;
    float dist;
    float distMin = 1.0e38;
    for (d.z=-1.0; d.z<2.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<2.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<2.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE).xyz * jitter + d;
                pos = rnd - offs;
                dist = dot(pos, pos);
                if (distMin > dist)
                {
                    distMin = dist;
                    point = rnd;
                }
            }
        }
    }
    point = normalize(point + cell);
    return vec4(point, sqrt(distMin));
}

//-----------------------------------------------------------------------------

float   Cell3NoiseColor(vec3 p, out vec4 color)
{
    vec3  cell = floor(p);
    vec3  offs = p - cell;
    vec3  pos;
    vec4  rnd;
    vec4  rndM = vec4(1.0);
    vec3  d;
    float dist;
    float distMin = 1.0e38;
    for (d.z=-1.0; d.z<2.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<2.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<2.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE);
                pos = rnd.xyz + d - offs;
                dist = dot(pos, pos);
                if (dist < distMin)
                {
                    distMin = dist;
                    rndM = rnd;
                }
            }
        }
    }
    color = rndM;
    return sqrt(distMin);
}

//-----------------------------------------------------------------------------

vec2    Cell3Noise2Color(vec3 p, out vec4 color)
{
    vec3  cell = floor(p);
    vec3  offs = p - cell;
    vec3  pos;
    vec4  rnd;
    vec4  rndM = vec4(1.0);
    vec3  d;
    float dist;
    float distMin1 = 1.0e38;
    float distMin2 = 1.0e38;
    for (d.z=-1.0; d.z<2.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<2.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<2.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE);
                pos = rnd.xyz + d - offs;
                dist = dot(pos, pos);
                if (dist < distMin1)
                {
                    distMin2 = distMin1;
                    distMin1 = dist;
                    rndM = rnd;
                }
                else
                    distMin2 = min(distMin2, dist);
            }
        }
    }
    color = rndM;
    return sqrt(vec2(distMin1, distMin2));
}

//-----------------------------------------------------------------------------

float   Cell3NoiseSmoothColor(vec3 p, float falloff, out vec4 color)
{
    vec3  cell = floor(p);
    vec3  offs = p - cell;
    vec3  pos;
    vec4  rnd;
    vec4  rndM = vec4(1.0);
    vec3  d;
    float dist;
    float distMin = 1.0e38;
    float res = 0.0;
    for (d.z=-1.0; d.z<2.0; d.z+=1.0)
    {
        for (d.y=-1.0; d.y<2.0; d.y+=1.0)
        {
            for (d.x=-1.0; d.x<2.0; d.x+=1.0)
            {
                rnd = NoiseNearestUVec4((cell + d) / NOISE_TEX_3D_SIZE);
                pos = rnd.xyz + d - offs;
                dist = dot(pos, pos);
                if (dist < distMin)
                {
                    distMin = dist;
                    rndM = rnd;
                }
                res += pow(dist, -falloff);
            }
        }
    }
    res = pow(res, -0.5/falloff);
    color = rndM;
    return res;
}

//-----------------------------------------------------------------------------




//-----------------------------------------------------------------------------
// Spherical Fibonacci Mapping
// http://lgdv.cs.fau.de/publications/publication/Pub.2015.tech.IMMD.IMMD9.spheri/
// Optimized by iq https://www.shadertoy.com/view/lllXz4
//-----------------------------------------------------------------------------
#define round(x) floor(x + 0.5)
//-----------------------------------------------------------------------------

vec2 inverseSF(vec3 p, float n)
{
    const float phi = 1.61803398875;

    float m = 1.0 - 1.0/n;
    
    float fi = min(atan(p.y, p.x), pi);
    float cosTheta = p.z;
    
    float k  = max(2.0, floor(log(n * pi * sqrt(5.0) * (1.0 - cosTheta*cosTheta)) / log(phi+1.0)));
    float Fk = pow(phi, k) / sqrt(5.0);
    vec2  F  = vec2(round(Fk), round(Fk * phi)); // k, k+1

    vec2 ka = 2.0 * F / n;
    vec2 kb = 2.0 * pi * (fract((F+1.0) * phi) - (phi-1.0));
    
    mat2 iB = mat2(ka.y, -ka.x, kb.y, -kb.x ) / (ka.y*kb.x - ka.x*kb.y);
    
    vec2  c = floor(iB * vec2(fi, cosTheta - m));
    float d = 8.0;
    float j = 0.0;
    for (int s=0; s<4; s++)
    {
        vec2 uv = vec2(float(s-2*(s/2)), float(s/2));
        
        float i = dot(F, uv + c);
        
        float fi = 2.0*pi*fract(i*phi);
        float cosTheta = m - 2.0*i/n;
        float sinTheta = sqrt(1.0 - cosTheta*cosTheta);
        
        vec3  q  = vec3(cos(fi)*sinTheta, sin(fi)*sinTheta, cosTheta);
        vec3  r  = q - p;
        float d2 = dot(r, r);
        if (d2 < d) 
        {
            d = d2;
            j = i;
        }
    }

    return vec2(j, sqrt(d));
}

//-----------------------------------------------------------------------------

vec2 inverseSF(vec3 p, float n, out vec3 NearestPoint)
{
    const float phi = 1.61803398875;

    float m = 1.0 - 1.0/n;
    
    float fi = min(atan(p.y, p.x), pi);
    float cosTheta = p.z;
    
    float k  = max(2.0, floor( log(n * pi * sqrt(5.0) * (1.0 - cosTheta*cosTheta)) / log(phi+1.0)));
    float Fk = pow(phi, k)/sqrt(5.0);
    vec2  F  = vec2(round(Fk), round(Fk * phi)); // k, k+1

    vec2 ka = 2.0 * F  /n;
    vec2 kb = 2.0 * pi * (fract((F+1.0) * phi) - (phi-1.0));
    
    mat2 iB = mat2(ka.y, -ka.x, kb.y, -kb.x ) / (ka.y*kb.x - ka.x*kb.y);
    
    vec2  c = floor(iB * vec2(fi, cosTheta - m));
    float d = 8.0;
    float j = 0.0;
    for (int s=0; s<4; s++)
    {
        vec2 uv = vec2(float(s-2*(s/2)), float(s/2));
        
        float i = dot(F, uv + c);
        
        float fi = 2.0*pi*fract(i*phi);
        float cosTheta = m - 2.0*i/n;
        float sinTheta = sqrt(1.0 - cosTheta*cosTheta);
        
        vec3  q  = vec3(cos(fi)*sinTheta, sin(fi)*sinTheta, cosTheta);
        vec3  r  = q - p;
        float d2 = dot(r, r);
        if (d2 < d) 
        {
            NearestPoint = q;
            d = d2;
            j = i;
        }
    }

    return vec2(j, sqrt(d));
}

//-----------------------------------------------------------------------------




//-----------------------------------------------------------------------------
float radPeak;
float radInner;
float radRim;
float radOuter;
float heightFloor;
float heightPeak;
float heightRim;
float craterSphereRadius;
float craterRoundDist;
float craterDistortion;
vec4  craterRaysColor;
//-----------------------------------------------------------------------------

float   CraterHeightFunc(float lastlastLand, float lastLand, float height, float r)
{
    float distHeight = craterDistortion * height;

    float t = 1.0 - r/radPeak;
    float peak = heightPeak * craterDistortion * smoothstep(0.0, 1.0, t);

    t = smoothstep(0.0, 1.0, (r - radInner) / (radRim - radInner));
    float inoutMask = t*t*t;
    float innerRim = heightRim * distHeight * smoothstep(0.0, 1.0, inoutMask);

    t = smoothstep(0.0, 1.0, (radOuter - r) / (radOuter - radRim));
    float outerRim = distHeight * mix(0.05, heightRim, t*t);

    t = saturate((1.0 - r) / (1.0 - radOuter));
    float halo = 0.05 * distHeight * t;

    return mix(lastlastLand + height * heightFloor + peak + innerRim, lastLand + outerRim + halo, inoutMask);
}

//-----------------------------------------------------------------------------

float   RayedCraterColorFunc(float r, float fi, float rnd)
{
    float t = saturate((radOuter - r) / (radOuter - radRim));
    float d4 = NoiseU(vec3(70.3 * fi, rnd, rnd));
    d4 *= d4;
    d4 *= d4;
    float d16 = d4 * d4;
    d16 *= d16;
    return sqrt(t) * pow(saturate(/*0.001 * t * t +*/ d16 + 1.0 - smoothstep(d4, d4 + 0.75, r)), 2.5);
}

//-----------------------------------------------------------------------------

float   CraterNoise(vec3 point, float cratMagn, float cratFreq, float cratSqrtDensity, float cratOctaves)
{
    //craterSphereRadius = cratFreq * cratSqrtDensity;
    //point *= craterSphereRadius;
    point = (point * cratFreq + Randomize) * cratSqrtDensity;

    float  newLand = 0.0;
    float  lastLand = 0.0;
    float  lastlastLand = 0.0;
    float  lastlastlastLand = 0.0;
    float  amplitude = 1.0;
    float  cell;
    float  radFactor = 1.0 / cratSqrtDensity;

    // Craters roundness distortion
    noiseH           = 0.5;
    noiseLacunarity  = 2.218281828459;
    noiseOffset      = 0.8;
    noiseOctaves     = 3;
    craterDistortion = 1.0;
    craterRoundDist  = 0.03;

    radPeak  = 0.03;
    radInner = 0.15;
    radRim   = 0.2;
    radOuter = 0.8;

    for (int i=0; i<cratOctaves; i++)
    {
        lastlastlastLand = lastlastLand;
        lastlastLand = lastLand;
        lastLand = newLand;

        //vec3 dist = craterRoundDist * Fbm3D(point*2.56);
        //cell = Cell2NoiseSphere(point + dist, craterSphereRadius, dist).w;
        //craterSphereRadius *= 1.83;
        cell = Cell3Noise(point + craterRoundDist * Fbm3D(point*2.56));
        newLand = CraterHeightFunc(lastlastlastLand, lastLand, amplitude, cell * radFactor);

        //cell = inverseSF(point + 0.2 * craterRoundDist * Fbm3D(point*2.56), fibFreq);
        //rad = hash1(cell.x * 743.1) * 0.9 + 0.1;
        //newLand = CraterHeightFunc(lastlastlastLand, lastLand, amplitude, cell.y * radFactor / rad);
        //fibFreq   *= 1.81818182;
        //radFactor *= 1.3483997256; // = sqrt(1.81818182)

        if (cratOctaves > 1)
        {
            point       *= 1.81818182;
            amplitude   *= 0.55;
            heightPeak  *= 0.25;
            heightFloor *= 1.2;
            radInner    *= 0.60;
        }
    }

    return  cratMagn * newLand;
}

//-----------------------------------------------------------------------------

float   RayedCraterNoise(vec3 point, float cratMagn, float cratFreq, float cratSqrtDensity, float cratOctaves)
{
    vec3  rotVec = normalize(Randomize);

    // Craters roundness distortion
    noiseH           = 0.5;
    noiseLacunarity  = 2.218281828459;
    noiseOffset      = 0.8;
    noiseOctaves     = 3;
    craterDistortion = 1.0;
    craterRoundDist  = 0.03;
    float shapeDist = 1.0 + 0.5 * craterRoundDist * Fbm(point * 419.54);

    radPeak  = 0.002;
    radInner = 0.015;
    radRim   = 0.03;
    radOuter = 0.8;

    float newLand = 0.0;
    float lastLand = 0.0;
    float lastlastLand = 0.0;
    float lastlastlastLand = 0.0;
    float amplitude = 1.0;
    vec2  cell;
    float rad;
    float radFactor = shapeDist / cratSqrtDensity;
    float fibFreq = 2.0 * cratFreq;

    for (int i=0; i<cratOctaves; i++)
    {
        lastlastlastLand = lastlastLand;
        lastlastLand = lastLand;
        lastLand = newLand;

        //cell = Cell2NoiseSphere(point, craterSphereRadius).w;
        ////cell = Cell2NoiseVec(point * craterSphereRadius, 1.0).w;
        //newLand = CraterHeightFunc(0.0, lastLand, amplitude, cell * radFactor);

        cell    = inverseSF(point, fibFreq);
        rad     = hash1(cell.x * 743.1) * 0.9 + 0.1;
        newLand = CraterHeightFunc(lastlastlastLand, lastLand, amplitude, cell.y * radFactor / rad);

        if (cratOctaves > 1)
        {
            point = Rotate(2.0 * pi * hash1(float(i)), rotVec, point);
            fibFreq     *= 1.81818182;
            radFactor   *= 1.3483997256; // = sqrt(1.81818182)
            amplitude   *= 0.55;
            heightPeak  *= 0.25;
            heightFloor *= 1.2;
            radInner    *= 0.6;
        }
    }

    return  cratMagn * newLand;
}

//-----------------------------------------------------------------------------

float   RayedCraterColorNoise(vec3 point, float cratFreq, float cratSqrtDensity, float cratOctaves)
{
    vec3  binormal = normalize(vec3(-point.z, 0.0, point.x)); // = normalize(cross(point, vec3(0, 1, 0)));
    vec3  rotVec = normalize(Randomize);

    // Craters roundness distortion
    noiseH           = 0.5;
    noiseLacunarity  = 2.218281828459;
    noiseOffset      = 0.8;
    noiseOctaves     = 3;
    craterDistortion = 1.0;
    craterRoundDist  = 0.03;
    float shapeDist = 1.0 + 0.5 * craterRoundDist * Fbm(point * 419.54);
    float colorDist = 1.0 - 0.2 * Fbm(point * 4315.16);

    float color = 0.0;
    float fi;
    vec2  cell;
    vec3  cellCenter = vec3(0.0);
    float rad;
    float radFactor = shapeDist / cratSqrtDensity;
    float fibFreq = 2.0 * cratFreq;

    heightFloor = -0.5;
    heightPeak  = 0.6;
    heightRim   = 1.0;
    radPeak     = 0.002;
    radInner    = 0.015;
    radRim      = 0.03;
    radOuter    = 0.8;

    for (int i=0; i<cratOctaves; i++)
    {
        //cell = Cell2NoiseSphere(point, craterSphereRadius);
        ////cell = Cell2NoiseVec(point * craterSphereRadius, 1.0);
        //fi = acos(dot(binormal, normalize(cell.xyz - point))) / (pi*2.0);
        //color += vary * RayedCraterColorFunc(cell.w * radFactor, fi, 48.3 * dot(cell.xyz, Randomize));
        //radInner  *= 0.6;

        cell = inverseSF(point, fibFreq, cellCenter);
        rad  = hash1(cell.x * 743.1) * 0.9 + 0.1;
        fi   = acos(dot(binormal, normalize(cellCenter - point))) / (pi*2.0);
        color += RayedCraterColorFunc(cell.y * radFactor / rad, fi, 48.3 * dot(cellCenter, Randomize));

        if (cratOctaves > 1)
        {
            point = Rotate(2.0 * pi * hash1(float(i)), rotVec, point);
            fibFreq   *= 1.81818182;
            radFactor *= 1.3483997256; // = sqrt(1.81818182)
            radInner  *= 0.6;
        }
    }

    return color * colorDist;
}

//-----------------------------------------------------------------------------

float   VolcanoRidges(float r, float fi1, float fi2, float rnd)
{
    float  ridges1 = iqTurbulence(vec3(fi1, r, rnd + 1.126), 0.55);
    float  ridges2 = iqTurbulence(vec3(fi2, r, rnd + 0.754), 0.55);
    return ridges1 * saturate(abs(fi2)) + ridges2 * saturate(abs(fi1));
}

//-----------------------------------------------------------------------------

float   VolcanoRidges(float r, float fi1, float fi2, float rnd, int oct)
{
    float  ridges1 = iqTurbulence2(vec3(fi1, r, rnd + 1.126), 0.55, oct);
    float  ridges2 = iqTurbulence2(vec3(fi2, r, rnd + 0.754), 0.55, oct);
    return ridges1 * saturate(abs(fi2)) + ridges2 * saturate(abs(fi1));
}

//-----------------------------------------------------------------------------

float   VolcanoHeightFunc(float r, float fi1, float fi2, float rnd, float size)
{
    float rs = 0.25 * r / size;
    float shape  = saturate(2.0 * size);
    float height = 0.75 + 0.75 * shape * shape;

    float cone = saturate(1.0 - pow(r, 0.5 + 0.5 * shape));

    const float calderaRadius = 0.14;
    float t = rs * (10.0 / calderaRadius) - 2.5;
    float caldera = 0.85 + mix(0.07, 0.025, shape);
    float calderaMask = smoothstep(0.0, 1.0, t);

    noiseOctaves = 8;
    float ridges = VolcanoRidges(rs, fi1, fi2, rnd);
    cone += mix(0.02, 0.06, shape) * saturate(2.0 * sqrt(r)) * ridges;

    return height * mix(caldera, cone, calderaMask);
}

//-----------------------------------------------------------------------------

float   VolcanoGlowFunc(float r, float fi1, float fi2, float rnd, float size)
{
    float rs = 0.25 * r / size;

    const float calderaRadius = 0.14;
    float t = rs * (10.0 / calderaRadius) - 2.5;
    float caldera = saturate(1.0 - t);

    noiseOctaves = 8;
    float ridges = VolcanoRidges(rs, fi1, fi2, rnd, 5);

    float flows = smoothstep(0.225, 0.15, rs) * pow(saturate(ridges + volcanoFlows - 1.0), 0.5);

    return max(caldera, flows);
}

//-----------------------------------------------------------------------------

float   VolcanoNoise(vec3 point, float globalLand, float localLand)
{
    noiseLacunarity = 2.218281828459;
    noiseH          = 0.5;
    noiseOffset     = 0.8;

    float  frequency = 150.0 * volcanoFreq;
    float  density   = volcanoDensity;
    float  size      = volcanoRadius;
    float  newLand   = localLand;
    float  globLand  = globalLand - 1.0;
    float  amplitude = 2.0 * volcanoMagn;
	vec2   cell;
    vec3   cellCenter = vec3(0.0);
    vec3   rotVec   = normalize(Randomize);
    vec3   binormal = normalize(vec3(-point.z, 0.0, point.x)); // = normalize(cross(point, vec3(0, 1, 0)));
    float  distFreq = 18.361 * volcanoFreq;
    float  distMagn = 0.003;

    for (int i=0; i<volcanoOctaves; i++)
    {
        noiseOctaves = 4;
        vec3 p = point + distMagn * Fbm3D(point * distFreq);

        cell = inverseSF(p, frequency, cellCenter);

        float h = hash1(cell.x);
        float r = 40.0 * cell.y;
        if ((h < density) && (r < 1.0))
        {
            float rnd = 48.3 * dot(cellCenter, Randomize);
            vec3  cen = normalize(cellCenter - p);
            float a   = dot(p, cross(cen, binormal));
            float b   = dot(cen, binormal);
            float fi1 = atan( a,  b) / pi;
            float fi2 = atan(-a, -b) / pi;

            float volcano = globLand + amplitude * VolcanoHeightFunc(r, fi1, fi2, rnd, size);
            newLand = softExpMaxMin(newLand, volcano, 32);
        }

        if (volcanoOctaves > 1)
        {
            point = Rotate(2.0 * pi * hash1(float(i)), rotVec, point);
            frequency *= 2.0;
            //density   *= 2.0;
            size      *= 0.5;
            amplitude *= 1.2;
            distFreq  *= 2.0;
            distMagn  *= 0.5;
        }
    }

    return newLand;
}

//-----------------------------------------------------------------------------

vec2    VolcanoGlowNoise(vec3 point)
{
    noiseLacunarity = 2.218281828459;
    noiseH          = 0.5;
    noiseOffset     = 0.8;

    float  frequency = 150.0 * volcanoFreq;
    float  density   = volcanoDensity;
    float  size      = volcanoRadius;
    vec2   volcTempMask = vec2(0.0, 0.0);
	vec2   cell;
    vec3   cellCenter = vec3(0.0);
    vec3   rotVec   = normalize(Randomize);
    vec3   binormal = normalize(vec3(-point.z, 0.0, point.x)); // = normalize(cross(point, vec3(0, 1, 0)));
    float  distFreq = 18.361 * volcanoFreq;
    float  distMagn = 0.003;

    for (int i=0; i<volcanoOctaves; i++)
    {
        noiseOctaves = 4;
        vec3 p = point + distMagn * Fbm3D(point * distFreq);

        cell = inverseSF(p, frequency, cellCenter);

        float h = hash1(cell.x);
        float r = 40.0 * cell.y;
        if ((h < density) && (r < 1.0))
        {
            float rnd = 48.3 * dot(cellCenter, Randomize);
            vec3  cen = normalize(cellCenter - p);
            float a   = dot(p, cross(cen, binormal));
            float b   = dot(cen, binormal);
            float fi1 = atan( a,  b) / pi;
            float fi2 = atan(-a, -b) / pi;

            volcTempMask = max(volcTempMask, vec2(1.2 * VolcanoGlowFunc(r, fi1, fi2, rnd, size), 1.0 - 2.0 * r));
        }

        if (volcanoOctaves > 1)
        {
            point = Rotate(2.0 * pi * hash1(float(i)), rotVec, point);
            frequency *= 2.0;
            size      *= 0.5;
            distFreq  *= 2.0;
            distMagn  *= 0.5;
        }
    }

    return volcTempMask;
}

//-----------------------------------------------------------------------------

float   MareHeightFunc(float lastLand, float lastlastLand, float height, float r, inout float mareFloor)
{
    float t;

    if (r < radInner)
    {   // crater bottom
        mareFloor = 1.0;
        return lastlastLand + height * heightFloor;
    }
    else if (r < radRim)
    {   // inner rim
        t = (r - radInner) / (radRim - radInner);
        t = smoothstep(0.0, 1.0, t);
        mareFloor = 1.0 - t;
        return mix(lastlastLand + height * heightFloor, lastLand + height * heightRim * craterDistortion, t);
    }
    else if (r < radOuter)
    {   // outer rim
        t = 1.0 - (r - radRim) / (radOuter - radRim);
        mareFloor = 0.0;
        return mix(lastLand, lastLand + height * heightRim * craterDistortion, smoothstep(0.0, 1.0, t*t));
    }
    else
    {
        mareFloor = 0.0;
        return lastLand;
    }
}

//-----------------------------------------------------------------------------

float   MareNoise(vec3 point, float globalLand, float bottomLand, inout float mareFloor)
{
    point = (point * mareFreq + Randomize) * mareSqrtDensity;

    float  amplitude = 0.7;
    float  newLand = globalLand;
    float  lastLand;
    float  cell;
    float  radFactor = 1.0 / mareSqrtDensity;

    radPeak  = 0.0;
    radInner = 0.5;
    radRim   = 0.6;
    radOuter = 1.0;
    heightFloor = 0.0;
    heightRim   = 0.2;

    for (int i=0; i<3; i++)
    {
        cell = Cell2Noise(point + 0.07 * Fbm3D(point));
        lastLand = newLand;
        newLand = MareHeightFunc(lastLand, bottomLand, amplitude, cell * radFactor, mareFloor);
        point = point * 1.3 + Randomize;
        amplitude *= 0.62;
        radFactor *= 1.2;
    }

    mareFloor = 1.0 - mareFloor;
    return newLand;
}

//-----------------------------------------------------------------------------

float   CrackHeightFunc(float lastLand, float lastlastLand, float height, float r, vec3 p)
{
    p.x += 0.05 * r;
    float inner = smoothstep(0.0, 0.5, r);
    float outer = smoothstep(0.5, 1.0, r);
    float cracks = height * (0.4 * Noise(p * 625.7) * (1.0 - inner) + inner * (1.0 - outer));
    float land = mix(lastLand, lastlastLand, r);
    return mix(cracks, land, outer);
}

//-----------------------------------------------------------------------------

float   CrackNoise(vec3 point, out float mask)
{
    point = (point + Randomize) * cracksFreq;

    float  newLand = 0.0;
    float  lastLand = 0.0;
    float  lastlastLand = 0.0;
    vec2   cell;
    float  r;
    float  ampl = 0.4 * cracksMagn;
    mask = 1.0;

    // Rim shape and height distortion
    noiseH          = 0.5;
    noiseLacunarity = 2.218281828459;
    noiseOffset     = 0.8;
    noiseOctaves    = 6.0;

    for (int i=0; i<cracksOctaves; i++)
    {
        cell = Cell2Noise2(point + 0.02 * Fbm3D(1.8 * point));
        r    = smoothstep(0.0, 1.0, 250.0 * abs(cell.y - cell.x));
        lastlastLand = lastLand;
        lastLand = newLand;
        newLand = CrackHeightFunc(lastlastLand, lastLand, ampl, r, point);
        point = point * 1.2 + Randomize;
        ampl *= 0.8333;
        mask *= smoothstep(0.6, 1.0, r);
    }

    return newLand;
}

//-----------------------------------------------------------------------------

float   CrackColorNoise(vec3 point, out float mask)
{
    point = (point + Randomize) * cracksFreq;

    float  newLand = 0.0;
    float  lastLand = 0.0;
    float  lastlastLand = 0.0;
    vec2   cell;
    float  r;

    // Rim height and shape distortion
    noiseH          = 0.5;
    noiseLacunarity = 2.218281828459;
    noiseOffset     = 0.8;
    noiseOctaves    = 6.0;
    mask = 1.0;

    for (int i=0; i<cracksOctaves; i++)
    {
        cell = Cell2Noise2(point + 0.02 * Fbm3D(1.8 * point));
        r    = smoothstep(0.0, 1.0, 250.0 * abs(cell.y - cell.x));
        lastlastLand = lastLand;
        lastLand = newLand;
        newLand = CrackHeightFunc(lastlastLand, lastLand, 1.0, r, point);
        point = point * 1.2 + Randomize;
        mask *= smoothstep(0.6, 1.0, r);
    }

    return pow(saturate(1.0 - newLand), 2.0);
}

//-----------------------------------------------------------------------------

float   DunesNoise(vec3 point, float octaves)
{
    //float dir = Noise(point * 3.86) * 197.3 * dunesFreq;
    float dir = sNoise(point * 3.86) * 197.3 * dunesFreq;
    vec3  p = point;

    float glob = saturate(Fbm(p * 7.21) + 0.3);
    float dwin = 1.0 / (octaves - 1.0);
    float win = 0;

    float wave, fade, dist;
    float dunes = 0.0;
    float ampl  = 0.05;
    float lac   = 1.17;

    for (int i=0; i<octaves; i++)
    {
        //dist = dir + Noise(p * dunesFreq * 100.0) * 1.7;
        dist = dir + sNoise(p * dunesFreq * 25.0) * 12.7 + sNoise(p * dunesFreq * 300.0) * 1.2;
        wave = fract(dist / 3.1415926);
        wave = cos(3.1415926 * wave * wave);
        fade = smoothstep(win-0.5*dwin, win, glob) * (1.0 - smoothstep(win+dwin, win+1.5*dwin, glob));
        //dunes += (1.0 - sqrt(wave * wave + 0.005)) * ampl * fade;
        dunes += (1.0 - sqrt(wave * wave + 0.005)) * (ampl + Fbm(p * dunesFreq * 150.0) * 0.05 - 0.03) * fade;
        p = p * lac + vec3(3.17, 5.38, 8.79);
        dir  *= lac;
        ampl /= lac;
        win  += dwin;
    }

    return dunes;
}

//-----------------------------------------------------------------------------

void	SolarSpotsHeightNoise(vec3 point, out float botMask, out float filMask, out float filaments)
{
    vec3 binormal = normalize(vec3(-point.z, 0.0, point.x)); // = normalize(cross(point, vec3(0, 1, 0)));
    craterSphereRadius = mareFreq * mareSqrtDensity;

	botMask = 1.0;
	filMask = 1.0;
    filaments = 0.0;

    float filam, botmask, filmask;
    float fi, rnd, t;
    vec4  cell;
    float radFactor = 2.0 / mareSqrtDensity;

    radInner = 0.4;
    radOuter = 1.0;

	vec3 dist = 0.01 * Fbm3D(point * 7.6);
	point += dist * 0.5;

    //for (int i=0; i<3; i++)
    {
        cell = Cell2NoiseSphere(point, craterSphereRadius);
        //cell = Cell2NoiseVec(point * craterSphereRadius);
        fi = acos(dot(binormal, normalize(cell.xyz - point))) / (pi*2.0);
		rnd = 48.3 * dot(cell.xyz, Randomize);

        t = saturate((cell.w * radFactor - radInner) / (radOuter - radInner));
	    botmask = smoothstep(0.0, 1.0, t);
	    filmask = smoothstep(0.0, 0.1, t) * (1.0 - botmask);
        filam   = NoiseU(vec3(montesFreq * fi, rnd, rnd));

		filaments += filam;
		filMask *= filmask;
		botMask *= botmask;

        craterSphereRadius *= 1.83;
        radInner *= 0.60;
        radOuter = 0.60;
    }
}

//-----------------------------------------------------------------------------

void	SolarSpotsTempNoise(vec3 point, out float botMask, out float filMask, out float filaments)
{
    vec3 binormal = normalize(vec3(-point.z, 0.0, point.x)); // = normalize(cross(point, vec3(0, 1, 0)));
    craterSphereRadius = mareFreq * mareSqrtDensity;

	botMask = 1.0;
	filMask = 1.0;
    filaments = 0.0;

    float filam, botmask, filmask;
    float fi, rnd, t;
    vec4  cell;
    float radFactor = 2.0 / mareSqrtDensity;

    radInner = 0.4;
    radOuter = 1.0;

	vec3 dist = 0.01 * Fbm3D(point * 7.6);
	point += dist * 0.5;

    //for (int i=0; i<3; i++)
    {
        cell = Cell2NoiseSphere(point, craterSphereRadius);
        //cell = Cell2NoiseVec(point * craterSphereRadius);
        fi = acos(dot(binormal, normalize(cell.xyz - point))) / (pi*2.0);
		rnd = 48.3 * dot(cell.xyz, Randomize);

        t = saturate((cell.w * radFactor - radInner) / (radOuter - radInner));
        botmask = smoothstep(0.0, 0.2, t);
        filmask = (1.0 - smoothstep(0.7, 1.0, t)) * smoothstep(0.0, 0.1, t) * 0.85;
        filam   = NoiseU(vec3(montesFreq * fi, rnd, rnd)) * t * 0.75;

		filaments += filam;
		filMask *= filmask;
		botMask *= botmask;

        craterSphereRadius *= 1.83;
        radInner *= 0.60;
        radOuter = 0.60;
    }
}

//-----------------------------------------------------------------------------
// Can be used to create lava planets or icebergs
// climate-dependent: gapWidth = climate, flood = 1.5
// random:            gapWidth = 0.7,     flood = 1.0
float   LithoCellsNoise(vec3 point, float gapWidth, float flood)
{
    float gap = saturate(1.0 - 1.0 * gapWidth);
    vec2 cell;
    vec3 p;
    vec4 col;

    noiseOctaves = 4;
    p = point * 14.2 + Randomize;
    p += 0.1 * Fbm3D(p * 0.7);

    cell = Cell3Noise2Color(p * (0.5 * gap - 0.5), col);

    float lithoCells = (1.0 - gap) * sqrt(abs(cell.y - cell.x));
    lithoCells = smoothstep(0.1 * gap, 0.6 * gap, lithoCells);
    lithoCells *= step(col.r, flood - gap);

    return lithoCells;
}

//-----------------------------------------------------------------------------

vec3    TurbulenceTerra(vec3 point)
{
    const float scale = 0.7;

    vec3  twistedPoint = point;
    vec3  cellCenter = vec3(0.0);
    vec2  cell;
    float r, fi, rnd, dist, dist2, dir;
    float strength = 5.5;
    float freq = 20.0 * scale;
    float size = 4.0 * scale;
    float dens = 0.3;

    for (int i = 0; i<2; i++)
    {
        vec2  cell = inverseSF(point, freq, cellCenter);
        rnd = hash1(cell.x);
        r = size * cell.y;

        if ((rnd < dens) && (r < 1.0))
        {
            dir = sign(0.5 * dens - rnd);
            dist = saturate(1.0 - r);
            dist2 = saturate(0.5 - r);
            fi = pow(dist, strength) * (exp(-6.0 * dist2) + 0.25);
            twistedPoint = Rotate(dir * 15.0 * sign(cellCenter.y + 0.001) * fi, cellCenter.xyz, point);
        }

        freq = min(freq * 2.0, 1600.0);
        size = min(size * 1.2, 30.0);
        strength = strength * 1.5;
        point = twistedPoint;
    }

    return twistedPoint;
}

//-----------------------------------------------------------------------------

vec3    CycloneNoiseTerra(vec3 point, inout float weight, inout float coverage)
{
    vec3  rotVec = normalize(Randomize);
    vec3  twistedPoint = point;
    vec3  cellCenter = vec3(0.0);
    vec2  cell;
    float r, fi, rnd, dist, w;
    float mag = -tidalLock * cycloneMagn;
    float freq = cycloneFreq * 50.0;
    float dens = cycloneDensity * 0.02;
    float size = 8.0;

    for (int i = 0; i<cycloneOctaves; i++)
    {
        cell = inverseSF(point, freq, cellCenter);
        rnd = hash1(cell.x);
        r = size * cell.y;

        if ((rnd < dens) && (r < 1.0))
        {
            dist = 1.0 - r;
            fi = mix(log(r), dist * dist * dist, r);
            twistedPoint = Rotate(mag * sign(cellCenter.y + 0.001) * fi, cellCenter.xyz, point);
            w = saturate(1.0 - r * 10.0);
            weight = min(weight, 1.0 - w * w);
            coverage = mix(coverage, 1.0, dist);
        }

        freq *= 2.0;
        dens *= 2.0;
        size *= 2.0;
        point = twistedPoint;
    }

    weight = saturate(weight);
    return twistedPoint;
}

//-----------------------------------------------------------------------------

float   HeightMapCloudsTerra(vec3 point)
{
    float zones = cos(point.y * stripeZones);
    float ang = zones * stripeTwist;
    vec3  twistedPoint = point;
    float coverage = cloudsCoverage;
    float weight = 1.0;
    float offset = 0.0;

    // Compute the cyclons
    if (tidalLock > 0.0)
    {
        vec3  cycloneCenter = vec3(0.0, 1.0, 0.0);
        float r = length(cycloneCenter - point);
        float mag = -tidalLock * cycloneMagn;
        if (r < 1.0)
        {
            float dist = 1.0 - r;
            float fi = mix(log(r), dist*dist*dist, r);
            twistedPoint = Rotate(mag * fi, cycloneCenter, point);
            weight = saturate(r * 40.0 - 0.05);
            weight = weight * weight;
            coverage = mix(coverage, 1.0, dist);
        }
        weight *= smoothstep(-0.2, 0.0, point.y);   // surpress clouds on a night side
    }
    else
        twistedPoint = CycloneNoiseTerra(point, weight, coverage);

    // Compute turbulence
    twistedPoint = TurbulenceTerra(twistedPoint);

    // Compute the Coriolis effect
    float sina = sin(ang);
    float cosa = cos(ang);
    twistedPoint = vec3(cosa*twistedPoint.x - sina*twistedPoint.z, twistedPoint.y, sina*twistedPoint.x + cosa*twistedPoint.z);
    twistedPoint = twistedPoint * cloudsFreq + Randomize;

    // Compute the flow-like distortion
    vec3 p = twistedPoint * cloudsFreq * 6.37;
    vec3 q = p + FbmClouds3D(p);
    vec3 r = p + FbmClouds3D(q);
    float f = FbmClouds(r) * 0.7 + coverage - 0.3;
    float global = saturate(f) * weight;

    // Compute turbulence features
    //noiseOctaves = cloudsOctaves;
    //float turbulence = (Fbm(point * 100.0 * cloudsFreq + Randomize) + 1.5);// * smoothstep(0.0, 0.05, global);

    return global;
}

//-----------------------------------------------------------------------------

vec3    TurbulenceGasGiant(vec3 point)
{
    const float scale = 0.7;

    vec3  twistedPoint = point;
    vec3  cellCenter = vec3(0.0);
    vec2  cell;
    float r, fi, rnd, dist, dist2, dir;
    float strength = 5.5;
    float freq = 800 * scale;
    float size = 15.0 * scale;
    float dens = 0.8;

    for (int i = 0; i<5; i++)
    {
        vec2  cell = inverseSF(point, freq, cellCenter);
        rnd = hash1(cell.x);
        r = size * cell.y;

        if ((rnd < dens) && (r < 1.0))
        {
            dir = sign(0.5 * dens - rnd);
            dist = saturate(1.0 - r);
            dist2 = saturate(0.5 - r);
            fi = pow(dist, strength) * (exp(-6.0 * dist2) + 0.25);
            twistedPoint = Rotate(dir * stripeTwist * sign(cellCenter.y) * fi, cellCenter.xyz, point);
        }

        freq = min(freq * 2.0, 1600.0);
        size = min(size * 1.2, 30.0);
        strength = strength * 1.5;
        point = twistedPoint;
    }

    return twistedPoint;
}

//-----------------------------------------------------------------------------

vec3    CycloneNoiseGasGiant(vec3 point, inout float offset)
{
    vec3  rotVec = normalize(Randomize);
    vec3  twistedPoint = point;
    vec3  cellCenter = vec3(0.0);
    vec2  cell;
    float r, fi, rnd, dist, dist2, dir;
    float offs = 0.6;
    float squeeze = 1.7;
    float strength = 2.5;
    float freq = cycloneFreq * 50.0;
    float dens = cycloneDensity * 0.02;
    float size = 6.0;

    for (int i = 0; i<cycloneOctaves; i++)
    {
        cell = inverseSF(vec3(point.x, point.y * squeeze, point.z), freq, cellCenter);
        rnd = hash1(cell.x);
        r = size * cell.y;

        if ((rnd < dens) && (r < 1.0))
        {
            dir = sign(0.7 * dens - rnd);
            dist = saturate(1.0 - r);
            dist2 = saturate(0.5 - r);
            fi = pow(dist, strength) * (exp(-6.0 * dist2) + 0.5);
            twistedPoint = Rotate(cycloneMagn * dir * sign(cellCenter.y + 0.001) * fi, cellCenter.xyz, point);
            offset += offs * fi * dir;
        }

        freq = min(freq * 2.0, 6400.0);
        dens = min(dens * 3.5, 0.3);
        size = min(size * 1.5, 15.0);
        offs = offs * 0.85;
        squeeze = max(squeeze - 0.3, 1.0);
        strength = max(strength * 1.3, 0.5);
        point = twistedPoint;
    }

    return twistedPoint;
}

//-----------------------------------------------------------------------------

float   HeightMapCloudsGasGiant(vec3 point)
{
    vec3  twistedPoint = point;

    // Compute zones
    float zones = Noise(vec3(0.0, twistedPoint.y * stripeZones * 0.5, 0.0)) * 0.6 + 0.25;
    float offset = 0.0;

    // Compute cyclons
    if (cycloneOctaves > 0.0)
        twistedPoint = CycloneNoiseGasGiant(twistedPoint, offset);

    // Compute turbulence
    twistedPoint = TurbulenceGasGiant(twistedPoint);

    // Compute stripes
    noiseOctaves = cloudsOctaves;
    float turbulence = Fbm(twistedPoint * 0.2);
    twistedPoint = twistedPoint * (0.05 * cloudsFreq) + Randomize;
    twistedPoint.y *= 100.0 + turbulence;
    float height = stripeFluct * (Fbm(twistedPoint) * 0.7 + 0.5);

    return zones + height + offset;
}

//-----------------------------------------------------------------------------

float   HeightMapSun(vec3 point)
{
    // Flows
    noiseOctaves = 5;
    vec3  p = point * colorDistFreq + Randomize;
    vec3  dist = 2.5 * Fbm3D(p * 0.5);
    noiseOctaves = 3;
    float flows = Fbm(p * 7.5 + dist);

    // Granularity
    noiseOctaves = 5;
    p = point * hillsFreq + Randomize;
    dist = dunesMagn * Fbm3D(p * 0.2);
    vec2  cell = Cell3Noise2(p + dist);
    float gran = smoothstep(0.1, 1.0, sqrt(abs(cell.y - cell.x))) - 0.5;

    // Solar spots
    float botMask = 1.0;
    float filMask = 0.0;
    float filaments = 0.0;
    if (mareSqrtDensity > 0.01)
    {
        noiseOctaves = 5;
        SolarSpotsHeightNoise(point, botMask, filMask, filaments);
    }

    const float surfHeight = 1.0;
    const float filHeight  = 0.6;
    const float spotHeight = 0.5;

    //return (flows * 0.1 + gran * (1.0 - filMask)) * mix(spotHeight, surfHeight, botMask) + filMask * mix(spotHeight, filHeight, filaments);
    //return (0.8 + flows * 0.1) * botMask + gran * 0.03 * (1.0 - filMask) + saturate(filaments) * 0.1 * filMask;
    return (0.8 + flows * 0.1) * colorDistMagn * botMask + gran * hillsMagn * (1.0 - filMask) + saturate(filaments) * 0.1 * hillsMagn * filMask;
}

//-----------------------------------------------------------------------------

float   GlowMapSun(vec3 point)
{
    // Flows
    noiseOctaves = 5;
    vec3  p = point * colorDistFreq + Randomize;
    vec3  dist = 2.5 * Fbm3D(p * 0.5);
    noiseOctaves = 3;
    float flows = Fbm(p * 7.5 + dist);

    // Granularity
    noiseOctaves = 5;
    p = point * hillsFreq + Randomize;
    dist = dunesMagn * Fbm3D(p * 0.2);
    vec2  cell = Cell3Noise2(p + dist);
    float gran = smoothstep(0.1, 1.0, sqrt(abs(cell.y - cell.x)));

    // Solar spots
    float botMask   = 1.0;
    float filMask   = 0.0;
    float filaments = 0.0;
    if (mareSqrtDensity > 0.01)
    {
        noiseOctaves = 5;
        SolarSpotsTempNoise(point, botMask, filMask, filaments);
    }

    float granTopTemp = colorParams.z;
    float granBotTemp = colorParams.w;
    float surfTemp = 1.0;
    float filTemp  = granTopTemp;
    float spotTemp = granBotTemp;

    return (flows * 0.1 + mix(granBotTemp, granTopTemp, gran) * (1.0 - filMask)) * mix(spotTemp, surfTemp, botMask) + filMask * mix(spotTemp, filTemp, filaments);
}

//-----------------------------------------------------------------------------

#endif
