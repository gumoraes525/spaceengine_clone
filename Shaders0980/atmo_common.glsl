// The include file for SpaceEngine's planetary surface shaders
//
// Precomputed Atmospheric Scattering
// Copyright (C) 2008 Eric Bruneton
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
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
// THE POSSIBILITY OF SUCH DAMAGE.

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

const int RES_R    = 32;
const int RES_MU   = 64; // 128
const int RES_MU_S = 32;
const int RES_NU   = 8;
const float INV_RES_NU = 1.0 / RES_NU;

const float pi = 3.14159265359;

#endif

//-----------------------------------------------------------------------------
// Uniforms

uniform sampler2D irradianceSampler;    // precomputed skylight irradiance (E table)
uniform sampler2D transmittanceSampler; // precomputed transmittance (T table)
uniform sampler3D inscatterSampler;     // precomputed inscattered light (S table)

uniform vec4 AtmoParams1;   // (density, scattering bright, skylight bright, exposure)
uniform vec4 AtmoParams2;   // (MieG, MieFade, HR, HM);
uniform vec3 AtmoRayleigh;  // (betaR)
uniform vec3 AtmoMieExt;    // (betaMExt);
uniform vec2 AtmoColAdjust; // (hsl color adjust);
uniform vec4 Radiuses;      // (atmosphere bottom radius, atmosphere top radius, atmosphere height, surface radius)

#ifdef _FRAGMENT_

float atmoH;
float atmoH2;
float planRadius2;
float mieG2;
float HorizonFixEps;

vec3  Attenuation;
float tex4Dlerp, tex4Dlerpi, tex4Dlerpf;

//-----------------------------------------------------------------------------

vec3    rgb2hsl(vec3 rgb)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(rgb.bg, K.wz), vec4(rgb.gb, K.xy), step(rgb.b, rgb.g));
    vec4 q = mix(vec4(p.xyw, rgb.r), vec4(rgb.r, p.yzx), step(p.x, rgb.r));
    float d = q.x - min(q.w, q.y);
    const float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

//-----------------------------------------------------------------------------

vec3    hsl2rgb(vec3 hsl)
{
    const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(hsl.xxx + K.xyz) * 6.0 - K.www);
    return hsl.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), hsl.y);
}

//-----------------------------------------------------------------------------

vec4 texture4D(float r, float mu, float muS)
{
    float rho2 = r * r - planRadius2;
    float rho = sqrt(rho2);
    float rmu = r * mu;
    float delta = rmu * rmu - rho2;
    vec4  cst = ((rmu < 0.0) && (delta > 0.0)) ? vec4(1.0, 0.0, 0.0, 0.5 - 0.5 / float(RES_MU)) : vec4(-1.0, atmoH2, atmoH, 0.5 + 0.5 / float(RES_MU));
    float uR = 0.5 / float(RES_R) + rho / atmoH * (1.0 - 1.0 / float(RES_R));

    //float uMu = cst.w + (rmu * cst.x + sqrt(delta + cst.y)) / (rho + cst.z) * (0.5 - 1.0 / float(RES_MU));

    float uMu = cst.w;
    if (rho + cst.z > 0.0)
        uMu += (rmu * cst.x + sqrt(delta + cst.y)) / (rho + cst.z) * (0.5 - 1.0 / float(RES_MU));

    // paper formula
    float uMuS = 0.5 / float(RES_MU_S) + max((1.0 - exp(-3.0 * muS - 0.6)) / (1.0 - exp(-3.6)), 0.0) * (1.0 - 1.0 / float(RES_MU_S));
    // better formula
    //float uMuS = 0.5 / float(RES_MU_S) + (atan(max(muS, -0.1975) * tan(1.26 * 1.1)) / 1.1 + (1.0 - 0.26)) * 0.5 * (1.0 - 1.0 / float(RES_MU_S));
    vec3 uvw = vec3((tex4Dlerpi + uMuS) * INV_RES_NU, uMu, uR);
    vec4 color = texture(inscatterSampler, uvw);
    uvw.x += INV_RES_NU;
    return mix(color, texture(inscatterSampler, uvw), tex4Dlerpf);
}

//-----------------------------------------------------------------------------
// Rayleigh phase function
float phaseFunctionR(float mu)
{
    const float ca = 3.0 / (16.0 * pi);
    return ca + ca*mu*mu;
}

