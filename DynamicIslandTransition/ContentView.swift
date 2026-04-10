import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var progress: CGFloat = 0
    @State private var suckedIn = false
    @State private var islandBump = false
    @State private var islandPreRelease = false
    @State private var didPlayBump = false

    /// Suction phase duration (spring response ≈ perceived length), ~0.35–0.4s snappy.
    @State private var animationDuration: Double = 0.37
    @State private var pinchIntensity: Double = 0.95
    @State private var wobbleAmplitude: Double = 0.32
    @State private var wobbleFrequency: Double = 11
    /// Scales vertical suction in the shader and upward translation of the card.
    @State private var verticalSuctionProgress: Double = 0.92
    @State private var showDebugPanel = true

    private let cardCornerRadius: CGFloat = 10
    private let islandBaseW: CGFloat = 126
    private let islandBaseH: CGFloat = 37

    private var releaseSpringResponse: Double {
        max(0.45, animationDuration * 1.38)
    }

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
            let panelMaxHeight = min(geo.size.height * 0.5, 520)
            let bottomInset = geo.safeAreaInsets.bottom

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    canvasBackground
                        .ignoresSafeArea(edges: [.top, .leading, .trailing])

                    Capsule()
                        .fill(Color.black)
                        .frame(width: islandDisplayWidth, height: islandDisplayHeight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .offset(y: 11)
                        .ignoresSafeArea(edges: .top)
                        .contentShape(Capsule())
                        .allowsHitTesting(suckedIn)
                        .onTapGesture(perform: spitOut)

                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: max(geo.safeAreaInsets.top + 52, 56))
                        HStack {
                            Spacer(minLength: 0)
                            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
                                let time = context.date.timeIntervalSinceReferenceDate
                                let liftP = min(max(progress, 0), 1)
                                let lift = CGFloat(verticalSuctionProgress) * 108 * liftP
                                WarpedCardImage(
                                    progress: progress,
                                    time: time,
                                    pinchIntensity: pinchIntensity,
                                    wobbleAmplitude: wobbleAmplitude,
                                    wobbleFrequency: wobbleFrequency,
                                    verticalSuctionProgress: verticalSuctionProgress
                                )
                                .offset(y: -lift)
                                .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                                .onTapGesture(perform: startSuckIn)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .layoutPriority(1)

                Group {
                    if showDebugPanel {
                        ScrollView {
                            controlPanelContent
                                .padding(.bottom, 16 + bottomInset)
                        }
                        .frame(maxHeight: panelMaxHeight)
                        .scrollIndicators(.visible)
                        .scrollBounceBehavior(.basedOnSize)
                    } else {
                        Button("Show tuning") { showDebugPanel = true }
                            .font(.caption)
                            .padding(.vertical, 12)
                            .padding(.bottom, bottomInset)
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
        .onChange(of: suckedIn) { _, newValue in
            if newValue { didPlayBump = false }
        }
        .onChange(of: progress) { oldValue, newValue in
            guard suckedIn, !didPlayBump, newValue >= 0.99 else { return }
            if oldValue < 0.99 {
                didPlayBump = true
                playIslandBump()
            }
        }
    }

    private var islandDisplayWidth: CGFloat {
        if islandPreRelease { return islandBaseW + 5 }
        if islandBump { return islandBaseW + 8 }
        return islandBaseW
    }

    private var islandDisplayHeight: CGFloat {
        if islandPreRelease { return islandBaseH + 2 }
        if islandBump { return islandBaseH + 4 }
        return islandBaseH
    }

    private func startSuckIn() {
        guard !suckedIn else { return }
        suckedIn = true
        withAnimation(.spring(response: animationDuration, dampingFraction: 0.72)) {
            progress = 1
        }
    }

    private func spitOut() {
        guard suckedIn else { return }
        withAnimation(.spring(response: 0.12, dampingFraction: 0.68)) {
            islandPreRelease = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            suckedIn = false
            withAnimation(.spring(response: releaseSpringResponse, dampingFraction: 0.58)) {
                progress = 0
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                islandPreRelease = false
            }
        }
    }

    private var controlPanelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Control Panel")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Hide") { showDebugPanel = false }
                    .font(.caption)
            }
            Toggle("Show debug panel", isOn: $showDebugPanel)
                .font(.subheadline)
            sliderRow("Suction duration (s)", value: $animationDuration, range: 0.25 ... 0.5)
            sliderRow("Pinch intensity", value: $pinchIntensity, range: 0.35 ... 1.6)
            sliderRow("Wobble amplitude", value: $wobbleAmplitude, range: 0 ... 1.2)
            sliderRow("Wobble frequency", value: $wobbleFrequency, range: 4 ... 22)
            sliderRow("Vertical suction speed", value: $verticalSuctionProgress, range: 0.35 ... 1.35)
            Text("Release uses a slower spring (~\(String(format: "%.2f", releaseSpringResponse))s) with bounce.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
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

    /// After the card is eaten: expand +8×+4pt, then spring back over ~0.3s.
    private func playIslandBump() {
        withAnimation(.spring(response: 0.12, dampingFraction: 0.75)) {
            islandBump = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                islandBump = false
            }
        }
    }
}

/// Isolates warp progress as `Animatable` so `distortionEffect` receives spring-interpolated values every frame.
@MainActor
private struct WarpedCardImage: View, Animatable {
    var progress: CGFloat
    var time: Double
    var pinchIntensity: Double
    var wobbleAmplitude: Double
    var wobbleFrequency: Double
    var verticalSuctionProgress: Double

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private let cardW: CGFloat = 260
    private let cardH: CGFloat = 260
    private let cardCornerRadius: CGFloat = 10

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
        let shader = Shader(
            function: ShaderFunction(library: .default, name: "taffyWarp"),
            arguments: [
                .boundingRect,
                .float(Double(progress)),
                .float(time),
                .float(pinchIntensity),
                .float(wobbleAmplitude),
                .float(wobbleFrequency),
                .float(verticalSuctionProgress),
            ]
        )
        Image("CardPhoto")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: cardW, height: cardH)
            .clipped()
            .clipShape(cardShape)
            .distortionEffect(
                shader,
                maxSampleOffset: CGSize(width: 360, height: 720),
                isEnabled: true
            )
            .clipShape(cardShape)
            .frame(width: cardW, height: cardH)
    }
}

#Preview {
    ContentView()
}
