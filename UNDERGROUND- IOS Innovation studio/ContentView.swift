import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .feed
    @State private var selectedPost: Post?

    var body: some View {
        ZStack(alignment: .bottom) {
            AppPalette.background
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case .feed:
                    FeedView(posts: SeedData.posts) { post in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedPost = post
                        }
                    }
                case .discover:
                    PlaceholderTabView(title: "Discover")
                case .create:
                    PlaceholderTabView(title: "Create")
                case .profile:
                    PlaceholderTabView(title: "Profile")
                }
            }
            .padding(.bottom, 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNavBar(selectedTab: $selectedTab)

            if let selectedPost {
                PostDetailView(post: selectedPost) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.selectedPost = nil
                    }
                }
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private enum AppTab: String, CaseIterable {
    case feed = "Feed"
    case discover = "Discover"
    case create = "Create"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .feed:
            return "square.grid.2x2.fill"
        case .discover:
            return "magnifyingglass"
        case .create:
            return "plus.app.fill"
        case .profile:
            return "person.crop.circle.fill"
        }
    }
}

private struct FeedView: View {
    let posts: [Post]
    let onSelect: (Post) -> Void

    private var leftColumn: [Post] {
        posts.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
    }

    private var rightColumn: [Post] {
        posts.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Underground")
                    .font(.inter(.bold, size: 32))
                    .foregroundStyle(AppPalette.text)
                    .padding(.top, 8)

                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(leftColumn) { post in
                            PostCardView(post: post, onTap: onSelect)
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(rightColumn) { post in
                            PostCardView(post: post, onTap: onSelect)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
}

private struct PostCardView: View {
    let post: Post
    let onTap: (Post) -> Void

    var body: some View {
        Button {
            onTap(post)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(post.coverColor)
                    .frame(height: post.coverHeight)

                Text(post.artistName)
                    .font(.inter(.medium, size: 13))
                    .foregroundStyle(AppPalette.secondaryText)

                Text(post.title)
                    .font(.inter(.semibold, size: 16))
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PostDetailView: View {
    let post: Post
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.inter(.semibold, size: 16))
                    .foregroundStyle(AppPalette.lavender)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(post.coverColor)
                        .frame(height: 270)

                    Text(post.artistName)
                        .font(.inter(.medium, size: 14))
                        .foregroundStyle(AppPalette.secondaryText)

                    Text(post.title)
                        .font(.inter(.bold, size: 28))
                        .foregroundStyle(AppPalette.text)

                    Text(post.caption)
                        .font(.inter(.regular, size: 16))
                        .foregroundStyle(AppPalette.text)
                        .lineSpacing(5)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppPalette.background.ignoresSafeArea())
    }
}

private struct BottomNavBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.inter(.medium, size: 12))
                    }
                    .foregroundStyle(selectedTab == tab ? AppPalette.lavender : AppPalette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 20)
        .background(AppPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
    }
}

private struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(title)
                .font(.inter(.bold, size: 30))
                .foregroundStyle(AppPalette.text)
            Text("Coming soon")
                .font(.inter(.regular, size: 16))
                .foregroundStyle(AppPalette.secondaryText)
            Spacer()
        }
    }
}

private struct Post: Identifiable {
    let id = UUID()
    let artistName: String
    let title: String
    let caption: String
    let coverColor: Color
    let coverHeight: CGFloat
}

private enum SeedData {
    static let posts: [Post] = [
        Post(artistName: "Maya Chen", title: "Signal Loops at 2AM", caption: "A late-night set built from rough synth passes and ambient street recordings. This version keeps all the texture and imperfections.", coverColor: Color(hex: "6D5FA8"), coverHeight: 170),
        Post(artistName: "The Drift", title: "Tape Hiss Session", caption: "One take, no polish. We left the hiss and room noise in because it felt honest and alive.", coverColor: Color(hex: "618A7B"), coverHeight: 220),
        Post(artistName: "Solaris", title: "Soft Orbit", caption: "A slow vocal draft about belonging, with long pauses and gentle pads to let each line breathe.", coverColor: Color(hex: "B3876A"), coverHeight: 185),
        Post(artistName: "Neon Atlas", title: "City Frame Cypher", caption: "Verses drafted across train rides and station platforms. The rhythm follows the movement of the city.", coverColor: Color(hex: "7588A6"), coverHeight: 235),
        Post(artistName: "Juni Wolf", title: "Room Tone Diaries", caption: "Built from room tone, guitar harmonics, and whispered notes. Intimate and intentionally sparse.", coverColor: Color(hex: "8A6A9E"), coverHeight: 190),
        Post(artistName: "Pulse", title: "Subfloor Draft", caption: "A heavy low-end sketch tested in small club systems. Sharing this while it still feels raw.", coverColor: Color(hex: "5D7E9B"), coverHeight: 245),
        Post(artistName: "Ari Kade", title: "Neon Memory", caption: "A cinematic synth piece inspired by empty streets after midnight and fading signage.", coverColor: Color(hex: "7E5E91"), coverHeight: 180),
        Post(artistName: "Luma Rae", title: "Shadow Chorus", caption: "Layered harmonies with minimal percussion. Focused on mood, depth, and emotional space.", coverColor: Color(hex: "6D8A71"), coverHeight: 215)
    ]
}

private enum AppPalette {
    static let background = Color(hex: "0D0D10")
    static let card = Color(hex: "1A1A22")
    static let text = Color(hex: "F0F0F2")
    static let secondaryText = Color(hex: "A3A3B0")
    static let lavender = Color(hex: "C9B8E8")
}

private extension Font {
    enum InterWeight {
        case regular
        case medium
        case semibold
        case bold
    }

    static func inter(_ weight: InterWeight, size: CGFloat) -> Font {
        let name: String
        switch weight {
        case .regular:
            name = "Inter-Regular"
        case .medium:
            name = "Inter-Medium"
        case .semibold:
            name = "Inter-SemiBold"
        case .bold:
            name = "Inter-Bold"
        }

        // Falls back automatically if Inter isn't bundled yet.
        return .custom(name, size: size)
    }
}

private extension Color {
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

#Preview {
    ContentView()
}