//-----------------------------------------------------------------------------
// Mie phase function
float phaseFunctionM(float mu)
{
    const float ca = 3.0 / (8.0 * pi);
    return (ca - ca * mieG2) * pow(1.0 + mieG2 - 2.0*AtmoParams2.r*mu, -1.5) * (1.0 + mu*mu) / (2.0 + mieG2);
}

//-----------------------------------------------------------------------------
// approximated single Mie scattering (cf. approximate Cm in paragraph
// "Angular precision")  rayMie.rgb=C*, rayMie.w=Cm,r
vec3 getMie(vec4 rayMie)
{
    return (rayMie.w * AtmoRayleigh.r / max(rayMie.x, 1e-4)) * (rayMie.rgb / AtmoRayleigh.rgb);
}

//-----------------------------------------------------------------------------
// irradiance by sky light
// h - relative height (h = (r - planRadius) / atmoHeight)
vec3 irradiance(float h, float muS)
{
    //float uMuS = (muS + 0.2) / 1.2;
    float uMuS = muS * 0.769230769 + 0.153846154;   // = (muS + 0.2) / 1.3;
    return texture(irradianceSampler, vec2(uMuS, h)).rgb;
}

//-----------------------------------------------------------------------------
// transmittance(transparency) of atmosphere for infinite ray (r,mu)
// (mu=cos(view zenith angle)), intersections with ground ignored
// h - relative height (h = (r - planRadius) / atmoHeight)
vec3 transmittance(float sqrth, float mu)
{
    //float uMu = atan((mu + 0.15) / (1.0 + 0.15) * tan(1.5)) / 1.5;
    //float uMu = atan((mu + 0.18) / (1.0 + 0.18) * tan(1.5)) / 1.5;
    float uMu = atan(mu * 11.950355887 + 2.1510640597) * 0.6666666667;
    return texture(transmittanceSampler, vec2(uMu, sqrth)).rgb;
}

//-----------------------------------------------------------------------------
// transmittance(=transparency) of atmosphere for infinite ray (r,mu)
// (mu=cos(view zenith angle)), or zero if ray intersects ground
// h - relative height (h = (r - planRadius) / atmoHeight)
vec3 transmittanceWithShadow(float sqrth, float mu, float mu0)
{
    return (mu < mu0) ? vec3(0.0) : transmittance(sqrth, mu);
}

//-----------------------------------------------------------------------------
// transmittance(=transparency) of atmosphere for infinite ray (r,mu)
// (mu=cos(view zenith angle)), or zero if ray intersects ground
// h - relative height (h = (r - planRadius) / atmoHeight)
vec3 transmittanceWithShadowDens(float sqrth, float mu, float mu0)
{
    return (mu < mu0) ? vec3(0.0) : mix(vec3(1.0), transmittance(sqrth, mu), AtmoParams1.x);
}

//-----------------------------------------------------------------------------
// transmittance (transparency) of atmosphere between x and x0
// assume segment x,x0 not intersecting ground
// r=||x||, mu=cos(zenith angle of [x,x0) ray at x)
vec3 transmittance(float sqrth, float mu, float sqrth0, float mu0)
{
    vec3 tr;
    if (mu > 0.0)
        tr = transmittance(sqrth, mu) / transmittance(sqrth0, mu0);
    else
        tr = transmittance(sqrth0, -mu0) / transmittance(sqrth, -mu);
    return mix(vec3(1.0), tr, AtmoParams1.x);
}

//-----------------------------------------------------------------------------
// optical depth for ray (r,mu) of length d, using analytic formula
// (mu=cos(view zenith angle)), intersections with ground ignored
// H = height scale of exponential density function
float opticalDepth(float H, float r, float mu, float d)
{
    float rcpH = 1.0/H;
    float a = sqrt(0.5*r*rcpH);
    float dr = d/r;
    vec2  a01 = a * vec2(mu, dr + mu);
    vec2  a01s = sign(a01);
    vec2  a01sq = a01*a01;
    float x = (a01s.y > a01s.x) ? exp(a01sq.x) : 0.0;
    vec2  y = a01s / (2.3193*abs(a01) + sqrt(1.52*a01sq + 4.0)) * vec2(1.0, exp(-d * rcpH * (0.5*dr + mu)));
    return sqrt(6.2831*H*r) * exp((Radiuses.x-r) * rcpH) * (x + dot(y, vec2(1.0, -1.0)));
}

