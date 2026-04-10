#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Inverse distortion for SwiftUI `distortionEffect`: returns **source** pixel (user space) for each **destination** pixel.
/// `position` / return value share the same coordinate space as `bounds` (x, y, width, height).
/// Uses `progress` (0…1) plus five UI uniforms: pinchIntensity, wobbleAmplitude, wobbleFrequency, verticalSuction, and `time`.
[[ stitchable ]] float2 taffyWarp(float2 position, float4 bounds, float progress, float time, float pinchIntensity, float wobbleAmplitude, float wobbleFrequency, float verticalSuction) {
    float minX = bounds.x;
    float minY = bounds.y;
    float w = max(bounds.z, 1.0f);
    float h = max(bounds.w, 1.0f);

    float p = clamp(progress, 0.0f, 1.0f);
    float pinchK = max(pinchIntensity, 0.05f);
    float wobbleK = max(wobbleAmplitude, 0.0f);
    float wobbleF = max(wobbleFrequency, 0.05f);
    float vertK = max(verticalSuction, 0.01f);

    // Normalized: x left→right, y top→bottom of the layer.
    float xn = (position.x - minX) / w;
    float yn = (position.y - minY) / h;

    // Top (yn≈0) leads toward the island; bottom (yn≈1) trails with delay — genie tail.
    float tailWeight = pow(saturate(yn), 0.9f);
    float phaseTop = smoothstep(0.0f, 0.4f, p);
    float phaseBot = smoothstep(0.08f, 0.98f, p);
    float rowPhase = mix(phaseTop, phaseBot, tailWeight);

    // Horizontal pinch toward center: stronger at top edge (portal), weaker at bottom.
    constexpr float islandRatio = 126.0f / 260.0f;
    float pinchStrength = saturate(rowPhase * pinchK);
    float pinchTop = mix(1.0f, islandRatio, pinchStrength);
    float pinchBot = mix(1.0f, mix(1.0f, islandRatio, 0.58f), pinchStrength);
    float pinchAmt = mix(pinchTop, pinchBot, smoothstep(0.0f, 1.0f, yn));

    float xc = 0.5f;
    float xSrc = xc + (xn - xc) / max(pinchAmt, 0.06f);

    // Trailing wobble: mostly bottom, strongest mid-animation; scales with wobbleAmplitude & wobbleFrequency.
    float wobbleEnvelope = p * (1.0f - p);
    float horizWobble = 0.028f * wobbleK * wobbleEnvelope * tailWeight * sin(time * (0.5f * wobbleF) + yn * 17.0f);
    xSrc += horizWobble;
    xSrc = saturate(xSrc);

    // Vertical suction: compress sampling toward the top (content appears stretched up toward Dynamic Island).
    float vertDrive = saturate(pow(rowPhase, 0.82f) * vertK);
    float ynCompressed = yn * mix(1.0f, 0.12f + 0.2f * yn, vertDrive);
    float taper = (1.0f - vertDrive) * tailWeight * 0.07f * sin(p * 3.14159265f);
    float vertWobble = 0.022f * wobbleK * wobbleEnvelope * tailWeight * cos(time * (0.4f * wobbleF) + yn * 13.0f);
    float ySrc = saturate(ynCompressed + taper + vertWobble);

    float2 samplePos = float2(minX + xSrc * w, minY + ySrc * h);

    // Smooth blend to identity at p≈0 so the card is perfectly flat at rest.
    float warpBlend = smoothstep(0.0f, 0.04f, p);
    return mix(position, samplePos, warpBlend);
}
