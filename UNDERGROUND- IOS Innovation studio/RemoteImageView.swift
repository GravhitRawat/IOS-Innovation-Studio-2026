import SwiftUI
import UIKit

// MARK: - Image Cache

final class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()

    private init() {}

    func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ key: String, image: UIImage) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// MARK: - Genre Query Mapping

func genreQuery(for genre: String) -> String {
    switch genre.lowercased() {
    case "electronic":
        return "electronic-music-neon-studio"
    case "indie":
        return "indie-concert-film-analog"
    case "hip-hop":
        return "hiphop-urban-street-night"
    case "r&b":
        return "rnb-city-lights-portrait"
    case "ambient":
        return "ambient-nature-fog-landscape"
    case "techno":
        return "techno-dark-club-pulse"
    default:
        return "music-artist-creative"
    }
}

// MARK: - Remote Image View

struct RemoteImageView: View {
    let query: String
    let width: Int
    let height: Int

    @State private var image: UIImage?
    @State private var isLoading = true

    private var imageURL: URL? {
        let seed = abs(query.hashValue) % 1000
        return URL(string: "https://picsum.photos/seed/\(seed)/\(width)/\(height)")
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(hex: "1A1A22"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "2A2A35"))
                            .frame(width: 40, height: 4)
                    )
                    .shimmering()
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = imageURL else { return }

        let cacheKey = url.absoluteString
        if let cached = ImageCache.shared.get(cacheKey) {
            image = cached
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let img = UIImage(data: data) else { return }
            ImageCache.shared.set(cacheKey, image: img)
            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: 0.3)) {
                    image = img
                    isLoading = false
                }
            }
        }.resume()
    }
}

// MARK: - Shimmer

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase * geo.size.width * 2)
                    .animation(
                        .linear(duration: 1.4).repeatForever(autoreverses: false),
                        value: phase
                    )
                    .onAppear { phase = 1 }
                }
                .clipped()
            )
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
