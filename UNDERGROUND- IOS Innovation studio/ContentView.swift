import AVFoundation
import Combine
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Root

struct ContentView: View {
    @State private var selectedTab: AppTab = .feed
    @State private var selectedPost: Post?
    @State private var selectedArtist: Artist?
    @State private var showingCreateSheet = false
    @State private var posts: [Post] = SeedData.posts
    @State private var commentsByPost: [UUID: [Comment]] = SeedData.commentsByPost
    @ObservedObject private var audioPlayer = AudioPlayerManager.shared

    @AppStorage("underground.savedPostIDs") private var savedPostIDsStorage = "[]"
    @AppStorage("underground.followingArtistIDs") private var followingArtistIDsStorage = "[]"

    private var savedPostIDs: Set<UUID> {
        Set(UUID.decodeArray(from: savedPostIDsStorage))
    }

    private var followingArtistIDs: Set<UUID> {
        Set(UUID.decodeArray(from: followingArtistIDsStorage))
    }

    private var savedPosts: [Post] {
        posts.filter { savedPostIDs.contains($0.id) }
    }

    private var followedArtists: [Artist] {
        SeedData.artists.filter { followingArtistIDs.contains($0.id) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppPalette.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .feed:
                    FeedView(
                        posts: posts,
                        artists: SeedData.artists,
                        onSelect: { post in
                            withAnimation(AppPalette.springStandard) {
                                selectedPost = post
                            }
                        },
                        onArtistTap: { artist in
                            withAnimation(AppPalette.springStandard) {
                                selectedArtist = artist
                            }
                        }
                    )
                case .discover:
                    DiscoverView(
                        artists: SeedData.artists,
                        posts: posts,
                        savedPosts: savedPosts,
                        userCity: SeedData.userCity,
                        onArtistTap: { artist in
                            withAnimation(AppPalette.springStandard) {
                                selectedArtist = artist
                            }
                        },
                        onPostTap: { post in
                            withAnimation(AppPalette.springStandard) {
                                selectedPost = post
                            }
                        }
                    )
                case .profile:
                    ProfileScreen(
                        artist: SeedData.currentArtist,
                        isOwnProfile: true,
                        posts: posts.filter { $0.artistID == SeedData.currentArtist.id },
                        likedArtists: followedArtists,
                        savedPosts: savedPosts,
                        isFollowing: false,
                        onToggleFollow: {},
                        onUnfollow: { artistID in
                            toggleFollow(artistID: artistID)
                        },
                        onPostTap: { post in
                            withAnimation(AppPalette.springStandard) {
                                selectedPost = post
                            }
                        }
                    )
                case .create:
                    EmptyView()
                }
            }
            .padding(.bottom, 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNavBar(selectedTab: $selectedTab) {
                showingCreateSheet = true
            }

            if let selectedPost {
                PostDetailView(
                    post: selectedPost,
                    artist: SeedData.artist(for: selectedPost.artistID),
                    comments: commentsByPost[selectedPost.id] ?? [],
                    isSaved: savedPostIDs.contains(selectedPost.id),
                    onBack: {
                        withAnimation(AppPalette.springStandard) {
                            self.selectedPost = nil
                        }
                    },
                    onSaveTap: { toggleSaved(postID: selectedPost.id) },
                    onArtistTap: { artist in
                        withAnimation(AppPalette.springStandard) {
                            selectedArtist = artist
                        }
                    },
                    onAddComment: { text in
                        addComment(to: selectedPost.id, body: text)
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }

            if let selectedArtist {
                ProfileScreen(
                    artist: selectedArtist,
                    isOwnProfile: selectedArtist.id == SeedData.currentArtist.id,
                    posts: posts.filter { $0.artistID == selectedArtist.id },
                    likedArtists: followedArtists,
                    savedPosts: savedPosts,
                    isFollowing: followingArtistIDs.contains(selectedArtist.id),
                    onToggleFollow: { toggleFollow(artistID: selectedArtist.id) },
                    onUnfollow: { artistID in
                        toggleFollow(artistID: artistID)
                    },
                    onPostTap: { post in
                        withAnimation(AppPalette.springStandard) {
                            selectedPost = post
                        }
                    },
                    onBack: {
                        withAnimation(AppPalette.springStandard) {
                            self.selectedArtist = nil
                        }
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(3)
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreatePostSheet { draft in
                let newPost = Post(
                    id: UUID(),
                    artistID: SeedData.currentArtist.id,
                    title: draft.title,
                    caption: draft.story,
                    genre: draft.genre,
                    mood: draft.mood,
                    hashtags: [draft.mood.rawValue, draft.genre.rawValue],
                    coverHeight: 220,
                    coverImageData: draft.coverImageData,
                    audioURL: draft.audioURL,
                    audioTitle: draft.audioTitle,
                    audioDuration: draft.audioDuration,
                    bloopers: draft.bloopers,
                    trackVersions: draft.trackVersions,
                    isLandscape: draft.isLandscape
                )
                posts.insert(newPost, at: 0)
                commentsByPost[newPost.id] = []
            }
        }
        .preferredColorScheme(.dark)
    }

    private func toggleSaved(postID: UUID) {
        var current = savedPostIDs
        if current.contains(postID) {
            current.remove(postID)
        } else {
            current.insert(postID)
        }
        savedPostIDsStorage = UUID.encodeArray(Array(current))
    }

    private func toggleFollow(artistID: UUID) {
        var current = followingArtistIDs
        if current.contains(artistID) {
            current.remove(artistID)
        } else {
            current.insert(artistID)
        }
        followingArtistIDsStorage = UUID.encodeArray(Array(current))
    }

    private func addComment(to postID: UUID, body: String) {
        let newComment = Comment(
            id: UUID(),
            username: "You",
            text: body,
            isArtistComment: false
        )
        var existing = commentsByPost[postID] ?? []
        existing.append(newComment)
        commentsByPost[postID] = existing
    }
}

// MARK: - Tabs

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

private struct BottomNavBar: View {
    @Binding var selectedTab: AppTab
    let onCreateTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    if tab == .create {
                        onCreateTap()
                    } else {
                        withAnimation(AppPalette.springStandard) {
                            selectedTab = tab
                        }
                    }
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

// MARK: - Feed

private struct FeedView: View {
    let posts: [Post]
    let artists: [Artist]
    let onSelect: (Post) -> Void
    let onArtistTap: (Artist) -> Void
    @State private var selectedGenre: Genre = .all
    @State private var longPressedPost: Post?
    @State private var longPressPlaybackProgress: Double = 0
    @State private var longPressIsPlaying = false
    @State private var longPressTimer: Timer?
    @State private var overlayImagePulse = false

    private var filteredPosts: [Post] {
        if selectedGenre == .all {
            return posts
        }
        return posts.filter { $0.genre == selectedGenre }
    }

    private var leftColumn: [Post] {
        filteredPosts.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
    }

    private var rightColumn: [Post] {
        filteredPosts.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element)
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppPalette.card)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppPalette.lavender)
                            )

                        Text("underground")
                            .font(.inter(.semibold, size: 17))
                            .foregroundStyle(AppPalette.text)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 14)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Genre.allCases) { genre in
                                Button {
                                    withAnimation(AppPalette.springStandard) {
                                        selectedGenre = genre
                                    }
                                } label: {
                                    Text(genre.label)
                                        .font(.inter(.medium, size: 13))
                                        .foregroundStyle(selectedGenre == genre ? AppPalette.background : AppPalette.text)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedGenre == genre ? AppPalette.lavender : AppPalette.card)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 14)

