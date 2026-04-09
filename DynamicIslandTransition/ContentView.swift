import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var progress: CGFloat = 0
    @State private var suckedIn = false
    @State private var islandBump = false

    // Debug / tuning (bound to shader + animation)
    @State private var animationDuration: Double = 0.62
    @State private var pinchIntensity: Double = 1.0
    @State private var wobbleAmplitude: Double = 1.0
    @State private var wobbleFrequency: Double = 1.0
    @State private var verticalSuctionProgress: Double = 1.0
    @State private var showDebugPanel = true

    private let cardW: CGFloat = 260
    private let cardH: CGFloat = 260
    private let cardCornerRadius: CGFloat = 10
    private let cardStrokeWidth: CGFloat = 2
    private let cardStrokeColor = Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)
    private let liftPerProgress: CGFloat = 410
    private let islandBaseW: CGFloat = 126
    private let islandBaseH: CGFloat = 37

    private var canvasBackground: Color {
        colorScheme == .dark ? .black : .white
    }

    private var tuningStripBackground: Color {
        colorScheme == .dark
            ? Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
            : Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
    }

    var body: some View {
        GeometryReader { geo in
            let bottomPanelMaxHeight = min(320, geo.size.height * 0.42)

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    canvasBackground
                        .ignoresSafeArea(edges: [.top, .leading, .trailing])

                    Capsule()
                        .fill(Color.black)
                        .frame(
                            width: islandBump ? islandBaseW + 6 : islandBaseW,
                            height: islandBump ? islandBaseH + 3 : islandBaseH
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .offset(y: 11)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)

                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: max(geo.safeAreaInsets.top + 52, 56))
                        HStack {
                            Spacer(minLength: 0)
                            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
                                let time = context.date.timeIntervalSinceReferenceDate
                                let pLinear = clampedProgress(progress)
                                let pShader = shaderMotionProgress(pLinear)
                                cardImageStack(time: time, shaderProgress: pShader)
                                    .offset(y: -liftOffset(progress: pLinear))
                                    .opacity(pLinear >= 0.998 ? 0 : 1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: toggleGenieAnimation)

                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: toggleGenieAnimation)

                Group {
                    if showDebugPanel {
                        ScrollView {
                            debugTuningContent
                        }
                        .frame(maxHeight: bottomPanelMaxHeight)
                    } else {
                        Button("Show tuning") { showDebugPanel = true }
                            .font(.caption)
                            .padding(.vertical, 12)
                    }
                }
                .frame(maxWidth: .infinity)
                .background {
                    tuningStripBackground
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(canvasBackground)
        .onChange(of: progress) { oldValue, newValue in
            if suckedIn, newValue >= 0.85, oldValue < 0.85 {
                playIslandBump()
            }
        }
    }

    private func toggleGenieAnimation() {
        suckedIn.toggle()
        withAnimation(.spring(response: animationDuration, dampingFraction: 0.82)) {
            progress = suckedIn ? 1 : 0
        }
    }

    private var debugTuningContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Genie tuning")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Hide") { showDebugPanel = false }
                    .font(.caption)
            }
            sliderRow("Animation duration", value: $animationDuration, range: 0.28 ... 1.4)
            sliderRow("Pinch intensity", value: $pinchIntensity, range: 0.2 ... 2.2)
            sliderRow("Wobble amplitude", value: $wobbleAmplitude, range: 0 ... 3)
            sliderRow("Wobble frequency", value: $wobbleFrequency, range: 0.2 ... 3)
            sliderRow("Vertical suction", value: $verticalSuctionProgress, range: 0.15 ... 2.2)
        }
        .padding(14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    /// Single animatable 0…1 progress, clamped after spring (no overshoot in the shader).
    private func clampedProgress(_ t: CGFloat) -> CGFloat {
        min(max(t, 0), 1)
    }

    /// Ease-out heavy: slow start, stronger mid stretch, quick final snap into the island.
    private func shaderMotionProgress(_ linear: CGFloat) -> CGFloat {
        let t = Double(clampedProgress(linear))
        // Primary: cubic ease-in-out (slow ends of normalized curve) — then bias late segment toward ease-out snap.
        let cubic: Double
        if t < 0.5 {
            cubic = 4 * t * t * t
        } else {
            let u = -2 * t + 2
            cubic = 1 - u * u * u / 2
        }
        // Blend from cubic to quartic ease-out in the last ~22% so the card seals into the pill cleanly.
        let blendStart = 0.78
        if t <= blendStart {
            return CGFloat(cubic)
        }
        let u = (t - blendStart) / (1 - blendStart)
        let smooth = u * u * (3 - 2 * u)
        let easeOutSnap = 1 - pow(1 - t, 2.8)
        let mixed = cubic * (1 - smooth) + easeOutSnap * smooth
        return CGFloat(min(max(mixed, 0), 1))
    }

    @ViewBuilder
    private func cardImageStack(time: Double, shaderProgress: CGFloat) -> some View {
        let shader = Shader(
            function: ShaderFunction(library: .default, name: "taffyWarp"),
            arguments: [
                .boundingRect,
                .float(Double(shaderProgress)),
                .float(time),
                .float(pinchIntensity),
                .float(wobbleAmplitude),
                .float(wobbleFrequency),
                .float(verticalSuctionProgress),
            ]
        )
        let cardShape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
        Image("CardPhoto")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: cardW, height: cardH)
            .clipped()
            .clipShape(cardShape)
            .distortionEffect(
                shader,
                maxSampleOffset: CGSize(width: 220, height: 520),
                isEnabled: true
            )
            .clipShape(cardShape)
            .frame(width: cardW, height: cardH)
            .overlay {
                cardShape.strokeBorder(cardStrokeColor, lineWidth: cardStrokeWidth)
            }
    }

    /// Matches vertical travel to curved shader progress so lift and warp stay in phase.
    private func liftOffset(progress: CGFloat) -> CGFloat {
        CGFloat(shaderMotionProgress(progress)) * liftPerProgress
    }

    private func playIslandBump() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
            islandBump = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                islandBump = false
            }
        }
    }
}

#Preview {
    ContentView()
}