//-----------------------------------------------------------------------------
// transmittance (transparency) of atmosphere for ray (r,mu) of length d
// (mu = cos(view zenith angle)), intersections with ground ignored
// uses analytic formula instead of transmittance texture
vec3 transmittanceAnalytic(float r, float mu, float d)
{
    vec3 tr = exp(-AtmoRayleigh.rgb * opticalDepth(AtmoParams2.z, r, mu, d) - AtmoMieExt.rgb * opticalDepth(AtmoParams2.w, r, mu, d));
    if (isnan(tr.r)) tr = vec3(1.0);
    return mix(vec3(1.0), tr, AtmoParams1.x);
}

//-----------------------------------------------------------------------------
//S[L]|x - T(x,xs)S[l]|xs = S[L]|x for spherical ground
//inscattered light along ray x+tv, when sun in direction s (=S[L]|x)
vec3 inscatterSky(vec3 lightVec)
{
    const float ca = 0.5 * float(RES_NU) - 0.5;
    float nu = dot(eyeVec, lightVec);
    tex4Dlerp  = nu * ca + ca;
    tex4Dlerpi = floor(tex4Dlerp);
    tex4Dlerpf = tex4Dlerp - tex4Dlerpi;

    float EyeMuS = dot(EyePosM, lightVec) / EyeR;
    float phaseR = phaseFunctionR(nu);
    float phaseM = phaseFunctionM(nu);
    vec4  inScatter = max(texture4D(EyeR, EyeMu, EyeMuS), 0.0);

    // Avoids imprecision problems in Mie scattering when sun is below horizon
    inScatter.w *= smoothstep(0.0, AtmoParams2.y, EyeMuS);

    inScatter.rgb = inScatter.rgb * phaseR + getMie(inScatter) * phaseM;

    // Change resulting inscatter hue and saturation
    inScatter.xyz = rgb2hsl(inScatter.rgb);
    inScatter.x  += AtmoColAdjust.x;
    inScatter.y   = clamp(inScatter.y * AtmoColAdjust.y, 0.0, 1.0);
    inScatter.z  *= AtmoParams1.y;
    inScatter.rgb = hsl2rgb(inScatter.xyz);

    return inScatter.rgb;
}

//-----------------------------------------------------------------------------

vec3 inscatterGround(vec3 lightVec)
{
    const float ca = 0.5 * (float(RES_NU) - 1.0);
    float nu = dot(eyeVec, lightVec);
    tex4Dlerp  = nu * ca + ca;
    tex4Dlerpi = floor(tex4Dlerp);
    tex4Dlerpf = tex4Dlerp - tex4Dlerpi;

    float phaseR = phaseFunctionR(nu);
    float EyeMuS  = dot(EyePosM, lightVec) / EyeR;
    vec4  eyeInScatter  = texture4D(EyeR, EyeMu,  EyeMuS);

    float phaseM = phaseFunctionM(nu);
    float FragMuS = dot(FragPos, lightVec) / FragR;
    vec4  fragInScatter = texture4D(FragR, FragMu, FragMuS);

    vec4  inScatter = max(eyeInScatter - Attenuation.rgbr * fragInScatter, 0.0);

    // Avoids imprecision problems in Mie scattering when sun is below horizon
    inScatter.a *= smoothstep(0.0, AtmoParams2.y, EyeMuS);

    inScatter.rgb = inScatter.rgb * phaseR + getMie(inScatter) * phaseM;

    // Change resulting inscatter hue and saturation
    inScatter.xyz = rgb2hsl(inScatter.rgb);
    inScatter.x  += AtmoColAdjust.x;
    inScatter.y   = clamp(inScatter.y * AtmoColAdjust.y, 0.0, 1.0);
    inScatter.z  *= AtmoParams1.y;
    inScatter.rgb = hsl2rgb(inScatter.xyz);

    return inScatter.rgb;
}

//-----------------------------------------------------------------------------

