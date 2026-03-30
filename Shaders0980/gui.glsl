#version 330 core
#auto_defines

uniform sampler2D   AtlasTexture;
uniform vec4        CoordTransf; // vertex coord offset, vertex coord scale
uniform vec2        ClipTransf;  // vertex coord offset, vertex coord scale

#ifdef _VERTEX_

layout(location = 0) in vec2 vPosition;
layout(location = 1) in vec2 vTexCoord;
layout(location = 2) in vec4 vClip;
layout(location = 3) in vec4 vColor;

out vec2 fTexCoord;
out vec4 fClip;
out vec4 fColor;

void main()
{
    gl_Position = vec4(vPosition * CoordTransf.zw + CoordTransf.xy, 0.0, 1.0);
    fTexCoord = vTexCoord;
    fClip  = vClip + ClipTransf.xyxy;
    fColor = vColor;
}

#else

in vec2 fTexCoord;
in vec4 fClip;
in vec4 fColor;
layout(origin_upper_left) in vec4 gl_FragCoord;

layout(location = 0) out vec4 OutColor;

void main()
{
    if (any(bvec2(clamp(gl_FragCoord.xy, fClip.xy, fClip.zw) - gl_FragCoord.xy)))
        discard;
    else
        OutColor = fColor * texture(AtlasTexture, fTexCoord);

    //if (any(bvec2(clamp(gl_FragCoord.xy, fClip.xy, fClip.zw) - gl_FragCoord.xy)))
    //    OutColor.rgb = 1.0 - OutColor.rgb;
}

#endif
