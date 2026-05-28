import PhotosUI
import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .feed
    @State private var selectedPost: Post?
    @State private var selectedArtist: Artist?
    @State private var showingCreateSheet = false
    @State private var showingSavedPosts = false
    @State private var posts: [Post] = SeedData.posts
    @State private var commentsByPost: [UUID: [Comment]] = SeedData.commentsByPost

    @AppStorage("underground.savedPostIDs") private var savedPostIDsStorage = "[]"
    @AppStorage("underground.followingArtistIDs") private var followingArtistIDsStorage = "[]"

    private var savedPostIDs: Set<UUID> {
        Set(UUID.decodeArray(from: savedPostIDsStorage))
    }

    private var followingArtistIDs: Set<UUID> {
        Set(UUID.decodeArray(from: followingArtistIDsStorage))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppPalette.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .feed:
                    FeedView(posts: posts, artists: SeedData.artists) { post in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedPost = post
                        }
                    } onArtistTap: { artist in
                        selectedArtist = artist
                    }
                case .discover:
                    DiscoverView(
                        artists: SeedData.artists,
                        collabRequests: SeedData.collabRequests,
                        onArtistTap: { selectedArtist = $0 }
                    )
                case .profile:
                    ProfileTabView(
                        artist: SeedData.currentArtist,
                        posts: posts.filter { $0.artistID == SeedData.currentArtist.id },
                        followingArtistIDs: followingArtistIDs,
                        savedPosts: posts.filter { savedPostIDs.contains($0.id) },
                        showSavedPosts: { showingSavedPosts = true }
                    ) { artistID in
                        toggleFollow(artistID: artistID)
                    }
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
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.selectedPost = nil
                        }
                    },
                    onSaveTap: { toggleSaved(postID: selectedPost.id) },
                    onArtistTap: { selectedArtist = $0 },
                    onAddComment: { text in
                        addComment(to: selectedPost.id, body: text)
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(2)
            }

            if let selectedArtist {
                ArtistProfileView(
                    artist: selectedArtist,
                    posts: posts.filter { $0.artistID == selectedArtist.id },
                    isFollowing: followingArtistIDs.contains(selectedArtist.id),
                    onBack: { self.selectedArtist = nil },
                    onToggleFollow: { toggleFollow(artistID: selectedArtist.id) }
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
                    coverColorHex: "6D5FA8",
                    coverHeight: 220,
                    visualStyleIndex: posts.count % 8
                )
                posts.insert(newPost, at: 0)
                commentsByPost[newPost.id] = []
            }
        }
        .sheet(isPresented: $showingSavedPosts) {
            SavedPostsView(
                savedPosts: posts.filter { savedPostIDs.contains($0.id) },
                artists: SeedData.artists
            )
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
    let artists: [Artist]
    let onSelect: (Post) -> Void
    let onArtistTap: (Artist) -> Void
    @State private var selectedGenre: Genre = .all

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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
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
                }
                .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Genre.allCases) { genre in
                            Button {
                                selectedGenre = genre
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
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(leftColumn) { post in
                            if let artist = artists.first(where: { $0.id == post.artistID }) {
                                PostCardView(post: post, artist: artist, onTap: onSelect, onArtistTap: onArtistTap)
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(rightColumn) { post in
                            if let artist = artists.first(where: { $0.id == post.artistID }) {
                                PostCardView(post: post, artist: artist, onTap: onSelect, onArtistTap: onArtistTap)
                            }
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
    let artist: Artist
    let onTap: (Post) -> Void
    let onArtistTap: (Artist) -> Void
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
                AstralAnimationView(style: post.visualStyleIndex % 8)
                    .frame(height: post.coverHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .scaleEffect(pressed ? 0.97 : 1.0)

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
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(post.coverColor)
                        .frame(height: 270)

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
    }
}

private struct DiscoverView: View {
    let artists: [Artist]
    let collabRequests: [CollabRequest]
    let onArtistTap: (Artist) -> Void
    @State private var query = ""
    @State private var showingDMForName = ""
    @State private var showingDMAlert = false

    private var filteredArtists: [Artist] {
        guard !query.isEmpty else { return artists }
        return artists.filter { artist in
            artist.name.localizedCaseInsensitiveContains(query) ||
            artist.genres.map(\.label).joined(separator: " ").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Discover")
                    .font(.inter(.bold, size: 30))
                    .foregroundStyle(AppPalette.text)
                    .padding(.top, 8)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppPalette.secondaryText)
                    TextField("Search by artist or genre", text: $query)
                        .font(.inter(.regular, size: 14))
                        .foregroundStyle(AppPalette.text)
                }
                .padding(12)
                .background(AppPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                ForEach(filteredArtists) { artist in
                    Button {
                        onArtistTap(artist)
                    } label: {
                        HStack(spacing: 10) {
                            AvatarView(colorHex: artist.avatarColorHex, initials: artist.initials, size: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(artist.name)
                                    .font(.inter(.semibold, size: 15))
                                    .foregroundStyle(AppPalette.text)
                                Text(artist.genres.map(\.label).joined(separator: " • "))
                                    .font(.inter(.regular, size: 12))
                                    .foregroundStyle(AppPalette.secondaryText)
                            }
                            Spacer()
                            if artist.city == "Sydney" {
                                Chip(text: "Sydney Local", background: AppPalette.sage, foreground: AppPalette.background)
                            }
                        }
                        .padding(12)
                        .background(AppPalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Text("Collab Board")
                    .font(.inter(.semibold, size: 18))
                    .foregroundStyle(AppPalette.text)
                    .padding(.top, 4)

                ForEach(collabRequests) { request in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(request.artistName)
                            .font(.inter(.semibold, size: 15))
                            .foregroundStyle(AppPalette.text)
                        Text("\(request.genre.label) • \(request.city)")
                            .font(.inter(.regular, size: 12))
                            .foregroundStyle(AppPalette.secondaryText)
                        Text(request.lookingFor)
                            .font(.inter(.regular, size: 14))
                            .foregroundStyle(AppPalette.text)
                        Button("Connect") {
                            showingDMForName = request.artistName
                            showingDMAlert = true
                        }
                        .font(.inter(.semibold, size: 13))
                        .foregroundStyle(AppPalette.lavender)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .alert("DM Thread Opened", isPresented: $showingDMAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Connected with \(showingDMForName).")
        }
    }
}

private struct ProfileTabView: View {
    let artist: Artist
    let posts: [Post]
    let followingArtistIDs: Set<UUID>
    let savedPosts: [Post]
    let showSavedPosts: () -> Void
    let onToggleFollow: (UUID) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
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

                    HStack(spacing: 8) {
                        ForEach(artist.genres) { genre in
                            Chip(text: genre.label, background: AppPalette.card, foreground: AppPalette.text)
                        }
                    }

                    if artist.isFoundingArtist {
                        Chip(text: "Founding Artist", background: AppPalette.lavender, foreground: AppPalette.background)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            onToggleFollow(artist.id)
                        }
                    } label: {
                        Text(followingArtistIDs.contains(artist.id) ? "Following" : "Follow")
                            .font(.inter(.semibold, size: 15))
                            .foregroundStyle(followingArtistIDs.contains(artist.id) ? AppPalette.text : AppPalette.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(followingArtistIDs.contains(artist.id) ? AppPalette.card : AppPalette.lavender)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button("Saved Posts") {
                        showSavedPosts()
                    }
                    .font(.inter(.medium, size: 14))
                    .foregroundStyle(AppPalette.lavender)
                }
                .padding(16)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(posts) { post in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(post.coverColor)
                            .frame(height: 92)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct ArtistProfileView: View {
    let artist: Artist
    let posts: [Post]
    let isFollowing: Bool
    let onBack: () -> Void
    let onToggleFollow: () -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

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
            .padding(.bottom, 8)

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

                        HStack(spacing: 8) {
                            ForEach(artist.genres) { genre in
                                Chip(text: genre.label, background: AppPalette.card, foreground: AppPalette.text)
                            }
                        }

                        if artist.isFoundingArtist {
                            Chip(text: "Founding Artist", background: AppPalette.lavender, foreground: AppPalette.background)
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
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
                    }
                    .padding(16)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(posts) { post in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(post.coverColor)
                                .frame(height: 92)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppPalette.background.ignoresSafeArea())
    }
}

private struct SavedPostsView: View {
    let savedPosts: [Post]
    let artists: [Artist]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(savedPosts) { post in
                        let artist = artists.first { $0.id == post.artistID }
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(post.coverColor)
                                .frame(width: 74, height: 74)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.title)
                                    .font(.inter(.semibold, size: 15))
                                    .foregroundStyle(AppPalette.text)
                                Text(artist?.name ?? "Unknown Artist")
                                    .font(.inter(.regular, size: 13))
                                    .foregroundStyle(AppPalette.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(AppPalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(16)
            }
            .background(AppPalette.background)
            .navigationTitle("Saved Posts")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct CreatePostSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var title = ""
    @State private var selectedGenre: Genre?
    @State private var selectedMood: Mood?
    @State private var story = ""

    let onPost: (CreatePostDraft) -> Void

    private var isFormValid: Bool {
        selectedPhoto != nil &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedGenre != nil &&
        selectedMood != nil &&
        story.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Create Post")
                        .font(.inter(.bold, size: 28))
                        .foregroundStyle(AppPalette.text)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text(selectedPhoto == nil ? "Pick cover photo" : "Photo selected")
                        }
                        .font(.inter(.medium, size: 14))
                        .foregroundStyle(AppPalette.text)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppPalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

                    if !isFormValid {
                        Text("story is required before posting")
                            .font(.inter(.medium, size: 13))
                            .foregroundStyle(AppPalette.peach)
                    }

                    Button("Post") {
                        guard
                            let selectedGenre,
                            let selectedMood
                        else { return }
                        onPost(
                            CreatePostDraft(
                                title: title,
                                genre: selectedGenre,
                                mood: selectedMood,
                                story: story
                            )
                        )
                        dismiss()
                    }
                    .font(.inter(.semibold, size: 15))
                    .foregroundStyle(isFormValid ? AppPalette.background : AppPalette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isFormValid ? AppPalette.lavender : AppPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(!isFormValid)
                }
                .padding(16)
            }
            .background(AppPalette.background)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
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
                        selectedTab = tab
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

private struct CreatePostDraft {
    let title: String
    let genre: Genre
    let mood: Mood
    let story: String
}

private struct Artist: Identifiable, Hashable {
    let id: UUID
    let name: String
    let city: String
    let genres: [Genre]
    let isFoundingArtist: Bool
    let bannerColorHex: String
    let avatarColorHex: String

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
    let coverColorHex: String
    let coverHeight: CGFloat
    let visualStyleIndex: Int

    var coverColor: Color {
        Color(hex: coverColorHex)
    }
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

private struct CollabRequest: Identifiable, Hashable {
    let id: UUID
    let artistName: String
    let genre: Genre
    let city: String
    let lookingFor: String
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

private enum SeedData {
    static let currentArtist = artists[0]

    static let artists: [Artist] = [
        Artist(id: UUID(), name: "Maya Chen", city: "Melbourne", genres: [.electronic], isFoundingArtist: true, bannerColorHex: "3E345F", avatarColorHex: "C9B8E8"),
        Artist(id: UUID(), name: "The Drift", city: "Sydney", genres: [.indie, .ambient], isFoundingArtist: false, bannerColorHex: "2A413A", avatarColorHex: "9AC2AE"),
        Artist(id: UUID(), name: "Solaris", city: "Melbourne", genres: [.rnb], isFoundingArtist: true, bannerColorHex: "5D4338", avatarColorHex: "E2B698"),
        Artist(id: UUID(), name: "Neon Atlas", city: "Brisbane", genres: [.hipHop], isFoundingArtist: false, bannerColorHex: "38465D", avatarColorHex: "A9BFE2"),
        Artist(id: UUID(), name: "Juni Wolf", city: "Melbourne", genres: [.ambient], isFoundingArtist: false, bannerColorHex: "4C395B", avatarColorHex: "D2B8E8"),
        Artist(id: UUID(), name: "Pulse", city: "Adelaide", genres: [.techno], isFoundingArtist: false, bannerColorHex: "324457", avatarColorHex: "9FBAD4"),
        Artist(id: UUID(), name: "Ari Kade", city: "Sydney", genres: [.electronic], isFoundingArtist: false, bannerColorHex: "4A3A61", avatarColorHex: "C9B8E8"),
        Artist(id: UUID(), name: "Luma Rae", city: "Perth", genres: [.indie], isFoundingArtist: false, bannerColorHex: "364A3D", avatarColorHex: "A8CFB2")
    ]

    static let posts: [Post] = [
        Post(id: UUID(), artistID: artists[0].id, title: "Signal Loops at 2AM", caption: "A late-night set built from rough synth passes and ambient street recordings. This version keeps all the texture and imperfections.", genre: .electronic, mood: .lateNight, hashtags: ["latenight", "synths"], coverColorHex: "6D5FA8", coverHeight: 170, visualStyleIndex: 0),
        Post(id: UUID(), artistID: artists[1].id, title: "Tape Hiss Session", caption: "One take, no polish. We left the hiss and room noise in because it felt honest and alive.", genre: .indie, mood: .raw, hashtags: ["raw", "demo"], coverColorHex: "618A7B", coverHeight: 220, visualStyleIndex: 1),
        Post(id: UUID(), artistID: artists[2].id, title: "Soft Orbit", caption: "A slow vocal draft about belonging, with long pauses and gentle pads to let each line breathe.", genre: .rnb, mood: .introspective, hashtags: ["vocals", "orbit"], coverColorHex: "B3876A", coverHeight: 185, visualStyleIndex: 2),
        Post(id: UUID(), artistID: artists[3].id, title: "City Frame Cypher", caption: "Verses drafted across train rides and station platforms. The rhythm follows the movement of the city.", genre: .hipHop, mood: .process, hashtags: ["city", "cypher"], coverColorHex: "7588A6", coverHeight: 235, visualStyleIndex: 3),
        Post(id: UUID(), artistID: artists[4].id, title: "Room Tone Diaries", caption: "Built from room tone, guitar harmonics, and whispered notes. Intimate and intentionally sparse.", genre: .ambient, mood: .lateNight, hashtags: ["ambient", "roomtone"], coverColorHex: "8A6A9E", coverHeight: 190, visualStyleIndex: 4),
        Post(id: UUID(), artistID: artists[5].id, title: "Subfloor Draft", caption: "A heavy low-end sketch tested in small club systems. Sharing this while it still feels raw.", genre: .techno, mood: .raw, hashtags: ["club", "lowend"], coverColorHex: "5D7E9B", coverHeight: 245, visualStyleIndex: 5),
        Post(id: UUID(), artistID: artists[6].id, title: "Neon Memory", caption: "A cinematic synth piece inspired by empty streets after midnight and fading signage.", genre: .electronic, mood: .lateNight, hashtags: ["neon", "cinematic"], coverColorHex: "7E5E91", coverHeight: 180, visualStyleIndex: 6),
        Post(id: UUID(), artistID: artists[7].id, title: "Shadow Chorus", caption: "Layered harmonies with minimal percussion. Focused on mood, depth, and emotional space.", genre: .indie, mood: .introspective, hashtags: ["chorus", "harmony"], coverColorHex: "6D8A71", coverHeight: 215, visualStyleIndex: 7)
    ]

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

    static let collabRequests: [CollabRequest] = [
        CollabRequest(id: UUID(), artistName: "The Drift", genre: .indie, city: "Sydney", lookingFor: "Looking for a vocalist for a stripped live session."),
        CollabRequest(id: UUID(), artistName: "Pulse", genre: .techno, city: "Adelaide", lookingFor: "Need a visual artist for live projections."),
        CollabRequest(id: UUID(), artistName: "Solaris", genre: .rnb, city: "Melbourne", lookingFor: "Open to co-writing hooks with producers.")
    ]

    static func artist(for id: UUID) -> Artist {
        artists.first(where: { $0.id == id }) ?? artists[0]
    }
}

private enum AppPalette {
    static let background = Color(hex: "0D0D10")
    static let card = Color(hex: "1A1A22")
    static let text = Color(hex: "F0F0F2")
    static let secondaryText = Color(hex: "A3A3B0")
    static let lavender = Color(hex: "C9B8E8")
    static let peach = Color(hex: "F2C4A0")
    static let sage = Color(hex: "B8D8C8")
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
