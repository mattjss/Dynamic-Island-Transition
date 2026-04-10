import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var progress: CGFloat = 0
    @State private var suckedIn = false
    @State private var islandBump = false

    // Control panel (bound to shader + animation)
    @State private var animationDuration: Double = 0.6
    @State private var pinchIntensity: Double = 0.85
    @State private var wobbleAmplitude: Double = 0.3
    @State private var wobbleFrequency: Double = 12
    @State private var verticalSuctionProgress: Double = 0.75
    @State private var showDebugPanel = true

    private let cardCornerRadius: CGFloat = 10
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
            let controlPanelHeight = min(geo.size.height * 0.5, 540)

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
                                WarpedCardImage(
                                    progress: progress,
                                    time: time,
                                    pinchIntensity: pinchIntensity,
                                    wobbleAmplitude: wobbleAmplitude,
                                    wobbleFrequency: wobbleFrequency,
                                    verticalSuctionProgress: verticalSuctionProgress
                                )
                                .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                                .onTapGesture(perform: toggleWarpAnimation)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Group {
                    if showDebugPanel {
                        ScrollView {
                            controlPanelContent
                                .padding(.bottom, 80 + geo.safeAreaInsets.bottom)
                        }
                        .scrollIndicators(.visible)
                    } else {
                        Button("Show tuning") { showDebugPanel = true }
                            .font(.caption)
                            .padding(.vertical, 12)
                    }
                }
                .frame(maxWidth: .infinity, height: showDebugPanel ? controlPanelHeight : 52, alignment: .bottom)
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

    private func toggleWarpAnimation() {
        suckedIn.toggle()
        withAnimation(.spring(response: animationDuration, dampingFraction: 0.82)) {
            progress = suckedIn ? 1 : 0
        }
    }

    private var controlPanelContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Control Panel")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Hide") { showDebugPanel = false }
                    .font(.caption)
            }
            sliderRow("Animation duration", value: $animationDuration, range: 0.28 ... 1.4)
            sliderRow("Pinch intensity", value: $pinchIntensity, range: 0.2 ... 2.2)
            sliderRow("Wobble amplitude", value: $wobbleAmplitude, range: 0 ... 3)
            sliderRow("Wobble frequency", value: $wobbleFrequency, range: 0.2 ... 24)
            sliderRow("Vertical suction", value: $verticalSuctionProgress, range: 0.15 ... 2.2)
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
    private let cardStrokeWidth: CGFloat = 2
    private let cardStrokeColor = Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)

    var body: some View {
        let p = min(max(progress, 0), 1)
        let cardShape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
        let shader = Shader(
            function: ShaderFunction(library: .default, name: "taffyWarp"),
            arguments: [
                .boundingRect,
                .float(Double(p)),
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
                maxSampleOffset: CGSize(width: 320, height: 640),
                isEnabled: true
            )
            .clipShape(cardShape)
            .frame(width: cardW, height: cardH)
            .overlay {
                cardShape.strokeBorder(cardStrokeColor, lineWidth: cardStrokeWidth)
            }
    }
}

#Preview {
    ContentView()
}
