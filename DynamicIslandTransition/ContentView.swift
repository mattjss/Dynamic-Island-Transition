import SwiftUI

struct ContentView: View {
    @State private var progress: CGFloat = 0
    @State private var suckedIn = false
    @State private var islandBump = false

    /// Softer damping + interpolating spring for a slight elastic overshoot (genie / vacuum tail).
    private let travelSpring = Animation.interpolatingSpring(stiffness: 210, damping: 19)
    private let cardW: CGFloat = 260
    private let cardH: CGFloat = 260
    /// Max vertical lift; eased so motion tightens mid-suck to match shader suction.
    private let liftPerProgress: CGFloat = 410
    private let islandBaseW: CGFloat = 126
    private let islandBaseH: CGFloat = 37

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: geo.size.height * 0.44)
                    HStack {
                        Spacer(minLength: 0)
                        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
                            let time = context.date.timeIntervalSinceReferenceDate
                            Image("CardPhoto")
                                .resizable()
                                .scaledToFill()
                                .frame(width: cardW, height: cardH)
                                .clipped()
                                .distortionEffect(
                                    Shader(
                                        function: ShaderFunction(library: .default, name: "taffyWarp"),
                                        arguments: [
                                            .boundingRect,
                                            .float(Double(progress)),
                                            .float(time),
                                        ]
                                    ),
                                    maxSampleOffset: CGSize(width: 220, height: 520),
                                    isEnabled: true
                                )
                                .offset(y: -liftOffset(progress: progress))
                                .opacity(progress >= 0.998 ? 0 : 1)
                        }
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

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
        }
        .contentShape(Rectangle())
        .onTapGesture {
            suckedIn.toggle()
            withAnimation(travelSpring) {
                progress = suckedIn ? 1 : 0
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            if suckedIn, newValue >= 0.85, oldValue < 0.85 {
                playIslandBump()
            }
        }
    }

    /// Ease-in-out cubic: slow start, strong mid pull, settle — matches portal suction timing.
    private func liftOffset(progress: CGFloat) -> CGFloat {
        let p = Double(progress)
        let t: Double
        if p < 0.5 {
            t = 4 * p * p * p
        } else {
            let u = -2 * p + 2
            t = 1 - u * u * u / 2
        }
        return CGFloat(t) * liftPerProgress
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