vec3 inscatterGroundFix(vec3 lightVec)
{
    const float ca = 0.5 * (float(RES_NU) - 1.0);
    float nu = dot(eyeVec, lightVec);
    tex4Dlerp  = nu * ca + ca;
    tex4Dlerpi = floor(tex4Dlerp);
    tex4Dlerpf = tex4Dlerp - tex4Dlerpi;

    float phaseR = phaseFunctionR(nu);
    float phaseM = phaseFunctionM(nu);
    float EyeMuS  = dot(EyePosM, lightVec) / EyeR;
    float FragMuS = dot(FragPos, lightVec) / FragR;
    vec4  eyeInScatter, fragInScatter;

    // Avoids imprecision problems near horizon by interpolating between two points above and below horizon
    float a = ((EyeMu - HorizonMu) + HorizonFixEps) / (2.0 * HorizonFixEps);

    EyeMu = HorizonMu - HorizonFixEps;
    FragR = sqrt(EyeR * EyeR + eyeVecLength * eyeVecLength + 2.0 * EyeR * eyeVecLength * EyeMu);
    FragMu = (EyeR * EyeMu + eyeVecLength) / FragR;
    eyeInScatter  = texture4D(EyeR,  EyeMu,  EyeMuS);
    fragInScatter = texture4D(FragR, FragMu, FragMuS);
    vec4 inScatterA = max(eyeInScatter - Attenuation.rgbr * fragInScatter, 0.0);

    EyeMu = HorizonMu + HorizonFixEps;
    FragR = sqrt(EyeR * EyeR + eyeVecLength * eyeVecLength + 2.0 * EyeR * eyeVecLength * EyeMu);
    FragMu = (EyeR * EyeMu + eyeVecLength) / FragR;
    eyeInScatter  = texture4D(EyeR,  EyeMu,  EyeMuS);
    fragInScatter = texture4D(FragR, FragMu, FragMuS);
    vec4 inScatterB = max(eyeInScatter - Attenuation.rgbr * fragInScatter, 0.0);

    vec4 inScatter = mix(inScatterA, inScatterB, a);

    // Avoids imprecision problems in Mie scattering when sun is below horizon
    inScatter.w *= smoothstep(0.0, AtmoParams2.y, EyeMuS);

    inScatter.rgb = inScatter.rgb * phaseR + getMie(inScatter) * phaseM;

    // Change resulting inscatter hue and saturation
    inScatter.xyz = rgb2hsl(inScatter.rgb);
    inScatter.x  += AtmoColAdjust.x;
    inScatter.y   = clamp(inScatter.y * AtmoColAdjust.y, 0.0, 1.0);
    inScatter.z  *= AtmoParams1.y;
    inScatter.rgb = hsl2rgb(inScatter.xyz);

    return inScatter.rgb;
}

//-----------------------------------------------------------------------------

bool intersect_sphere(in float radius, in vec3 x, in vec3 v, out float offset, out float max_path_len)
{
    offset = 0.0;
    max_path_len = 0.0;
    vec3 l = -x;       // vector from ray origin to center of the sphere
    float l2 = dot(x, x);
    float s = dot(l, v);
    float r2 = radius * radius; // adjust top atmosphere boundary by small epsilon to prevent artifacts!!
    if (l2 <= r2)
    {
        float m2 = l2 - s*s;// ray origin inside sphere, hit is ensured
        float q = sqrt(r2-m2);
        max_path_len = s+q;
        return true;
    }
    else if (s >= 0.0)
    { // ray starts outside in front of sphere, hit is possible
        float m2 = l2 - s*s;
        if (m2 <= r2)
        {
            float q = sqrt(r2-m2); // ray hits atmosphere definitely
            offset = s-q;
            max_path_len = (s+q)-offset;
            return true;
        }
    }
    return false;
}

//-----------------------------------------------------------------------------