                    HStack(alignment: .top, spacing: 12) {
                        LazyVStack(spacing: 12) {
                            ForEach(leftColumn) { post in
                                if let artist = artists.first(where: { $0.id == post.artistID }) {
                                    PostCardView(
                                        post: post,
                                        artist: artist,
                                        onTap: onSelect,
                                        onArtistTap: onArtistTap,
                                        onLongPressStart: { startLongPressOverlay(for: post) },
                                        onLongPressEnd: { endLongPressOverlay() }
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        LazyVStack(spacing: 12) {
                            ForEach(rightColumn) { post in
                                if let artist = artists.first(where: { $0.id == post.artistID }) {
                                    PostCardView(
                                        post: post,
                                        artist: artist,
                                        onTap: onSelect,
                                        onArtistTap: onArtistTap,
                                        onLongPressStart: { startLongPressOverlay(for: post) },
                                        onLongPressEnd: { endLongPressOverlay() }
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            if let longPressedPost,
               let artist = artists.first(where: { $0.id == longPressedPost.artistID }) {
                FeedLongPressOverlay(
                    post: longPressedPost,
                    artist: artist,
                    playbackProgress: longPressPlaybackProgress,
                    isPlaying: longPressIsPlaying,
                    imagePulse: overlayImagePulse,
                    onTogglePlay: { toggleLongPressPlayback() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: longPressedPost?.id)
        .onChange(of: longPressedPost?.id) { _, newID in
            if newID != nil {
                overlayImagePulse = true
                startLongPressPlayback()
            } else {
                overlayImagePulse = false
            }
        }
    }

    private func startLongPressOverlay(for post: Post) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            longPressedPost = post
        }
    }

    private func endLongPressOverlay() {
        stopLongPressTimer()
        longPressPlaybackProgress = 0
        longPressIsPlaying = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            longPressedPost = nil
        }
    }

    private func startLongPressPlayback() {
        guard longPressedPost != nil else { return }
        longPressPlaybackProgress = 0
        longPressIsPlaying = true
        startLongPressTimer()
    }

    private func toggleLongPressPlayback() {
        if longPressIsPlaying {
            stopLongPressTimer()
            longPressIsPlaying = false
        } else {
            if longPressPlaybackProgress >= 1.0 {
                longPressPlaybackProgress = 0
            }
            longPressIsPlaying = true
            startLongPressTimer()
        }
    }

    private func startLongPressTimer() {
        stopLongPressTimer()
        let duration = longPressedPost?.audioDuration ?? 214
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let increment = 0.1 / duration
            if longPressPlaybackProgress + increment >= 1.0 {
                stopLongPressTimer()
                longPressIsPlaying = false
                longPressPlaybackProgress = 0
            } else {
                longPressPlaybackProgress += increment
            }
        }
    }

    private func stopLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
}

private struct PostCardView: View {
    let post: Post
    let artist: Artist
    let onTap: (Post) -> Void
    let onArtistTap: (Artist) -> Void
    let onLongPressStart: () -> Void
    let onLongPressEnd: () -> Void
    @State private var pressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                    pressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                    pressed = false
                    onTap(post)
                }
            } label: {
                FeedCoverImageView(post: post, height: post.coverHeight)
            }
            .buttonStyle(.plain)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .onEnded { _ in
                        onLongPressStart()
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        onLongPressEnd()
                    }
            )

            if post.audioURL != nil || post.audioDuration != nil {
                CompactPlayerBar(post: post)
            }

            Button {
                onArtistTap(artist)
            } label: {
                HStack(spacing: 8) {
                    AvatarView(colorHex: artist.avatarColorHex, initials: artist.initials, size: 28)
                    Text(artist.name)
                        .font(.inter(.medium, size: 13))
                        .foregroundStyle(AppPalette.secondaryText)
                }
            }
            .buttonStyle(.plain)

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
}

private struct FeedCoverImageView: View {
    let post: Post
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let imageData = post.coverImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    RemoteImageView(
                        query: genreQuery(for: post.genre.label),
                        width: 400,
                        height: 500
                    )
                }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(
                colors: [.clear, Color(hex: "0D0D10").opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct FeedLongPressOverlay: View {
    let post: Post
    let artist: Artist
    let playbackProgress: Double
    let isPlaying: Bool
    let imagePulse: Bool
    let onTogglePlay: () -> Void
    @State private var hintOpacity = 0.5
    @State private var playButtonScale: CGFloat = 1.0

    private var hasAudio: Bool {
        post.audioURL != nil || post.audioDuration != nil
    }

    private var audioDuration: TimeInterval {
        post.audioDuration ?? 214
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Group {
                    if let imageData = post.coverImageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RemoteImageView(
                            query: genreQuery(for: post.genre.label),
                            width: 300,
                            height: 300
                        )
                    }
                }
                .frame(width: 300, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.6), radius: 20)
                .scaleEffect(imagePulse ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: imagePulse)

                Text(post.title)
                    .font(.inter(.bold, size: 22))
                    .foregroundStyle(AppPalette.text)
                    .multilineTextAlignment(.center)

                Text(artist.name)
                    .font(.inter(.regular, size: 15))
                    .foregroundStyle(AppPalette.secondaryText)

                Chip(text: post.genre.label, background: AppPalette.lavender, foreground: AppPalette.background)

                if hasAudio {
                    VStack(spacing: 12) {
                        DetailWaveformVisualiser(isPlaying: isPlaying)
                            .frame(width: 220)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppPalette.trackBackground)
                                    .frame(height: 3)
                                Capsule()
                                    .fill(AppPalette.lavender)
                                    .frame(width: max(0, proxy.size.width * playbackProgress), height: 3)
                                    .animation(.linear(duration: 0.1), value: playbackProgress)
                            }
                        }
                        .frame(height: 3)
                        .frame(width: 220)

                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                playButtonScale = 0.85
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    playButtonScale = 1.0
                                }
                            }
                            onTogglePlay()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(AppPalette.lavender)
                                .scaleEffect(playButtonScale)
                        }
                        .buttonStyle(.plain)

                        Text("\(formatTime(playbackProgress * audioDuration)) / \(formatTime(audioDuration))")
                            .font(.inter(.regular, size: 12))
                            .foregroundStyle(AppPalette.secondaryText)
                    }
                    .padding(.top, 8)
                }

                Spacer()

                Text("release to close")
                    .font(.inter(.regular, size: 12))
                    .foregroundStyle(AppPalette.tertiaryText)
                    .opacity(hintOpacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                            hintOpacity = 1.0
                        }
                    }
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct PostCoverImageView: View {
    let imageData: Data?
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .fill(AppPalette.card)
                    .frame(height: height)
                    .overlay(
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(AppPalette.secondaryText)
                    )
            }

            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: max(height * 0.45, 56))
            .allowsHitTesting(false)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Compact Player Bar (in feed card)

private struct CompactPlayerBar: View {
    let post: Post
    @ObservedObject private var player = AudioPlayerManager.shared

    private var isActive: Bool {
        player.currentPostID == post.id
    }

    private var isPlaying: Bool {
        isActive && player.isPlaying
    }

    private var progress: Double {
        guard isActive, player.duration > 0 else { return 0 }
        return min(1, max(0, player.currentTime / player.duration))
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.lavender)

