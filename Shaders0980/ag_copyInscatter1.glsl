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

// copies deltaS into S (line 5 in algorithm 4.1)

#include "ag_common.glsl"

uniform float r;
uniform vec4 dhdH;
uniform int layer;

uniform sampler3D deltaSRSampler;
uniform sampler3D deltaSMSampler;

#ifdef _GEOMETRY_
#extension GL_EXT_geometry_shader4 : enable

layout (triangles) in;
layout (triangle_strip, max_vertices = 4) out;

void main()
{
    gl_Position = gl_PositionIn[0];
    gl_Layer = layer;
    EmitVertex();
    gl_Position = gl_PositionIn[1];
    gl_Layer = layer;
    EmitVertex();
    gl_Position = gl_PositionIn[2];
    gl_Layer = layer;
    EmitVertex();
    EndPrimitive();
}

#endif

#ifdef _FRAGMENT_

layout(location = 0) out vec4  OutColor;

void main()
{
    vec3 uvw = vec3(gl_FragCoord.xy, float(layer) + 0.5) / vec3(ivec3(RES_MU_S * RES_NU, RES_MU, RES_R));
    vec4 ray = texture(deltaSRSampler, uvw);
    vec4 mie = texture(deltaSMSampler, uvw);
    OutColor = vec4(ray.rgb, mie.r); // store only red component of single Mie scattering (cf. "Angular precision")
}

#endif
