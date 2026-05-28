import SwiftUI
import UIKit

struct AstralAnimationView: UIViewRepresentable {
    let style: Int

    func makeUIView(context: Context) -> AstralAnimationContainerView {
        let view = AstralAnimationContainerView(style: style)
        view.clipsToBounds = true
        view.layer.cornerRadius = 20
        return view
    }

    func updateUIView(_ uiView: AstralAnimationContainerView, context: Context) {}

    static func dismantleUIView(_ uiView: AstralAnimationContainerView, coordinator: ()) {
        uiView.pauseAnimation()
    }
}

// MARK: - Container UIView

final class AstralAnimationContainerView: UIView {
    private let styleIndex: Int
    private var gradientLayer = CAGradientLayer()
    private var emitterLayers: [CAEmitterLayer] = []
    private var isPaused = false
    private var layersConfigured = false

    init(style: Int) {
        self.styleIndex = max(0, min(style, 7))
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds

        for emitter in emitterLayers {
            emitter.frame = bounds
            updateEmitterGeometry(emitter)
        }

        if !layersConfigured && bounds.width > 0 && bounds.height > 0 {
            configureStyle()
            layersConfigured = true
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updatePlaybackState()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        updatePlaybackState()
    }

    private func updatePlaybackState() {
        if window != nil, superview != nil {
            resumeAnimation()
        } else {
            pauseAnimation()
        }
    }

    func pauseAnimation() {
        guard !isPaused else { return }
        isPaused = true
        pauseLayer(gradientLayer)
        emitterLayers.forEach { pauseLayer($0) }
    }

    func resumeAnimation() {
        guard isPaused else { return }
        isPaused = false
        resumeLayer(gradientLayer)
        emitterLayers.forEach { resumeLayer($0) }
    }

    // MARK: - Style Configuration

    private func configureStyle() {
        gradientLayer.removeFromSuperlayer()
        emitterLayers.forEach { $0.removeFromSuperlayer() }
        emitterLayers.removeAll()

        layer.insertSublayer(gradientLayer, at: 0)

        switch styleIndex {
        case 0: configureDeepSpaceNebula()
        case 1: configureAuroraBorealis()
        case 2: configureSolarFlare()
        case 3: configureMidnightOcean()
        case 4: configureCosmicDust()
        case 5: configureElectricStorm()
        case 6: configureLavaFlow()
        case 7: configurePrismMist()
        default: configureDeepSpaceNebula()
        }
    }

    // Style 0 — Deep Space Nebula
    private func configureDeepSpaceNebula() {
        gradientLayer.type = .radial
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.colors = [
            UIColor(hex: "0D0020").cgColor,
            UIColor(hex: "1A0040").cgColor,
            UIColor(hex: "2D0060").cgColor,
            UIColor(hex: "0D0020").cgColor
        ]

        let altColors = [
            UIColor(hex: "0D0020").cgColor,
            UIColor(hex: "2D0060").cgColor,
            UIColor(hex: "1A0040").cgColor,
            UIColor(hex: "120030").cgColor
        ]
        addColorAnimation(to: gradientLayer, from: gradientLayer.colors!, to: altColors, duration: 6, autoreverses: true)

        let stars = makeEmitterLayer()
        stars.emitterCells = [
            makeCell(
                color: .white,
                birthRate: 3,
                lifetime: 8,
                velocity: 8,
                scale: 0.015,
                alphaSpeed: -0.05
            )
        ]
        addEmitter(stars)

        let core = makeEmitterLayer()
        core.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        core.emitterCells = [
            makeCell(
                color: UIColor(hex: "FF6B2B"),
                birthRate: 1,
                lifetime: 6,
                velocity: 4,
                scale: 0.04,
                alphaSpeed: -0.08
            )
        ]
        addEmitter(core)
    }

    // Style 1 — Aurora Borealis
    private func configureAuroraBorealis() {
        gradientLayer.type = .axial
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.colors = [
            UIColor(hex: "001A1A").cgColor,
            UIColor(hex: "003333").cgColor,
            UIColor(hex: "004D4D").cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]

        let locationsAnimation = CAKeyframeAnimation(keyPath: "locations")
        locationsAnimation.values = [
            [0, 0.5, 1],
            [0, 0.35, 0.85],
            [0, 0.65, 1],
            [0, 0.5, 1]
        ]
        locationsAnimation.duration = 4
        locationsAnimation.repeatCount = .infinity
        locationsAnimation.isRemovedOnCompletion = false
        locationsAnimation.fillMode = .forwards
        gradientLayer.add(locationsAnimation, forKey: "auroraLocations")

        let aurora = makeEmitterLayer()
        aurora.emitterShape = .line
        aurora.emitterMode = .outline
        aurora.emitterSize = CGSize(width: bounds.width, height: 1)
        aurora.emitterPosition = CGPoint(x: bounds.midX, y: 0)
        aurora.emitterCells = [
            makeCell(
                color: UIColor(hex: "00FFCC"),
                birthRate: 2,
                lifetime: 10,
                velocity: 6,
                velocityRange: 5,
                scale: 0.018,
                alphaSpeed: -0.04,
                yAcceleration: 2
            )
        ]
        addEmitter(aurora)
    }

    // Style 2 — Solar Flare
    private func configureSolarFlare() {
        gradientLayer.type = .radial
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.colors = [
            UIColor(hex: "FF4500").cgColor,
            UIColor(hex: "FF8C00").cgColor,
            UIColor(hex: "3D1400").cgColor,
            UIColor(hex: "1A0800").cgColor
        ]

        let altColors = [
            UIColor(hex: "FF8C00").cgColor,
            UIColor(hex: "FF4500").cgColor,
            UIColor(hex: "3D1400").cgColor,
            UIColor(hex: "1A0800").cgColor
        ]
        addColorAnimation(to: gradientLayer, from: gradientLayer.colors!, to: altColors, duration: 3, autoreverses: true)

        let flare = makeEmitterLayer()
        flare.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY * 0.6)
        flare.emitterCells = [
            makeCell(
                color: UIColor(hex: "FF6B00"),
                birthRate: 4,
                lifetime: 3,
                velocity: 40,
                velocityRange: 20,
                scale: 0.02,
                alphaSpeed: -0.3,
                emissionLongitude: -.pi / 2
            ),
            makeCell(
                color: UIColor(hex: "FFD700"),
                birthRate: 4,
                lifetime: 3,
                velocity: 40,
                velocityRange: 20,
                scale: 0.02,
                alphaSpeed: -0.3,
                emissionLongitude: -.pi / 2
            )
        ]
        addEmitter(flare)
    }