                Text(post.audioTitle ?? "Untitled track")
                    .font(.inter(.medium, size: 12))
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Button {
                    if let url = post.audioURL {
                        player.toggle(
                            url: url,
                            postID: post.id,
                            title: post.audioTitle ?? post.title,
                            duration: post.audioDuration ?? 0
                        )
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppPalette.lavender)
                }
                .buttonStyle(.plain)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(AppPalette.trackBackground)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(AppPalette.lavender)
                        .frame(width: max(0, proxy.size.width * progress), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppPalette.background.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Post Detail

private struct PostDetailView: View {
    let post: Post
    let artist: Artist
    let comments: [Comment]
    let isSaved: Bool
    let onBack: () -> Void
    let onSaveTap: () -> Void
    let onArtistTap: (Artist) -> Void
    let onAddComment: (String) -> Void
    @State private var commentDraft = ""
    @State private var fullscreenBlooper: BlooperItem?
    @State private var activeVersionID: UUID?
    @State private var versionProgress: Double = 0
    @State private var versionIsPlaying = false
    @State private var versionTimer: Timer?

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

                Button(action: onSaveTap) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppPalette.lavender)
                        .frame(width: 36, height: 36)
                        .background(AppPalette.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    PostCoverImageView(imageData: post.coverImageData, height: 270)

                    Button {
                        onArtistTap(artist)
                    } label: {
                        HStack(spacing: 8) {
                            AvatarView(colorHex: artist.avatarColorHex, initials: artist.initials, size: 32)
                            Text(artist.name)
                                .font(.inter(.medium, size: 14))
                                .foregroundStyle(AppPalette.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 8) {
                        Chip(text: post.genre.label, background: AppPalette.card, foreground: AppPalette.text)
                        ForEach(post.hashtags, id: \.self) { tag in
                            Chip(text: "#\(tag)", background: AppPalette.card, foreground: AppPalette.secondaryText)
                        }
                    }

                    Text(post.title)
                        .font(.inter(.bold, size: 28))
                        .foregroundStyle(AppPalette.text)

                    Text(post.caption)
                        .font(.inter(.regular, size: 16))
                        .foregroundStyle(AppPalette.text)
                        .lineSpacing(5)

                    if post.hasAudio {
                        PostDetailMusicPlayer(post: post)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Comments")
                            .font(.inter(.semibold, size: 18))
                            .foregroundStyle(AppPalette.text)

                        ForEach(comments) { comment in
                            HStack(alignment: .top, spacing: 8) {
                                AvatarView(
                                    colorHex: comment.isArtistComment ? "C9B8E8" : "6B6B82",
                                    initials: comment.initials,
                                    size: 26
                                )
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(comment.username)
                                            .font(.inter(.semibold, size: 13))
                                            .foregroundStyle(AppPalette.text)
                                        if comment.isArtistComment {
                                            Chip(text: "Artist", background: AppPalette.peach, foreground: AppPalette.background)
                                        }
                                    }
                                    Text(comment.text)
                                        .font(.inter(.regular, size: 14))
                                        .foregroundStyle(AppPalette.secondaryText)
                                }
                            }
                        }
                    }

                    if !post.trackVersions.isEmpty {
                        VersionHistorySection(
                            versions: post.trackVersions,
                            activeVersionID: $activeVersionID,
                            versionProgress: $versionProgress,
                            versionIsPlaying: $versionIsPlaying,
                            versionTimer: $versionTimer
                        )
                    }

                    if !post.bloopers.isEmpty {
                        BloopersSection(bloopers: post.bloopers) { item in
                            fullscreenBlooper = item
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }

            HStack(spacing: 8) {
                TextField("Write a comment...", text: $commentDraft)
                    .font(.inter(.regular, size: 14))
                    .foregroundStyle(AppPalette.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button("Send") {
                    let trimmed = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onAddComment(trimmed)
                    commentDraft = ""
                }
                .font(.inter(.semibold, size: 14))
                .foregroundStyle(AppPalette.lavender)
                .padding(.horizontal, 10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(AppPalette.background)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppPalette.background.ignoresSafeArea())
        .sheet(item: $fullscreenBlooper) { item in
            BlooperFullscreenView(item: item) {
                fullscreenBlooper = nil
            }
        }
    }
}

// MARK: - Post Detail Music Player

private struct PostDetailMusicPlayer: View {
    let post: Post
    @State private var playbackProgress: Double = 0
    @State private var isPlaying = false
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0
    @State private var playButtonScale: CGFloat = 1.0
    @State private var playbackTimer: Timer?
    @State private var wasPlayingBeforeScrub = false

    private var audioDuration: TimeInterval {
        post.audioDuration ?? 214
    }

    private var displayProgress: Double {
        isScrubbing ? scrubProgress : playbackProgress
    }

    private var currentTime: TimeInterval {
        displayProgress * audioDuration
    }

    private var trackTitle: String {
        post.audioTitle ?? post.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.lavender)

                Text(trackTitle)
                    .font(.inter(.bold, size: 15))
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)

                Spacer()

                Text(formatTime(audioDuration))
                    .font(.inter(.regular, size: 12))
                    .foregroundStyle(AppPalette.secondaryText)
            }

            DetailWaveformVisualiser(isPlaying: isPlaying)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppPalette.trackBackground)
                        .frame(height: 3)

                    Capsule()
                        .fill(AppPalette.lavender)
                        .frame(width: max(0, proxy.size.width * displayProgress), height: 3)
                        .animation(.linear(duration: 0.1), value: displayProgress)

                    Circle()
                        .fill(AppPalette.lavender)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .offset(x: max(0, proxy.size.width * displayProgress - 5))
                        .animation(.linear(duration: 0.1), value: displayProgress)
                }
                .frame(height: 10)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isScrubbing {
                                wasPlayingBeforeScrub = isPlaying
                                stopTimer()
                                isPlaying = false
                            }
                            isScrubbing = true
                            scrubProgress = min(1, max(0, value.location.x / proxy.size.width))
                        }
                        .onEnded { _ in
                            isScrubbing = false
                            playbackProgress = scrubProgress
                            if wasPlayingBeforeScrub {
                                isPlaying = true
                                startTimer()
                            }
                        }
                )
            }
            .frame(height: 14)

            HStack {
                Text(formatTime(currentTime))
                    .font(.inter(.regular, size: 12))
                    .foregroundStyle(AppPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        playButtonScale = 0.85
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            playButtonScale = 1.0
                        }
                    }
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(AppPalette.lavender)
                        .scaleEffect(playButtonScale)
                }
                .buttonStyle(.plain)

                Text(formatTime(audioDuration))
                    .font(.inter(.regular, size: 12))
                    .foregroundStyle(AppPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onDisappear {
            stopTimer()
        }
    }

    private func togglePlayback() {
        if isPlaying {
            stopTimer()
            isPlaying = false
        } else {
            if playbackProgress >= 1.0 {
                playbackProgress = 0
            }
            isPlaying = true
            startTimer()
        }
    }

    private func startTimer() {
        stopTimer()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let increment = 0.1 / audioDuration
            if playbackProgress + increment >= 1.0 {
                stopTimer()
                isPlaying = false
                playbackProgress = 0
            } else {
                playbackProgress += increment
            }
        }
    }

    private func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}

private struct DetailWaveformVisualiser: View {
    let isPlaying: Bool
    private let barCount = 28

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                DetailWaveformBar(index: index, isPlaying: isPlaying)
            }
        }
        .frame(height: 32)
        .frame(maxWidth: .infinity)
    }
}

private struct DetailWaveformBar: View {
    let index: Int
    let isPlaying: Bool

    private let minHeight: CGFloat
    private let maxHeight: CGFloat
    private let animDuration: Double

    @State private var height: CGFloat = 4

    init(index: Int, isPlaying: Bool) {
        self.index = index
        self.isPlaying = isPlaying
        var generator = SeededGenerator(seed: UInt64(index + 1))
        minHeight = CGFloat.random(in: 4...8, using: &generator)
        maxHeight = CGFloat.random(in: 16...32, using: &generator)
        animDuration = Double.random(in: 0.3...0.7, using: &generator)
    }

    private var barColor: Color {
        isPlaying ? AppPalette.lavender : AppPalette.barMuted
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(barColor)
            .frame(width: 2, height: height)
            .animation(
                .easeInOut(duration: animDuration)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.04),
                value: isPlaying
            )
            .onAppear { updateHeight() }
            .onChange(of: isPlaying) { _, _ in
                updateHeight()
            }
    }

    private func updateHeight() {
        if isPlaying {
            height = minHeight
            withAnimation(
                .easeInOut(duration: animDuration)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.04)
            ) {
                height = maxHeight
            }
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                height = 4
            }
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Version History

private struct VersionHistorySection: View {
    let versions: [TrackVersion]
    @Binding var activeVersionID: UUID?
    @Binding var versionProgress: Double
    @Binding var versionIsPlaying: Bool
    @Binding var versionTimer: Timer?

    private var versionCountLabel: String {
        "\(versions.count) version\(versions.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("🎵")
                        .font(.system(size: 17))
                    Text("Version History")
                        .font(.inter(.semibold, size: 17))
                        .foregroundStyle(AppPalette.text)
                }

                Spacer()

