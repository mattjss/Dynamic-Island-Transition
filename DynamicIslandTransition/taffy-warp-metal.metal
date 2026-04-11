#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Inverse distortion for `distortionEffect`: maps destination → source in user space.
/// Genie teardrop: top pinches toward Dynamic Island width; bottom stays wide and lags.
/// Upward motion is driven from Swift via offset; `progress` is unclamped for spring overshoot.
[[ stitchable ]] float2 taffyWarp(float2 position, float4 bounds, float progress, float squeezeStrength, float squeezeZone, float islandWidthRatio) {
    float minX = bounds.x;
    float minY = bounds.y;
    float w = max(bounds.z, 1.0f);
    float h = max(bounds.w, 1.0f);

    float pIn = progress;
    float strength = max(squeezeStrength, 0.05f);
    float zone = clamp(squeezeZone, 0.08f, 1.0f);

    float xn = (position.x - minX) / w;
    float yn = (position.y - minY) / h;

    // Squeeze zone: fraction of height (from top) that participates in the pinch taper.
    float t = saturate(yn / zone);
    constexpr float pinchCurvePower = 2.15f;
    float verticalPinchWeight = pow(1.0f - t, pinchCurvePower);

    // Lower rows follow suction later (trailing wide base).
    float tailLag = pow(saturate(yn), 0.92f);
    float phaseTop = smoothstep(0.0f, 0.32f, pIn);
    float phaseBot = smoothstep(0.06f, 0.96f, pIn);
    float rowPhase = mix(phaseTop, phaseBot, tailLag);

    // Squeeze strength: how fully we approach island width at full phase (narrower = higher blend).
    float pinchBlend = saturate(rowPhase * strength * verticalPinchWeight);
    float targetRatio = clamp(islandWidthRatio, 0.12f, 0.95f);
    float pinchAmt = mix(1.0f, targetRatio, pinchBlend);

    float xc = 0.5f;
    float xSrc = xc + (xn - xc) / max(pinchAmt, 0.06f);

    // Light vertical compression with suction (funnel), keyed off row phase.
    float vertDrive = pow(max(rowPhase, 0.0f), 0.78f);
    float ynCompressed = yn * mix(1.0f, 0.14f + 0.24f * yn, vertDrive);
    float ySrc = saturate(ynCompressed);

    float2 samplePos = float2(minX + xSrc * w, minY + ySrc * h);

    // Release: slight horizontal bulge when progress undershoots zero.
    float pClamp0 = saturate(pIn);
    float neg = saturate(-pIn * 6.0f);
    if (neg > 1e-3f) {
        float bulge = 1.0f + 0.11f * neg;
        float2 bulgePos = float2(minX + (xc + (xn - xc) * bulge) * w, minY + yn * h);
        samplePos = mix(samplePos, bulgePos, neg * (1.0f - pClamp0));
    }

    float warpBlend = smoothstep(0.0f, 0.045f, abs(pIn));
    if (pIn < 0.0f) {
        warpBlend = max(warpBlend, neg * 0.85f);
    }
    return mix(position, samplePos, warpBlend);
}