    // Style 3 — Midnight Ocean
    private func configureMidnightOcean() {
        gradientLayer.type = .axial
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.colors = [
            UIColor(hex: "000814").cgColor,
            UIColor(hex: "001233").cgColor,
            UIColor(hex: "023E8A").cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]

        let waveAnimation = CAKeyframeAnimation(keyPath: "locations")
        waveAnimation.values = [
            [0, 0.5, 1],
            [0, 0.4, 0.95],
            [0, 0.6, 1],
            [0, 0.5, 1]
        ]
        waveAnimation.duration = 5
        waveAnimation.repeatCount = .infinity
        waveAnimation.isRemovedOnCompletion = false
        waveAnimation.fillMode = .forwards
        gradientLayer.add(waveAnimation, forKey: "oceanWave")

        let moonlight = makeEmitterLayer()
        moonlight.emitterCells = [
            makeCell(
                color: UIColor(hex: "C9B8E8"),
                birthRate: 1,
                lifetime: 12,
                velocity: 3,
                scale: 0.03,
                alphaSpeed: -0.03
            )
        ]
        addEmitter(moonlight)
    }

    // Style 4 — Cosmic Dust
    private func configureCosmicDust() {
        gradientLayer.type = .radial
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.colors = [
            UIColor(hex: "1A0010").cgColor,
            UIColor(hex: "2D0020").cgColor,
            UIColor(hex: "4D0030").cgColor
        ]

        let dust = makeEmitterLayer()
        dust.emitterShape = .circle
        dust.emitterMode = .surface
        dust.emitterSize = bounds.size
        dust.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        dust.emitterCells = [
            makeCell(
                color: UIColor(hex: "FF9EBB"),
                birthRate: 4,
                lifetime: 8,
                velocity: 15,
                velocityRange: 10,
                scale: 0.018,
                alphaSpeed: -0.05,
                spin: 0.3,
                spinRange: 0.5
            )
        ]
        addEmitter(dust)
    }

