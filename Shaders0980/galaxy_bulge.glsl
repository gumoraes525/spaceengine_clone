#version 330 core
#auto_defines

uniform sampler2D PrecomputedDensityFunc;
uniform mat4x4    Mvp;
uniform vec3      EyePos;
uniform vec4      BulgeColor;
uniform vec3      Reddening;

#ifdef _VERTEX_

layout(location = 0) in  vec3  VertexPos;
layout(location = 1) in  vec2  TexCoord;
layout(location = 2) in  vec3  Tangent;

out vec3  vPosition;

void main()
{
    gl_Position = Mvp * vec4(VertexPos, 1.0);
    vPosition = VertexPos;
}

#else

in vec3  vPosition;

layout(location = 0) out vec4 FragColor;

void main()
{
    // Calculate the parameters of the density function
    vec3   vertPos = normalize(vPosition);
    vec3   ray     = EyePos + vertPos;              // the ray from the pixel to the eye
    float  rlen    = length(ray) + 1.0e-6;          // to avoid division by zero
    float  depth   = dot(vertPos, ray/rlen);        // half length of the part of the galaxy along the ray
    float  offset  = pow(1.0 - depth*depth, 0.125); // the ray's offset from the galaxy's center
    depth = min(depth, 0.5*rlen);                   // cut the half length if the eye is inside the galaxy
    //float  fade = smoothstep(0.0, 0.5, dot(vPosition, EyePos));

    // Now get the visible brightness of the pixel
    float density = texture(PrecomputedDensityFunc, vec2(offset, depth)).r;

    // Calculate the final color
    FragColor = density * BulgeColor;
    FragColor.rgb = clamp(FragColor.rgb * Reddening, 0.0, 1.0);
}

#endif