void compute_layered_fog(in vec2 fog_layer_min_max, in vec3 x_, in vec3 v_, in float t_, out float path_len, out float to_bounadry_len) // mu = angle between eye_radius vector and view vector (dot)
{
    vec3 x = x_; ///TODO: optimize this crazy shit! tip: could be optimizied, because our t is always > 0, for infinity its > 9999999
    vec3 v = v_;

    float t = t_;

    float offset_bot, max_path_bot;
    bool intersects_bot = intersect_sphere(fog_layer_min_max.x, x, v, offset_bot, max_path_bot);
    float offset_top, max_path_top;
    bool intersects_top = intersect_sphere(fog_layer_min_max.y, x, v, offset_top, max_path_top);

    to_bounadry_len = offset_top;
    // S1 - outer sphere, S2 - inner sphere
    if (intersects_top)
    {
        if (offset_top > 0.0)
        { // outside S1
            if ((t < 0.0) || (t >(offset_top+max_path_top)))
            {
                path_len = max_path_top - max_path_bot;
            }
            else if (t < offset_top)
            {
                path_len = 0.0;
            }
            else if (intersects_bot)
            {
                if (t < offset_bot)
                {
                    path_len = t - offset_top;
                }
                else if (t < (offset_bot + max_path_bot))
                {
                    path_len = offset_bot - offset_top;
                }
                else if (t < (offset_top + max_path_top))
                {
                    path_len = (offset_bot - offset_top) + t - offset_bot - max_path_bot;
                }
                else
                {
                    path_len = max_path_top - max_path_bot;
                }
            }
            else if (t > 0.0)
            {
                path_len = t - offset_top;
            }
            else
            {
                path_len = 0.0;
            }
        }
        else if (intersects_bot)
        { // inside S1, intersecting S2
            if (offset_bot > 0.0)
            { // outside S2
                if ((t > 0.0) && t < offset_bot)
                {
                    path_len = t;
                }
                else if ((t > 0.0) && t < (offset_bot + max_path_bot))
                {
                    path_len = offset_bot;
                }
                else if ((t > 0.0) && t < max_path_top)
                {
                    path_len = offset_bot + t - (offset_bot + max_path_bot);
                }
                else
                {
                    path_len = max_path_top - max_path_bot;
                }
            }
            else
            { // inside S2
                if ((t > 0.0) && (t < max_path_bot))
                {
                    path_len = 0.0;
                }
                else if ((t > 0.0) && (t < max_path_top))
                {
                    path_len = t - max_path_bot;
                }
                else
                {
                    path_len = max_path_top - max_path_bot;
                }
            }
        }
        else
        { // inside S1, S2 is not intersected
            if ((t > 0.0) && t < max_path_top)
            {
                path_len = t;
            }
            else
            {
                path_len = max_path_top;
            }
        }
    }
    else
    {
        path_len = 0.0;
    }
/*
    if (path_len > 0.0)
    {
        float fog_p_uv_noise_scaler = M_4PI;
        float fog_p_uv_noise_time_shift = time*0.15;

        vec3 ft_fog_p = (x+v*(to_bounadry_len))*fog_p_uv_noise_scaler;
        vec3 bt_fog_p = (x+v*(to_bounadry_len+path_len))*fog_p_uv_noise_scaler;
        vec3 n_ft_fog_p = normalize(ft_fog_p);
        vec3 n_bt_fog_p = normalize(bt_fog_p);
        ft_fog_p += fog_p_uv_noise_time_shift;
        bt_fog_p += fog_p_uv_noise_time_shift;

        vec3 ft_weights = n_ft_fog_p*n_ft_fog_p/dot(n_ft_fog_p, n_ft_fog_p);
        vec3 bt_weights = n_bt_fog_p*n_bt_fog_p/dot(n_bt_fog_p, n_bt_fog_p);
        vec3 weights = (ft_weights+bt_weights)*0.5;
        vec2 n1 =   texture(noisemap, ft_fog_p.xy).xy; +2.0*texture(noisemap, ft_fog_p.xy*0.01).xy +
            texture(noisemap, bt_fog_p.xy).yx; +2.0*texture(noisemap, bt_fog_p.xy*0.01).yx;
        vec2 n2 =   texture(noisemap, ft_fog_p.yz).xy; +2.0*texture(noisemap, ft_fog_p.yz*0.01).xy +
            texture(noisemap, bt_fog_p.yz).yx; +2.0*texture(noisemap, bt_fog_p.yz*0.01).yx;
        vec2 n3 =   texture(noisemap, ft_fog_p.zx).xy; +2.0*texture(noisemap, ft_fog_p.zx*0.01).xy +
            texture(noisemap, bt_fog_p.zx).yx; +2.0*texture(noisemap, bt_fog_p.zx*0.01).yx;
        float k = 1.0;
        for (int i = 0; i < 4; i++)
        {
            k *= 0.75;
            ft_fog_p *= k;
            bt_fog_p *= k;
            n1 += k*(texture(noisemap, ft_fog_p.xy).xy + texture(noisemap, bt_fog_p.xy).yx);
            n2 += k*(texture(noisemap, ft_fog_p.yz).xy + texture(noisemap, bt_fog_p.yz).yx);
            n3 += k*(texture(noisemap, ft_fog_p.zx).xy + texture(noisemap, bt_fog_p.zx).yx);
        }

        vec2 u3 = vec2(0.5);
        float fog_noise = dot(n1*weights.x + n2*weights.y + n3*weights.z, u3);
        path_len = max(0.0, path_len*(1.0-0.1*(2.0*fog_noise-1.0)));
    }
*/
}