                Text(versionCountLabel)
                    .font(.inter(.regular, size: 13))
                    .foregroundStyle(AppPalette.secondaryText)
            }

            VStack(spacing: 10) {
                ForEach(versions) { version in
                    VersionHistoryCard(
                        version: version,
                        isActive: activeVersionID == version.id,
                        isPlaying: activeVersionID == version.id && versionIsPlaying,
                        progress: activeVersionID == version.id ? versionProgress : 0,
                        onSelect: {
                            activeVersionID = version.id
                            stopVersionTimer()
                            versionIsPlaying = false
                            versionProgress = 0
                        },
                        onTogglePlay: {
                            toggleVersionPlayback(version)
                        }
                    )
                }
            }
        }
        .onDisappear {
            stopVersionTimer()
        }
    }

    private func toggleVersionPlayback(_ version: TrackVersion) {
        if activeVersionID == version.id && versionIsPlaying {
            stopVersionTimer()
            versionIsPlaying = false
            return
        }

        if activeVersionID != version.id {
            versionProgress = 0
        } else if versionProgress >= 1.0 {
            versionProgress = 0
        }

        activeVersionID = version.id
        versionIsPlaying = true
        startVersionTimer(duration: version.duration)
    }

    private func startVersionTimer(duration: TimeInterval) {
        stopVersionTimer()
        versionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let increment = 0.1 / duration
            if versionProgress + increment >= 1.0 {
                stopVersionTimer()
                versionIsPlaying = false
                versionProgress = 0
            } else {
                versionProgress += increment
            }
        }
    }

    private func stopVersionTimer() {
        versionTimer?.invalidate()
        versionTimer = nil
    }
}

private struct VersionHistoryCard: View {
    let version: TrackVersion
    let isActive: Bool
    let isPlaying: Bool
    let progress: Double
    let onSelect: () -> Void
    let onTogglePlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(version.versionLabel)
                    .font(.inter(.medium, size: 12))
                    .foregroundStyle(AppPalette.lavender)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppPalette.trackBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(version.title)
                    .font(.inter(.bold, size: 15))
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)

                Spacer()

                Text(formatTime(version.duration))
                    .font(.inter(.regular, size: 12))
                    .foregroundStyle(AppPalette.secondaryText)
            }

            HStack(spacing: 10) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppPalette.trackBackground)
                            .frame(height: 2)
                        Capsule()
                            .fill(AppPalette.lavender)
                            .frame(width: max(0, proxy.size.width * progress), height: 2)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                }
                .frame(height: 2)

                Button(action: onTogglePlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppPalette.lavender)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isActive ? AppPalette.lavender.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Bloopers

private struct BloopersSection: View {
    let bloopers: [BlooperItem]
    let onSelect: (BlooperItem) -> Void

    private var momentLabel: String {
        "\(bloopers.count) moment\(bloopers.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(AppPalette.trackBackground)
                .frame(height: 1)

            HStack {
                HStack(spacing: 6) {
                    Text("🎬")
                        .font(.system(size: 17))
                    Text("Behind the Scenes")
                        .font(.inter(.semibold, size: 17))
                        .foregroundStyle(AppPalette.text)
                }

                Spacer()

                Text(momentLabel)
                    .font(.inter(.regular, size: 13))
                    .foregroundStyle(AppPalette.secondaryText)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(bloopers) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            VStack(spacing: 0) {
                                Group {
                                    if let data = item.imageData, let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Rectangle()
                                            .fill(AppPalette.trackBackground)
                                    }
                                }
                                .frame(width: 150, height: 140)
                                .clipped()

                                if let caption = item.caption, !caption.isEmpty {
                                    Text(caption)
                                        .font(.inter(.regular, size: 12))
                                        .foregroundStyle(AppPalette.secondaryText)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(6)
                                } else {
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(width: 150, height: 190)
                            .background(AppPalette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppPalette.trackBackground, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct BlooperFullscreenView: View {
    let item: BlooperItem
    let onDismiss: () -> Void
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                if let data = item.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 16)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundStyle(AppPalette.secondaryText)
                }

                if let caption = item.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.inter(.regular, size: 15))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
            .offset(y: dragOffset)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(AppPalette.card.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                Spacer()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        onDismiss()
                    } else {
                        withAnimation(AppPalette.springStandard) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}

// MARK: - Discover

private struct DiscoverView: View {
    let artists: [Artist]
    let posts: [Post]
    let savedPosts: [Post]
    let userCity: String
    let onArtistTap: (Artist) -> Void
    let onPostTap: (Post) -> Void

    @State private var query = ""

    private var preferredGenres: Set<Genre> {
        if savedPosts.isEmpty {
            return Set(Genre.selectableCases)
        }
        return Set(savedPosts.map(\.genre))
    }

    private var youMightLikePosts: [Post] {
        posts.filter { preferredGenres.contains($0.genre) }
    }

    private var landscapePosts: [Post] {
        posts.filter { $0.isLandscape }
    }

    private var trendingCityPosts: [Post] {
        posts.filter { post in
            let artist = artists.first { $0.id == post.artistID }
            return artist?.city == userCity
        }
    }

    private var newArtists: [Artist] {
        artists.sorted { $0.followerCount < $1.followerCount }
    }

    private var searchResults: [Artist] {
        guard !query.isEmpty else { return [] }
        return artists.filter { artist in
            artist.name.localizedCaseInsensitiveContains(query) ||
            artist.genres.map(\.label).joined(separator: " ").localizedCaseInsensitiveContains(query) ||
            artist.city.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Discover")
                    .font(.inter(.bold, size: 30))
                    .foregroundStyle(AppPalette.text)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppPalette.secondaryText)
                    TextField("", text: $query, prompt: Text("artists, songs, genres, cities...").foregroundColor(AppPalette.tertiaryText))
                        .font(.inter(.regular, size: 15))
                        .foregroundStyle(AppPalette.text)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(AppPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .padding(.horizontal, 16)

                if !query.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(searchResults) { artist in
                            Button {
                                onArtistTap(artist)
                            } label: {
                                HStack(spacing: 10) {
                                    AvatarView(colorHex: artist.avatarColorHex, initials: artist.initials, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(artist.name)
                                            .font(.inter(.semibold, size: 14))
                                            .foregroundStyle(AppPalette.text)
                                        Text(artist.genres.map(\.label).joined(separator: " • "))
                                            .font(.inter(.regular, size: 12))
                                            .foregroundStyle(AppPalette.secondaryText)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            Divider().background(AppPalette.tertiaryText.opacity(0.2))
                        }

                        if searchResults.isEmpty {
                            Text("No matches")
                                .font(.inter(.regular, size: 13))
                                .foregroundStyle(AppPalette.secondaryText)
                                .padding(12)
                        }
                    }
                    .background(AppPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                } else {
                    discoverContent
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var discoverContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            DiscoverSectionHeader(title: "You might like")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(youMightLikePosts) { post in
                        let artist = artists.first { $0.id == post.artistID }
                        PortraitPostCard(post: post, artist: artist) { onPostTap(post) }
                    }
                }
                .padding(.horizontal, 16)
            }

            DiscoverSectionHeader(title: "Landscape Posts")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(landscapePosts) { post in
                        let artist = artists.first { $0.id == post.artistID }
                        LandscapePostCard(post: post, artist: artist) { onPostTap(post) }
                    }
                }
                .padding(.horizontal, 16)
            }

            DiscoverSectionHeader(title: "Trending in \(userCity)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(trendingCityPosts) { post in
                        let artist = artists.first { $0.id == post.artistID }
                        PortraitPostCard(post: post, artist: artist) { onPostTap(post) }
                    }
                }
                .padding(.horizontal, 16)
            }

            DiscoverSectionHeader(title: "New artists")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(newArtists) { artist in
                        Button {
                            onArtistTap(artist)
                        } label: {
                            VStack(spacing: 6) {
                                AvatarView(colorHex: artist.avatarColorHex, initials: artist.initials, size: 64)
                                Text(artist.name)
                                    .font(.inter(.medium, size: 12))
                                    .foregroundStyle(AppPalette.text)
                                Text(artist.genres.first?.label ?? "")
                                    .font(.inter(.regular, size: 10))
                                    .foregroundStyle(AppPalette.secondaryText)
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct DiscoverSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.inter(.semibold, size: 17))
                .foregroundStyle(AppPalette.text)
            Spacer()
            Button("see all") {}
                .font(.inter(.medium, size: 13))
                .foregroundStyle(AppPalette.lavender)
        }
        .padding(.horizontal, 16)
    }
}

private struct PortraitPostCard: View {
    let post: Post
    let artist: Artist?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let data = post.coverImageData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            RemoteImageView(
                                query: genreQuery(for: post.genre.label),
                                width: 320,
                                height: 440
                            )
                        }
                    }
                    .frame(width: 160, height: 220)
                    .clipped()

