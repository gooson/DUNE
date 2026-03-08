#include <metal_stdlib>
using namespace metal;

[[ stitchable ]] half4 shanksSeaShimmer(
    float2 position,
    half4 color,
    float time,
    float2 size,
    float intensity
) {
    if (size.x <= 0.0 || size.y <= 0.0) {
        return color;
    }

    float2 uv = position / size;
    float ripple = sin((uv.x * 14.0 + time * 0.9) + sin(uv.y * 22.0 - time * 0.4)) * 0.5 + 0.5;
    float sweep = sin((uv.y * 18.0 - time * 0.7) + cos(uv.x * 16.0 + time * 0.6)) * 0.5 + 0.5;
    float glow = pow(clamp(ripple * sweep, 0.0, 1.0), 3.0) * intensity;

    half3 tint = half3(0.46h, 0.92h, 0.96h);
    half3 result = color.rgb + tint * half(glow * 0.32);
    return half4(result, color.a);
}

[[ stitchable ]] half4 shanksKamusariGlow(
    float2 position,
    half4 color,
    float time,
    float2 size,
    float intensity
) {
    if (size.x <= 0.0 || size.y <= 0.0) {
        return color;
    }

    float2 uv = (position / size) * 2.0 - 1.0;
    float radius = length(uv);
    float angle = atan2(uv.y, uv.x);
    float swirl = sin(angle * 7.0 - time * 3.2 + radius * 11.0) * 0.5 + 0.5;
    float corona = pow(clamp(1.0 - radius, 0.0, 1.0), 2.4);
    float arc = pow(clamp(swirl * corona, 0.0, 1.0), 2.0) * intensity;

    half3 warm = half3(1.0h, 0.87h, 0.48h);
    half3 hot = half3(1.0h, 0.32h, 0.36h);
    half mixValue = half(0.5 + 0.5 * sin(time * 2.1 + radius * 8.0));
    half3 tint = mix(warm, hot, mixValue);

    return half4(color.rgb + tint * half(arc * 0.45), color.a);
}

[[ stitchable ]] float2 shanksWaterWarp(
    float2 position,
    float time,
    float2 size,
    float intensity
) {
    if (size.x <= 0.0 || size.y <= 0.0) {
        return position;
    }

    float2 uv = position / size;
    float waveX = sin(uv.y * 18.0 + time * 1.6) * 6.0;
    float waveY = cos(uv.x * 12.0 - time * 1.3) * 3.5;
    float swirl = sin((uv.x + uv.y) * 16.0 - time * 2.0) * 2.0;

    return position + float2((waveX + swirl) * intensity, waveY * intensity);
}