    // Style 5 — Electric Storm
    private func configureElectricStorm() {
        gradientLayer.type = .axial
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.colors = [
            UIColor(hex: "080808").cgColor,
            UIColor(hex: "0D0D0D").cgColor,
            UIColor(hex: "111111").cgColor
        ]

        let bursts = makeEmitterLayer()
        bursts.emitterCells = [
            makeCell(
                color: UIColor(hex: "00B4FF"),
                birthRate: 6,
                lifetime: 1.5,
                velocity: 80,
                velocityRange: 60,
                scale: 0.025,
                alphaSpeed: -0.6
            )
        ]
        addEmitter(bursts)

        let flash = makeEmitterLayer()
        flash.emitterCells = [
            makeCell(
                color: .white,
                birthRate: 1,
                lifetime: 0.5,
                velocity: 20,
                velocityRange: 30,
                scale: 0.04,
                alphaSpeed: -1.2
            )
        ]
        addEmitter(flash)
    }

    // Style 6 — Lava Flow
    private func configureLavaFlow() {
        gradientLayer.type = .axial
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.colors = [
            UIColor(hex: "1A0000").cgColor,
            UIColor(hex: "3D0000").cgColor,
            UIColor(hex: "8B0000").cgColor
        ]

        let altColors = [
            UIColor(hex: "3D0000").cgColor,
            UIColor(hex: "8B0000").cgColor,
            UIColor(hex: "CC5500").cgColor
        ]
        addColorAnimation(to: gradientLayer, from: gradientLayer.colors!, to: altColors, duration: 4, autoreverses: true)

        let lava = makeEmitterLayer()
        lava.emitterPosition = CGPoint(x: bounds.midX, y: 0)
        lava.emitterShape = .line
        lava.emitterSize = CGSize(width: bounds.width, height: 1)
        lava.emitterCells = [
            makeCell(
                color: UIColor(hex: "FF6B00"),
                birthRate: 3,
                lifetime: 6,
                velocity: 20,
                scale: 0.02,
                alphaSpeed: -0.08,
                yAcceleration: 10
            )
        ]
        addEmitter(lava)
    }