//-----------------------------------------------------------------------------
// Lorenz-Mie hazy phase function
float ae_phase_function_lmh(float mu)
{
    return 0.25 * pi * (0.5 + 4.5 * pow((1.0 + mu) * 0.5, 8.0));
}

//-----------------------------------------------------------------------------

// Lorenz-Mie hazy murky function
float ae_phase_function_lmm(float mu)
{
    return 0.25 * pi * (0.5 + 16.5 * pow((1.0 + mu) * 0.5, 32.0));
}

//-----------------------------------------------------------------------------

vec3 inscatterGroundFog(vec3 lightVec, float fog_path_len, float fog_to_boundary_len)
{
    const float ca = 0.5 * (float(RES_NU) - 1.0);
    float nu = dot(eyeVec, lightVec);
    tex4Dlerp  = nu * ca + ca;
    tex4Dlerpi = floor(tex4Dlerp);
    tex4Dlerpf = tex4Dlerp - tex4Dlerpi;

    float phaseR = phaseFunctionR(nu);
    float EyeMuS  = dot(EyePosM, lightVec) / EyeR;
    vec4  eyeInScatter  = texture4D(EyeR, EyeMu,  EyeMuS);

    float phaseM = phaseFunctionM(nu);
    float FragMuS = dot(FragPos, lightVec) / FragR;
    vec4  fragInScatter = texture4D(FragR, FragMu, FragMuS);

    vec4  inScatter = max(eyeInScatter - Attenuation.rgbr * fragInScatter, 0.0);

    // Avoids imprecision problems in Mie scattering when sun is below horizon
    float mieFade = smoothstep(0.0, AtmoParams2.y, EyeMuS);

    // account for fog-layer inscattering, mie only
    float phaseLMH = ae_phase_function_lmm(nu);
    float fog_transmittance = exp(-2.4 * fog_path_len);
    vec3  x1 = EyePosM + eyeVec * fog_to_boundary_len;
    float x1r = length(x1);
    float x1mus = dot(x1, lightVec) / length(x1);

    float r1 = x1r;
    float mus1 = x1mus;

    vec3 sunLight = transmittance(r1, mus1);
    vec3 groundSkyLight = irradiance(r1, mus1) * AtmoParams1.z;
    vec3 fog_inscatter = vec3(1.0) /*(sunLight + groundSkyLight) / pi*/ * (1.0 - fog_transmittance) * phaseLMH;
    if (fog_path_len > 0)
    {
        float mu_fog_pos = dot(x1, eyeVec) / x1r;
	    vec4 inscatter_fog_surface = texture4D(x1r, mu_fog_pos, x1mus);
        vec3 fog_sky_attenuation = transmittanceAnalytic(EyeR, EyeMu, fog_to_boundary_len);
        vec4 fog_inscatter_rm = max(inScatter - fog_sky_attenuation.xyzx * inscatter_fog_surface, 0.0);
        fog_inscatter_rm.w *= mieFade;
        fog_inscatter += fog_inscatter_rm.xyz * phaseR  + getMie(fog_inscatter_rm) * phaseM;
    }

    inScatter.a *= mieFade;
    inScatter.rgb = inScatter.rgb * phaseR + getMie(inScatter) * phaseM;

    inScatter.rgb = mix(fog_inscatter, inScatter.rgb, fog_transmittance);

    // Change resulting inscatter hue and saturation
    inScatter.xyz = rgb2hsl(inScatter.rgb);
    inScatter.x  += AtmoColAdjust.x;
    inScatter.y   = clamp(inScatter.y * AtmoColAdjust.y, 0.0, 1.0);
    inScatter.z  *= AtmoParams1.y;
    inScatter.rgb = hsl2rgb(inScatter.xyz);

    return inScatter.rgb;
}

//-----------------------------------------------------------------------------

#endif