                    LinearGradient(
                        colors: [.clear, Color(hex: "0D0D10").opacity(0.85)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Spacer()
                        Chip(text: post.genre.label, background: AppPalette.lavender, foreground: AppPalette.background)
                        Text(artist?.name ?? "")
                            .font(.inter(.medium, size: 11))
                            .foregroundStyle(AppPalette.text)
                    }
                    .padding(10)
                }
                .frame(width: 160, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct LandscapePostCard: View {
    let post: Post
    let artist: Artist?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let data = post.coverImageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RemoteImageView(
                            query: genreQuery(for: post.genre.label),
                            width: 640,
                            height: 360
                        )
                    }
                }
                .frame(width: 320, height: 180)
                .clipped()

                LinearGradient(
                    colors: [.clear, Color(hex: "0D0D10").opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(artist?.name ?? "")
                        .font(.inter(.medium, size: 12))
                        .foregroundStyle(AppPalette.text.opacity(0.85))
                    Text(post.title)
                        .font(.inter(.semibold, size: 16))
                        .foregroundStyle(AppPalette.text)
                        .lineLimit(1)
                }
                .padding(12)
            }
            .frame(width: 320, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Screen (unified own & other artist)

private enum ProfileSegment: String, CaseIterable, Identifiable {
    case posts = "Posts"
    case liked = "Liked Artists"
    case saved = "Saved Posts"
    var id: String { rawValue }
    var label: String { rawValue }
}

private struct ProfileScreen: View {
    let artist: Artist
    let isOwnProfile: Bool
    let posts: [Post]
    let likedArtists: [Artist]
    let savedPosts: [Post]
    let isFollowing: Bool
    let onToggleFollow: () -> Void
    let onUnfollow: (UUID) -> Void
    let onPostTap: (Post) -> Void
    var onBack: (() -> Void)?

    @State private var selectedSegment: ProfileSegment = .posts

    var body: some View {
        VStack(spacing: 0) {
            if let onBack {
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
                .padding(.bottom, 8)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(artist.bannerColor)
                        .frame(height: 170)

                    VStack(spacing: 10) {
                        AvatarView(colorHex: artist.avatarColorHex, initials: artist.initials, size: 88)
                            .overlay(Circle().stroke(AppPalette.background, lineWidth: 4))
                            .offset(y: -44)
                            .padding(.bottom, -44)

                        Text(artist.name)
                            .font(.inter(.bold, size: 26))
                            .foregroundStyle(AppPalette.text)

                        Text(artist.city)
                            .font(.inter(.regular, size: 14))
                            .foregroundStyle(AppPalette.secondaryText)

                        Text(artist.bio)
                            .font(.inter(.regular, size: 13))
                            .foregroundStyle(AppPalette.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        HStack(spacing: 8) {
                            ForEach(artist.genres) { genre in
                                Chip(text: genre.label, background: AppPalette.card, foreground: AppPalette.text)
                            }
                        }

                        if artist.isFoundingArtist {
                            Chip(text: "Founding Artist", background: AppPalette.lavender, foreground: AppPalette.background)
                        }

                        if !isOwnProfile {
                            Button {
                                withAnimation(AppPalette.springStandard) {
                                    onToggleFollow()
                                }
                            } label: {
                                Text(isFollowing ? "Following" : "Follow")
                                    .font(.inter(.semibold, size: 15))
                                    .foregroundStyle(isFollowing ? AppPalette.text : AppPalette.background)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(isFollowing ? AppPalette.card : AppPalette.lavender)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                    SegmentedTabBar(selected: $selectedSegment)
                        .padding(.top, 6)

                    Group {
                        switch selectedSegment {
                        case .posts:
                            ProfilePostsGrid(posts: posts, onTap: onPostTap)
                        case .liked:
                            LikedArtistsList(artists: likedArtists, onUnfollow: onUnfollow)
                        case .saved:
                            SavedPostsGrid(savedPosts: savedPosts, onTap: onPostTap)
                        }
                    }
                    .padding(.top, 14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppPalette.background.ignoresSafeArea())
    }
}

private struct SegmentedTabBar: View {
    @Binding var selected: ProfileSegment

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProfileSegment.allCases) { segment in
                Button {
                    withAnimation(AppPalette.springStandard) {
                        selected = segment
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(segment.label)
                            .font(.inter(.medium, size: 15))
                            .foregroundStyle(selected == segment ? AppPalette.text : AppPalette.secondaryText)
                        Rectangle()
                            .fill(selected == segment ? AppPalette.lavender : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(AppPalette.card)
    }
}

private struct ProfilePostsGrid: View {
    let posts: [Post]
    let onTap: (Post) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        if posts.isEmpty {
            placeholder(text: "Posts will appear here")
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(posts) { post in
                    Button {
                        onTap(post)
                    } label: {
                        thumbnail(for: post, height: 110)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct SavedPostsGrid: View {
    let savedPosts: [Post]
    let onTap: (Post) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        if savedPosts.isEmpty {
            placeholder(text: "Posts you save will appear here")
        } else {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(savedPosts) { post in
                    Button {
                        onTap(post)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            thumbnail(for: post, height: 160)
                            Text(post.title)
                                .font(.inter(.semibold, size: 13))
                                .foregroundStyle(AppPalette.text)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct LikedArtistsList: View {
    let artists: [Artist]
    let onUnfollow: (UUID) -> Void

    var body: some View {
        if artists.isEmpty {
            placeholder(text: "Artists you connect with will appear here")
        } else {
            VStack(spacing: 10) {
                ForEach(artists) { artist in
                    HStack(spacing: 12) {
                        AvatarView(colorHex: artist.avatarColorHex, initials: artist.initials, size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(artist.name)
                                .font(.inter(.semibold, size: 14))
                                .foregroundStyle(AppPalette.text)
                            Text("\(artist.genres.map(\.label).joined(separator: " • ")) • \(artist.city)")
                                .font(.inter(.regular, size: 12))
                                .foregroundStyle(AppPalette.secondaryText)
                        }
                        Spacer()
                        Button("Unfollow") {
                            onUnfollow(artist.id)
                        }
                        .font(.inter(.medium, size: 12))
                        .foregroundStyle(AppPalette.tertiaryText)
                    }
                    .padding(12)
                    .background(AppPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

@ViewBuilder
private func thumbnail(for post: Post, height: CGFloat) -> some View {
    if let data = post.coverImageData, let image = UIImage(data: data) {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    } else {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppPalette.card)
            .frame(height: height)
            .overlay(
                Image(systemName: "photo.on.rectangle")
                    .foregroundStyle(AppPalette.secondaryText)
            )
    }
}

@ViewBuilder
private func placeholder(text: String) -> some View {
    VStack {
        Spacer(minLength: 40)
        Text(text)
            .font(.inter(.regular, size: 14))
            .foregroundStyle(AppPalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        Spacer(minLength: 40)
    }
    .padding(.vertical, 40)
}

// MARK: - Create Post Sheet

private struct CreatePostDraft {
    let title: String
    let genre: Genre
    let mood: Mood
    let story: String
    let coverImageData: Data?
    let audioURL: URL?
    let audioTitle: String?
    let audioDuration: TimeInterval?
    let bloopers: [BlooperItem]
    let trackVersions: [TrackVersion]
    let isLandscape: Bool
}

private struct CreatePostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var title = ""
    @State private var selectedGenre: Genre?
    @State private var selectedMood: Mood?
    @State private var story = ""
    @State private var audioURL: URL?
    @State private var audioTitle: String?
    @State private var audioDuration: TimeInterval?
    @State private var showingAudioPicker = false
    @State private var blooperPickerItems: [PhotosPickerItem] = []
    @State private var bloopers: [BlooperItem] = []
    @State private var trackVersions: [TrackVersion] = []
    @State private var showingAddVersionSheet = false
    @State private var isLandscape = false

    let onPost: (CreatePostDraft) -> Void

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedGenre != nil &&
        selectedMood != nil &&
        story.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppPalette.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Create Post")
                        .font(.inter(.bold, size: 28))
                        .foregroundStyle(AppPalette.text)
                        .padding(.top, 56)

                    LabeledField(label: "Cover Image") {
                        PhotosPicker(selection: $coverPickerItem, matching: .images) {
                            HStack {
                                Image(systemName: coverImageData == nil ? "photo" : "photo.fill")
                                Text(coverImageData == nil ? "Pick cover photo" : "Photo selected")
                                Spacer()
                                if coverImageData != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppPalette.sage)
                                }
                            }
                            .font(.inter(.medium, size: 14))
                            .foregroundStyle(AppPalette.text)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppPalette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    LabeledField(label: "Title") {
                        TextField("Enter title", text: $title)
                            .font(.inter(.regular, size: 14))
                            .foregroundStyle(AppPalette.text)
                            .padding(12)
                            .background(AppPalette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    LabeledField(label: "Genre") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Genre.selectableCases) { genre in
                                    SelectChip(
                                        text: genre.label,
                                        selected: selectedGenre == genre
                                    ) { selectedGenre = genre }
                                }
                            }
                        }
                    }

                    LabeledField(label: "Mood") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Mood.allCases) { mood in
                                    SelectChip(
                                        text: mood.label,
                                        selected: selectedMood == mood
                                    ) { selectedMood = mood }
                                }
                            }
                        }
                    }

                    Toggle(isOn: $isLandscape) {
                        Text("Landscape format")
                            .font(.inter(.medium, size: 14))
                            .foregroundStyle(AppPalette.text)
                    }
                    .tint(AppPalette.lavender)

                    LabeledField(label: "Story") {
                        TextEditor(text: $story)
                            .font(.inter(.regular, size: 14))
                            .foregroundStyle(AppPalette.text)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(AppPalette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.system(size: 18))
                            .foregroundStyle(AppPalette.lavender)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Track")
                                .font(.inter(.regular, size: 15))
                                .foregroundStyle(AppPalette.text)

                            if let audioTitle {
                                HStack(spacing: 6) {
                                    Text(audioTitle)
                                        .font(.inter(.regular, size: 12))
                                        .foregroundStyle(AppPalette.sage)
                                        .lineLimit(1)

                                    Button {
                                        audioURL = nil
                                        self.audioTitle = nil
                                        audioDuration = nil
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(AppPalette.secondaryText)
                                            .frame(width: 18, height: 18)
                                            .background(AppPalette.trackBackground)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Text("optional — share your music")
                                    .font(.inter(.regular, size: 12))
                                    .foregroundStyle(AppPalette.secondaryText)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppPalette.secondaryText)
                    }
                    .padding(12)
                    .background(AppPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture {
                        showingAudioPicker = true
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Version History")
                            .font(.inter(.semibold, size: 14))
                            .foregroundStyle(AppPalette.text)

                        if !trackVersions.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(trackVersions) { version in
                                    HStack(spacing: 8) {
                                        Text(version.versionLabel)
                                            .font(.inter(.medium, size: 12))
                                            .foregroundStyle(AppPalette.lavender)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppPalette.trackBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                        Text(version.title)
                                            .font(.inter(.medium, size: 13))
                                            .foregroundStyle(AppPalette.text)
                                            .lineLimit(1)

                                        Spacer()

                                        Button {
                                            trackVersions.removeAll { $0.id == version.id }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(AppPalette.secondaryText)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(10)
                                    .background(AppPalette.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }

                        Button {
                            showingAddVersionSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppPalette.lavender)
                                Text("Add another version")
                                    .font(.inter(.medium, size: 14))
                                    .foregroundStyle(AppPalette.lavender)
                                Spacer()
                            }
                            .padding(12)
                            .background(AppPalette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("🎬")
                                    .font(.system(size: 15))
                                Text("Behind the Scenes")
                                    .font(.inter(.regular, size: 15))
                                    .foregroundStyle(AppPalette.text)
                            }
                            Text("add bloopers — optional")
                                .font(.inter(.regular, size: 12))
                                .foregroundStyle(AppPalette.secondaryText)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                if bloopers.count < 6 {
                                    PhotosPicker(
                                        selection: $blooperPickerItems,
                                        maxSelectionCount: 6 - bloopers.count,
                                        matching: .images
                                    ) {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(AppPalette.trackBackground)
                                            .frame(width: 100, height: 120)
                                            .overlay(
                                                Image(systemName: "plus")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(AppPalette.tertiaryText)
                                            )
                                    }
                                }

                                ForEach(Array(bloopers.enumerated()), id: \.element.id) { index, item in
                                    VStack(spacing: 6) {
                                        ZStack(alignment: .topTrailing) {
                                            Group {
                                                if let data = item.imageData, let image = UIImage(data: data) {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .scaledToFill()
                                                } else {
                                                    Rectangle()
                                                        .fill(AppPalette.trackBackground)
                                                }
                                            }
                                            .frame(width: 100, height: 120)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                            Button {
                                                bloopers.removeAll { $0.id == item.id }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(AppPalette.text)
                                                    .frame(width: 20, height: 20)
                                                    .background(AppPalette.card)
                                                    .clipShape(Circle())
                                            }
                                            .buttonStyle(.plain)
                                            .padding(6)
                                        }

                                        TextField(
                                            "",
                                            text: Binding(
                                                get: { bloopers[index].caption ?? "" },
                                                set: { bloopers[index].caption = $0.isEmpty ? nil : $0 }
                                            ),
                                            prompt: Text("add caption...")
                                                .foregroundColor(AppPalette.tertiaryText)
                                        )
                                        .font(.inter(.regular, size: 11))
                                        .foregroundStyle(AppPalette.text)
                                        .frame(width: 100)
                                    }
                                }
                            }
                        }
                    }

                    if !isFormValid {
                        Text("story is required before posting")
                            .font(.inter(.medium, size: 13))
                            .foregroundStyle(AppPalette.peach)
                            .padding(.bottom, 30)
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppPalette.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(AppPalette.trackBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    guard
                        isFormValid,
                        let selectedGenre,
                        let selectedMood
                    else { return }
                    onPost(
                        CreatePostDraft(
                            title: title,
                            genre: selectedGenre,
                            mood: selectedMood,
                            story: story,
                            coverImageData: coverImageData,
                            audioURL: audioURL,
                            audioTitle: audioTitle,
                            audioDuration: audioDuration,
                            bloopers: bloopers,
                            trackVersions: trackVersions,
                            isLandscape: isLandscape
                        )
                    )
                    dismiss()
                } label: {
                    Text("Post")
                        .font(.inter(.semibold, size: 14))
                        .foregroundStyle(isFormValid ? AppPalette.background : AppPalette.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isFormValid ? AppPalette.lavender : AppPalette.card)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!isFormValid)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .task(id: coverPickerItem) {
            if let coverPickerItem,
               let data = try? await coverPickerItem.loadTransferable(type: Data.self) {
                coverImageData = data
            }
        }
        .task(id: blooperPickerItems) {
            guard !blooperPickerItems.isEmpty else { return }
            for item in blooperPickerItems {
                guard bloopers.count < 6 else { break }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    bloopers.append(BlooperItem(imageData: data, caption: nil))
                }
            }
            blooperPickerItems = []
        }
        .sheet(isPresented: $showingAudioPicker) {
            AudioDocumentPicker { url in
                audioURL = url
                audioTitle = url.deletingPathExtension().lastPathComponent
                let asset = AVURLAsset(url: url)
                audioDuration = CMTimeGetSeconds(asset.duration)
            }
        }
        .sheet(isPresented: $showingAddVersionSheet) {
            AddVersionSheet { version in
                trackVersions.append(version)
            }
        }
    }
}

private struct AddVersionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var versionLabel = ""
    @State private var versionTitle = ""
    @State private var audioURL: URL?
    @State private var audioDuration: TimeInterval = 214
    @State private var showingAudioPicker = false

    let onAdd: (TrackVersion) -> Void

    var body: some View {
        ZStack {
            AppPalette.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.inter(.medium, size: 14))
                        .foregroundStyle(AppPalette.secondaryText)
                    Spacer()
                    Text("Add Version")
                        .font(.inter(.semibold, size: 16))
                        .foregroundStyle(AppPalette.text)
                    Spacer()
                    Button("Add") {
                        onAdd(
                            TrackVersion(
                                title: versionTitle,
                                duration: audioDuration,
                                audioURL: audioURL,
                                versionLabel: versionLabel
                            )
                        )
                        dismiss()
                    }
                    .font(.inter(.semibold, size: 14))
                    .foregroundStyle(AppPalette.lavender)
                    .disabled(versionLabel.trimmingCharacters(in: .whitespaces).isEmpty || versionTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 20)

                LabeledField(label: "Version Label") {
                    TextField("e.g. Demo v1", text: $versionLabel)
                        .font(.inter(.regular, size: 14))
                        .foregroundStyle(AppPalette.text)
                        .padding(12)
                        .background(AppPalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                LabeledField(label: "Title") {
                    TextField("Track title", text: $versionTitle)
                        .font(.inter(.regular, size: 14))
                        .foregroundStyle(AppPalette.text)
                        .padding(12)
                        .background(AppPalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    showingAudioPicker = true
                } label: {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(AppPalette.lavender)
                        Text(audioURL == nil ? "Pick audio file" : "Audio selected")
                            .font(.inter(.medium, size: 14))
                            .foregroundStyle(AppPalette.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppPalette.secondaryText)
                    }
                    .padding(12)
                    .background(AppPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAudioPicker) {
            AudioDocumentPicker { url in
                audioURL = url
                let seconds = CMTimeGetSeconds(AVURLAsset(url: url).duration)
                audioDuration = seconds.isFinite && seconds > 0 ? seconds : 214
            }
        }
    }
}

// MARK: - Audio Document Picker

private struct AudioDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

// MARK: - Audio Player Manager

final class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerManager()

    @Published var isPlaying: Bool = false
    @Published var currentPostID: UUID?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackProgress: Double = 0

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    private override init() {
        super.init()
    }

    func toggle(url: URL, postID: UUID, title: String, duration: TimeInterval) {
        if currentPostID == postID {
            if isPlaying {
                pause()
            } else {
                resume()
            }
        } else {
            play(url: url, postID: postID, title: title, duration: duration)
        }
    }

    func play(url: URL, postID: UUID) {
        play(url: url, postID: postID, title: "", duration: 0)
    }

    func play(url: URL, postID: UUID, title: String, duration fallbackDuration: TimeInterval) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            currentPostID = postID
            isPlaying = true
            duration = player?.duration ?? fallbackDuration
            currentTime = 0
            playbackProgress = 0
            startProgressTimer()
        } catch {
            print("Audio error: \(error)")
            currentPostID = nil
            isPlaying = false
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
    }

    func resume() {
        player?.play()
        isPlaying = true
        startProgressTimer()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentPostID = nil
        currentTime = 0
        duration = 0
        playbackProgress = 0
        stopProgressTimer()
    }

    func seekToTime(_ time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(0, time), player.duration)
        currentTime = player.currentTime
        if player.duration > 0 {
            playbackProgress = player.currentTime / player.duration
        }
    }

    func seek(to progress: Double) {
        guard let player, player.duration > 0 else { return }
        let clamped = min(1, max(0, progress))
        seekToTime(clamped * player.duration)
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            DispatchQueue.main.async {
                self.currentTime = player.currentTime
                if player.duration > 0 {
                    self.duration = player.duration
                    self.playbackProgress = player.currentTime / player.duration
                }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.playbackProgress = 0
            self.currentPostID = nil
            self.stopProgressTimer()
        }
    }
}

// MARK: - Shared Components

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.inter(.semibold, size: 14))
                .foregroundStyle(AppPalette.text)
            content
        }
    }
}

private struct SelectChip: View {
    let text: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.inter(.medium, size: 13))
                .foregroundStyle(selected ? AppPalette.background : AppPalette.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? AppPalette.lavender : AppPalette.card)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct Chip: View {
    let text: String
    let background: Color
    let foreground: Color

    var body: some View {
        Text(text)
            .font(.inter(.medium, size: 12))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background)
            .clipShape(Capsule())
    }
}

private struct AvatarView: View {
    let colorHex: String
    let initials: String
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.inter(.bold, size: size * 0.34))
                    .foregroundStyle(AppPalette.background)
            )
    }
}

// MARK: - Models

private struct Artist: Identifiable, Hashable {
    let id: UUID
    let name: String
    let city: String
    let genres: [Genre]
    let isFoundingArtist: Bool
    let bannerColorHex: String
    let avatarColorHex: String
    let bio: String
    let followerCount: Int

    var initials: String {
        name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
    }

    var bannerColor: Color {
        Color(hex: bannerColorHex)
    }
}

private struct Post: Identifiable, Hashable {
    let id: UUID
    let artistID: UUID
    let title: String
    let caption: String
    let genre: Genre
    let mood: Mood
    let hashtags: [String]
    let coverHeight: CGFloat
    var coverImageData: Data?
    var audioURL: URL?
    var audioTitle: String?
    var audioDuration: TimeInterval?
    var bloopers: [BlooperItem]
    var trackVersions: [TrackVersion]
    var isLandscape: Bool

    var hasAudio: Bool {
        audioURL != nil || audioTitle != nil
    }
}

struct TrackVersion: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var title: String
    var duration: TimeInterval
    var audioURL: URL?
    var versionLabel: String
}

struct BlooperItem: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var imageData: Data?
    var caption: String?
}

private struct Comment: Identifiable, Hashable {
    let id: UUID
    let username: String
    let text: String
    let isArtistComment: Bool

    var initials: String {
        String(username.prefix(2)).uppercased()
    }
}

private enum Genre: String, CaseIterable, Identifiable {
    case all = "All"
    case electronic = "Electronic"
    case indie = "Indie"
    case hipHop = "Hip-Hop"
    case rnb = "R&B"
    case ambient = "Ambient"
    case techno = "Techno"

    var id: String { rawValue }
    var label: String { rawValue }

    static var selectableCases: [Genre] {
        allCases.filter { $0 != .all }
    }
}

private enum Mood: String, CaseIterable, Identifiable {
    case lateNight = "latenight"
    case raw = "raw"
    case process = "process"
    case introspective = "introspective"

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

// MARK: - Seed Data

// MARK: - Seed Data Helpers

private func colorPlaceholderImage(_ color: UIColor, size: CGSize = CGSize(width: 150, height: 190)) -> Data? {
    UIGraphicsBeginImageContext(size)
    color.setFill()
    UIRectFill(CGRect(origin: .zero, size: size))
    let img = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return img?.jpegData(compressionQuality: 0.8)
}

private func makeTestBloopers() -> [BlooperItem] {
    [
        BlooperItem(
            imageData: colorPlaceholderImage(UIColor(red: 0.2, green: 0.1, blue: 0.3, alpha: 1)),
            caption: "studio setup"
        ),
        BlooperItem(
            imageData: colorPlaceholderImage(UIColor(red: 0.1, green: 0.2, blue: 0.2, alpha: 1)),
            caption: "first take"
        ),
        BlooperItem(
            imageData: colorPlaceholderImage(UIColor(red: 0.3, green: 0.15, blue: 0.1, alpha: 1)),
            caption: "the original idea"
        )
    ]
}

private func makeSeedAudio() -> (URL?, String?, TimeInterval?) {
    let candidates = ["demo_track", "sample", "track"]
    let extensions = ["mp3", "m4a", "wav"]

    for name in candidates {
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                let seconds = CMTimeGetSeconds(AVURLAsset(url: url).duration)
                if seconds.isFinite, seconds > 0 {
                    return (url, "late night session", seconds)
                }
            }
        }
    }

    return (nil, "late night session", 214)
}

private func makeTestTrackVersions() -> [TrackVersion] {
    [
        TrackVersion(title: "late night session", duration: 214, versionLabel: "Final Mix"),
        TrackVersion(title: "late night session", duration: 187, versionLabel: "Demo v1"),
        TrackVersion(title: "late night — acoustic", duration: 198, versionLabel: "Acoustic")
    ]
}

private enum SeedData {
    static let userCity = "Sydney"
    static let currentArtist = artists[6]

    static let artists: [Artist] = [
        Artist(id: UUID(), name: "Maya Chen", city: "Melbourne", genres: [.electronic], isFoundingArtist: true, bannerColorHex: "3E345F", avatarColorHex: "C9B8E8", bio: "Late-night synth loops and process notes from Melbourne.", followerCount: 480),
        Artist(id: UUID(), name: "The Drift", city: "Sydney", genres: [.indie, .ambient], isFoundingArtist: false, bannerColorHex: "2A413A", avatarColorHex: "9AC2AE", bio: "Tape recordings and quiet rooms.", followerCount: 124),
        Artist(id: UUID(), name: "Solaris", city: "Melbourne", genres: [.rnb], isFoundingArtist: true, bannerColorHex: "5D4338", avatarColorHex: "E2B698", bio: "Slow R&B vocals about belonging.", followerCount: 612),
        Artist(id: UUID(), name: "Neon Atlas", city: "Brisbane", genres: [.hipHop], isFoundingArtist: false, bannerColorHex: "38465D", avatarColorHex: "A9BFE2", bio: "City-frame hip-hop. Verses drafted on trains.", followerCount: 245),
        Artist(id: UUID(), name: "Juni Wolf", city: "Melbourne", genres: [.ambient], isFoundingArtist: false, bannerColorHex: "4C395B", avatarColorHex: "D2B8E8", bio: "Field recordings and patient layers.", followerCount: 88),
        Artist(id: UUID(), name: "Pulse", city: "Adelaide", genres: [.techno], isFoundingArtist: false, bannerColorHex: "324457", avatarColorHex: "9FBAD4", bio: "Subfloor techno drafts.", followerCount: 53),
        Artist(id: UUID(), name: "Ari Kade", city: "Sydney", genres: [.electronic], isFoundingArtist: false, bannerColorHex: "4A3A61", avatarColorHex: "C9B8E8", bio: "Cinematic synth pieces from Sydney streets.", followerCount: 36),
        Artist(id: UUID(), name: "Luma Rae", city: "Perth", genres: [.indie], isFoundingArtist: false, bannerColorHex: "364A3D", avatarColorHex: "A8CFB2", bio: "Layered harmonies, minimal percussion.", followerCount: 22)
    ]

    static let posts: [Post] = {
        let seedAudio = makeSeedAudio()
        let testBloopers = makeTestBloopers()
        let testVersions = makeTestTrackVersions()

        return [
        Post(
            id: UUID(),
            artistID: artists[0].id,
            title: "Signal Loops at 2AM",
            caption: "A late-night set built from rough synth passes and ambient street recordings. This version keeps all the texture and imperfections.",
            genre: .electronic,
            mood: .lateNight,
            hashtags: ["latenight", "synths"],
            coverHeight: 170,
            coverImageData: nil,
            audioURL: seedAudio.0,
            audioTitle: seedAudio.1,
            audioDuration: seedAudio.2,
            bloopers: testBloopers,
            trackVersions: testVersions,
            isLandscape: false
        ),
        Post(
            id: UUID(),
            artistID: artists[1].id,
            title: "Tape Hiss Session",
            caption: "One take, no polish. We left the hiss and room noise in because it felt honest and alive.",
            genre: .indie,
            mood: .raw,
            hashtags: ["raw", "demo"],
            coverHeight: 220,
            coverImageData: nil,
            audioURL: seedAudio.0,
            audioTitle: seedAudio.1,
            audioDuration: seedAudio.2,
            bloopers: testBloopers,
            trackVersions: testVersions,
            isLandscape: true
        ),
        Post(
            id: UUID(),
            artistID: artists[2].id,
            title: "Soft Orbit",
            caption: "A slow vocal draft about belonging, with long pauses and gentle pads to let each line breathe.",
            genre: .rnb,
            mood: .introspective,
            hashtags: ["vocals", "orbit"],
            coverHeight: 185,
            coverImageData: nil,
            audioURL: nil,
            audioTitle: nil,
            audioDuration: nil,
            bloopers: [],
            trackVersions: [],
            isLandscape: false
        ),
        Post(
            id: UUID(),
            artistID: artists[3].id,
            title: "City Frame Cypher",
            caption: "Verses drafted across train rides and station platforms. The rhythm follows the movement of the city.",
            genre: .hipHop,
            mood: .process,
            hashtags: ["city", "cypher"],
            coverHeight: 235,
            coverImageData: nil,
            audioURL: nil,
            audioTitle: nil,
            audioDuration: nil,
            bloopers: [],
            trackVersions: [],
            isLandscape: true
        ),
        Post(
            id: UUID(),
            artistID: artists[4].id,
            title: "Room Tone Diaries",
            caption: "Built from room tone, guitar harmonics, and whispered notes. Intimate and intentionally sparse.",
            genre: .ambient,
            mood: .lateNight,
            hashtags: ["ambient", "roomtone"],
            coverHeight: 190,
            coverImageData: nil,
            audioURL: nil,
            audioTitle: nil,
            audioDuration: nil,
            bloopers: [],
            trackVersions: [],
            isLandscape: false
        ),
        Post(
            id: UUID(),
            artistID: artists[5].id,
            title: "Subfloor Draft",
            caption: "A heavy low-end sketch tested in small club systems. Sharing this while it still feels raw.",
            genre: .techno,
            mood: .raw,
            hashtags: ["club", "lowend"],
            coverHeight: 245,
            coverImageData: nil,
            audioURL: nil,
            audioTitle: nil,
            audioDuration: nil,
            bloopers: [],
            trackVersions: [],
            isLandscape: false
        ),
        Post(
            id: UUID(),
            artistID: artists[6].id,
            title: "Neon Memory",
            caption: "A cinematic synth piece inspired by empty streets after midnight and fading signage.",
            genre: .electronic,
            mood: .lateNight,
            hashtags: ["neon", "cinematic"],
            coverHeight: 180,
            coverImageData: nil,
            audioURL: nil,
            audioTitle: nil,
            audioDuration: nil,
            bloopers: [],
            trackVersions: [],
            isLandscape: true
        ),
        Post(
            id: UUID(),
            artistID: artists[7].id,
            title: "Shadow Chorus",
            caption: "Layered harmonies with minimal percussion. Focused on mood, depth, and emotional space.",
            genre: .indie,
            mood: .introspective,
            hashtags: ["chorus", "harmony"],
            coverHeight: 215,
            coverImageData: nil,
            audioURL: nil,
            audioTitle: nil,
            audioDuration: nil,
            bloopers: [],
            trackVersions: [],
            isLandscape: false
        )
    ]
    }()

    static let commentsByPost: [UUID: [Comment]] = {
        Dictionary(uniqueKeysWithValues: posts.map { post in
            (
                post.id,
                [
                    Comment(id: UUID(), username: "Nova", text: "This tone palette is unreal.", isArtistComment: false),
                    Comment(id: UUID(), username: artist(for: post.artistID).name, text: "Appreciate you listening. More soon.", isArtistComment: true)
                ]
            )
        })
    }()

    static func artist(for id: UUID) -> Artist {
        artists.first(where: { $0.id == id }) ?? artists[0]
    }
}

// MARK: - Palette / Helpers

private enum AppPalette {
    static let background = Color(hex: "0D0D10")
    static let card = Color(hex: "1A1A22")
    static let text = Color(hex: "F0F0F2")
    static let secondaryText = Color(hex: "A3A3B0")
    static let tertiaryText = Color(hex: "6E6E80")
    static let lavender = Color(hex: "C9B8E8")
    static let peach = Color(hex: "F2C4A0")
    static let sage = Color(hex: "B8D8C8")
    static let trackBackground = Color(hex: "2A2A35")
    static let barMuted = Color(hex: "484850")

    static let springStandard = Animation.spring(response: 0.4, dampingFraction: 0.75)
}

private extension UUID {
    static func encodeArray(_ ids: [UUID]) -> String {
        let strings = ids.map(\.uuidString)
        let data = (try? JSONEncoder().encode(strings)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func decodeArray(from value: String) -> [UUID] {
        guard
            let data = value.data(using: .utf8),
            let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return strings.compactMap(UUID.init(uuidString:))
    }
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
        return .custom(name, size: size)
    }
}

// MARK: - Helpers

private func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let total = Int(seconds)
    let minutes = total / 60
    let secs = total % 60
    return String(format: "%d:%02d", minutes, secs)
}

#Preview {
    ContentView()
}
