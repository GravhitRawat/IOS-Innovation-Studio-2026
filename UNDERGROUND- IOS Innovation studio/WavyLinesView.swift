import SwiftUI

struct WavyLinesView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                drawWaves(context: context, size: size, time: time)
            }
        }
    }

    func drawWaves(context: GraphicsContext, size: CGSize, time: Double) {
        let lineCount = 18
        let lineSpacing = size.height / Double(lineCount + 1)

        let amplitudes: [Double] = [8, 11, 7, 13, 9, 12, 6, 10, 14, 8, 11, 7, 13, 9, 12, 6, 10, 14]
        let frequencies: [Double] = [2.1, 2.8, 1.9, 3.1, 2.4, 2.7, 2.0, 3.0, 1.8, 2.3, 2.9, 2.2, 2.6, 1.9, 3.2, 2.5, 2.1, 2.8]
        let speeds: [Double] = [0.4, 0.6, 0.35, 0.55, 0.45, 0.65, 0.38, 0.5, 0.42, 0.6, 0.36, 0.52, 0.48, 0.4, 0.62, 0.44, 0.58, 0.46]
        let opacities: [Double] = [0.07, 0.05, 0.11, 0.06, 0.09, 0.05, 0.12, 0.07, 0.08, 0.06, 0.10, 0.05, 0.09, 0.07, 0.06, 0.11, 0.08, 0.05]
        let phaseOffsets: [Double] = [0.0, 0.4, 0.8, 1.2, 1.6, 2.0, 2.4, 2.8, 3.2, 3.6, 4.0, 4.4, 4.8, 5.2, 5.6, 6.0, 0.2, 0.6]

        for i in 0..<lineCount {
            let baseY = lineSpacing * Double(i + 1)
            var path = Path()
            let steps = Int(size.width / 2)

            for step in 0...steps {
                let x = Double(step) * 2.0
                let normalised = x / size.width
                let y = baseY + amplitudes[i] * sin(
                    (normalised * frequencies[i] * .pi * 2) + (time * speeds[i]) + phaseOffsets[i]
                )

                if step == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(
                path,
                with: .color(Color(white: 1.0, opacity: opacities[i])),
                lineWidth: 0.6
            )
        }
    }
}