    // Style 7 — Prism Mist
    private func configurePrismMist() {
        backgroundColor = UIColor(hex: "0D0D10")

        gradientLayer.type = .axial
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.colors = [
            UIColor(hex: "C9B8E8").withAlphaComponent(0.35).cgColor,
            UIColor(hex: "F2C4A0").withAlphaComponent(0.35).cgColor,
            UIColor(hex: "B8D8C8").withAlphaComponent(0.35).cgColor
        ]

        let colorCycle = CAKeyframeAnimation(keyPath: "colors")
        colorCycle.values = [
            [
                UIColor(hex: "C9B8E8").withAlphaComponent(0.35).cgColor,
                UIColor(hex: "F2C4A0").withAlphaComponent(0.35).cgColor,
                UIColor(hex: "B8D8C8").withAlphaComponent(0.35).cgColor
            ],
            [
                UIColor(hex: "F2C4A0").withAlphaComponent(0.35).cgColor,
                UIColor(hex: "B8D8C8").withAlphaComponent(0.35).cgColor,
                UIColor(hex: "C9B8E8").withAlphaComponent(0.35).cgColor
            ],
            [
                UIColor(hex: "B8D8C8").withAlphaComponent(0.35).cgColor,
                UIColor(hex: "C9B8E8").withAlphaComponent(0.35).cgColor,
                UIColor(hex: "F2C4A0").withAlphaComponent(0.35).cgColor
            ],
            [
                UIColor(hex: "C9B8E8").withAlphaComponent(0.35).cgColor,
                UIColor(hex: "F2C4A0").withAlphaComponent(0.35).cgColor,
                UIColor(hex: "B8D8C8").withAlphaComponent(0.35).cgColor
            ]
        ]
        colorCycle.duration = 8
        colorCycle.repeatCount = .infinity
        colorCycle.isRemovedOnCompletion = false
        colorCycle.fillMode = .forwards
        gradientLayer.add(colorCycle, forKey: "prismColors")

        let mist = makeEmitterLayer()
        mist.emitterCells = [
            makeCell(
                color: .white,
                birthRate: 1,
                lifetime: 15,
                velocity: 3,
                scale: 0.05,
                alphaSpeed: -0.02
            )
        ]
        addEmitter(mist)
    }

    // MARK: - Helpers

    private func addEmitter(_ emitter: CAEmitterLayer) {
        layer.addSublayer(emitter)
        emitterLayers.append(emitter)
    }

    private func updateEmitterGeometry(_ emitter: CAEmitterLayer) {
        switch styleIndex {
        case 1:
            emitter.emitterShape = .line
            emitter.emitterSize = CGSize(width: bounds.width, height: 1)
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: 0)
        case 2:
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY * 0.6)
        case 4:
            emitter.emitterShape = .circle
            emitter.emitterSize = bounds.size
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        case 6:
            emitter.emitterShape = .line
            emitter.emitterSize = CGSize(width: bounds.width, height: 1)
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: 0)
        default:
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    private func makeEmitterLayer() -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterShape = .rectangle
        emitter.emitterMode = .volume
        emitter.renderMode = .additive
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitter.emitterSize = bounds.size
        return emitter
    }

    private func makeCell(
        color: UIColor,
        birthRate: Float,
        lifetime: Float,
        velocity: CGFloat,
        velocityRange: CGFloat = 0,
        scale: CGFloat,
        alphaSpeed: Float,
        yAcceleration: CGFloat = 0,
        spin: CGFloat = 0,
        spinRange: CGFloat = 0,
        emissionLongitude: CGFloat = 0
    ) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = ParticleTexture.circle.cgImage
        cell.color = color.cgColor
        cell.birthRate = birthRate
        cell.lifetime = lifetime
        cell.velocity = velocity
        cell.velocityRange = velocityRange
        cell.scale = scale
        cell.alphaSpeed = alphaSpeed
        cell.yAcceleration = yAcceleration
        cell.spin = spin
        cell.spinRange = spinRange
        cell.emissionLongitude = emissionLongitude
        cell.emissionRange = .pi * 2
        return cell
    }

    private func addColorAnimation(
        to layer: CAGradientLayer,
        from: [Any],
        to: [Any],
        duration: CFTimeInterval,
        autoreverses: Bool
    ) {
        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.autoreverses = autoreverses
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        layer.add(animation, forKey: "colorCycle")
    }

    private func pauseLayer(_ layer: CALayer) {
        let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = pausedTime
    }

    private func resumeLayer(_ layer: CALayer) {
        let pausedTime = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        layer.beginTime = timeSincePause
    }
}

// MARK: - Particle Texture

private enum ParticleTexture {
    static let circle: UIImage = {
        let size: CGFloat = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
    }()
}

// MARK: - UIColor Hex

private extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
