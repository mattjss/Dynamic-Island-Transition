import SwiftUI

struct ContentView: View {
    @State private var progress: CGFloat = 0
    @State private var suckedIn = false
    @State private var islandBump = false
    @State private var islandPreRelease = false
    @State private var didPlayBump = false
    @State private var showTuningSheet = false

    @State private var duration: Double = 0.37
    @State private var squeezeStrength: Double = 0.95
    @State private var squeezeZone: Double = 0.55
    @State private var cardHeight: Double = 260
    @State private var cardWidth: Double = 260

    private let cardCornerRadius: CGFloat = 10
    private let islandBaseW: CGFloat = 126
    private let islandBaseH: CGFloat = 37

    private var releaseSpringResponse: Double {
        max(0.55, duration * 1.75)
    }

    private var releaseDamping: Double {
        0.52
    }

    private var islandScale: CGFloat {
        if islandPreRelease { return 1.06 }
        if islandBump { return 1.14 }
        return 1.0
    }

    var body: some View {
        GeometryReader { geo in
            let islandCenterY = geo.safeAreaInsets.top + 11 + islandBaseH * 0.5
            let screenCenterY = geo.size.height * 0.5
            let travelToIsland = screenCenterY - islandCenterY

            ZStack {
                Color.white
                    .ignoresSafeArea()

                Capsule()
                    .fill(Color.black)
                    .frame(width: islandBaseW, height: islandBaseH)
                    .scaleEffect(islandScale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .offset(y: 11)
                    .ignoresSafeArea(edges: .top)
                    .contentShape(Capsule())
                    .allowsHitTesting(suckedIn)
                    .onTapGesture(perform: spitOut)

                WarpedCardImage(
                    progress: progress,
                    squeezeStrength: squeezeStrength,
                    squeezeZone: squeezeZone,
                    islandWidthRatio: islandBaseW / CGFloat(cardWidth),
                    cardWidth: CGFloat(cardWidth),
                    cardHeight: CGFloat(cardHeight),
                    cardCornerRadius: cardCornerRadius
                )
                .offset(y: -travelToIsland * progress)
                .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                .onTapGesture(perform: startSuckIn)

                VStack {
                    Spacer()
                    Button {
                        showTuningSheet = true
                    } label: {
                        Capsule()
                            .fill(Color.gray.opacity(0.22))
                            .frame(width: 44, height: 5)
                    }
                    .accessibilityLabel("Show tuning")
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 20))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.white)
        .sheet(isPresented: $showTuningSheet) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Squeeze Strength")
                        Slider(value: $squeezeStrength, in: 0.35 ... 1.6)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Squeeze Zone")
                        Slider(value: $squeezeZone, in: 0.12 ... 1.0)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration")
                        Slider(value: $duration, in: 0.22 ... 0.65)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Height")
                        Slider(value: $cardHeight, in: 160 ... 340)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Width")
                        Slider(value: $cardWidth, in: 160 ... 340)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: suckedIn) { _, newValue in
            if newValue { didPlayBump = false }
        }
        .onChange(of: progress) { oldValue, newValue in
            guard suckedIn, !didPlayBump, newValue >= 1 else { return }
            if oldValue < 1 {
                didPlayBump = true
                playIslandBump()
            }
        }
    }

    private func startSuckIn() {
        guard !suckedIn else { return }
        suckedIn = true
        withAnimation(.spring(response: duration, dampingFraction: 0.72)) {
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
            withAnimation(.spring(response: releaseSpringResponse, dampingFraction: releaseDamping)) {
                progress = 0
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                islandPreRelease = false
            }
        }
    }

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
    var squeezeStrength: Double
    var squeezeZone: Double
    var islandWidthRatio: CGFloat
    var cardWidth: CGFloat
    var cardHeight: CGFloat
    var cardCornerRadius: CGFloat

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
        let shader = Shader(
            function: ShaderFunction(library: .default, name: "taffyWarp"),
            arguments: [
                .boundingRect,
                .float(Double(progress)),
                .float(squeezeStrength),
                .float(squeezeZone),
                .float(Double(islandWidthRatio)),
            ]
        )
        Image("CardPhoto")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: cardWidth, height: cardHeight)
            .clipped()
            .clipShape(cardShape)
            .distortionEffect(
                shader,
                maxSampleOffset: CGSize(width: 420, height: 840),
                isEnabled: true
            )
            .clipShape(cardShape)
            .frame(width: cardWidth, height: cardHeight)
    }
}

#Preview {
    ContentView()
}
