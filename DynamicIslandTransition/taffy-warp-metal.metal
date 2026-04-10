#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Inverse distortion for SwiftUI `distortionEffect`: returns **source** pixel (user space) for each **destination** pixel.
/// Progressive horizontal pinch: island width at the top, full card width at the bottom via a power curve on vertical position.
/// Wobble uses sine waves with envelope `p*(1-p)` (strongest mid-gesture). `progress` may go slightly below 0 during release overshoot.
[[ stitchable ]] float2 taffyWarp(float2 position, float4 bounds, float progress, float time, float pinchIntensity, float wobbleAmplitude, float wobbleFrequency, float verticalSuction) {
    float minX = bounds.x;
    float minY = bounds.y;
    float w = max(bounds.z, 1.0f);
    float h = max(bounds.w, 1.0f);

    float pIn = progress;
    float pMain = saturate(pIn);
    float pinchK = max(pinchIntensity, 0.05f);
    float wobbleK = max(wobbleAmplitude, 0.0f);
    float wobbleF = max(wobbleFrequency, 0.05f);
    float vertK = max(verticalSuction, 0.01f);

    float xn = (position.x - minX) / w;
    float yn = (position.y - minY) / h;

    // Teardrop weight: tight at top (yn=0), loose at bottom. Power curve so the tail trails naturally.
    constexpr float pinchCurvePower = 2.15f;
    float verticalPinchWeight = pow(saturate(1.0f - yn), pinchCurvePower);

    // Top rows follow suction quickly; bottom rows trail (taffy tail).
    float tailLag = pow(saturate(yn), 0.92f);
    float phaseTop = smoothstep(0.0f, 0.32f, pMain);
    float phaseBot = smoothstep(0.06f, 0.96f, pMain);
    float rowPhase = mix(phaseTop, phaseBot, tailLag);

    constexpr float islandRatio = 126.0f / 260.0f;
    float pinchBlend = saturate(rowPhase * pinchK * verticalPinchWeight);
    float pinchAmt = mix(1.0f, islandRatio, pinchBlend);

    float xc = 0.5f;
    float xSrc = xc + (xn - xc) / max(pinchAmt, 0.06f);

    // Sine wobble, strongest mid-animation (fade at start and end of 0…1).
    float wobbleEnvelope = 4.0f * pMain * (1.0f - pMain);
    wobbleEnvelope = max(wobbleEnvelope, 0.0f);
    float tailWobbleWeight = mix(0.35f, 1.0f, tailLag);
    float horizWobble = 0.032f * wobbleK * wobbleEnvelope * tailWobbleWeight * sin(time * (0.55f * wobbleF) + yn * 18.0f);
    xSrc += horizWobble;
    xSrc = saturate(xSrc);

    float vertDrive = saturate(pow(rowPhase, 0.78f) * vertK);
    float ynCompressed = yn * mix(1.0f, 0.11f + 0.22f * yn, vertDrive);
    float taper = (1.0f - vertDrive) * tailLag * 0.065f * sin(pMain * 3.14159265f);
    float vertWobble = 0.024f * wobbleK * wobbleEnvelope * tailWobbleWeight * cos(time * (0.42f * wobbleF) + yn * 14.0f);
    float ySrc = saturate(ynCompressed + taper + vertWobble);

    float2 samplePos = float2(minX + xSrc * w, minY + ySrc * h);

    // Release overshoot: brief horizontal bulge when progress dips slightly below 0.
    float neg = saturate(-pIn * 6.0f);
    if (neg > 1e-3f) {
        float bulge = 1.0f + 0.11f * neg;
        float2 bulgePos = float2(minX + (xc + (xn - xc) * bulge) * w, minY + yn * h);
        samplePos = mix(samplePos, bulgePos, neg * (1.0f - pMain));
    }

    float warpBlend = smoothstep(0.0f, 0.045f, abs(pIn));
    if (pIn < 0.0f) {
        warpBlend = max(warpBlend, neg * 0.85f);
    }
    return mix(position, samplePos, warpBlend);
}
