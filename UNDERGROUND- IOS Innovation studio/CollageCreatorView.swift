import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Models

enum CollageElementType: Equatable {
    case image
    case text
    case audioSticker
    case sticker
    case colorBlock
}

struct CollageElement: Identifiable {
    var id: UUID = UUID()
    var type: CollageElementType
    var position: CGPoint
    var size: CGSize
    var rotation: Double = 0
    var scale: CGFloat = 1.0
    var zIndex: Double
    var isSelected: Bool = false

    var imageData: Data?
    var text: String?
    var textColor: Color = .white
    var textSize: CGFloat = 24
    var textWeight: Font.Weight = .regular
    var backgroundColor: Color = .clear
    var audioURL: URL?
    var audioTitle: String?
    var stickerName: String?
    var stickerColor: Color = Color(hex: "C9B8E8")
    var opacity: Double = 1.0
    var cornerRadius: CGFloat = 12
}

enum CollageBackground: Equatable {
    case dark
    case light
    case black
    case grain
    case gradient(startHex: String, endHex: String)
}

// MARK: - Collage Creator

struct CollageCreatorView: View {
    @Environment(\.dismiss) private var dismiss

    let onSaveToPosts: (Data) -> Void

    @State private var elements: [CollageElement] = []
    @State private var selectedElementID: UUID?
    @State private var canvasScale: CGFloat = 1.0
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasBackground: CollageBackground = .dark
    @State private var history: [[CollageElement]] = []

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showingPhotoPicker = false
    @State private var showingTextEditor = false
    @State private var showingAudioPicker = false
    @State private var showingStickerPicker = false
    @State private var showingColorPicker = false
    @State private var showingBackgroundPicker = false
    @State private var customBackgroundColor = Color(hex: "1A0040")
    @State private var showingCustomBackgroundPicker = false
    @State private var showingShareOptions = false
    @State private var showingActivityShare = false
    @State private var renderedShareImage: UIImage?

    @State private var newTextDraft = ""
    @State private var editingTextElementID: UUID?
    @State private var textEditDraft = ""
    @State private var textEditSize: Double = 24
    @State private var textEditBold = false
    @State private var textEditColor: Color = .white
    @State private var replacingImageElementID: UUID?
    @State private var replacePhotoItem: PhotosPickerItem?

    @State private var canvasSize: CGSize = .zero
    @State private var canvasPanStart: CGSize = .zero
    @State private var canvasMagnifyBase: CGFloat = 1.0
    @State private var liveMagnification: CGFloat = 1.0
    @State private var magnifyBaseScale: CGFloat = 1.0
    @State private var dragStartPositions: [UUID: CGPoint] = [:]
    @State private var playingAudioElementID: UUID?
    @State private var audioPlaybackProgress: Double = 0
    @State private var audioIsPlaying = false
    @State private var audioTimer: Timer?

    private var selectedElement: CollageElement? {
        guard let selectedElementID else { return nil }
        return elements.first { $0.id == selectedElementID }
    }

    var body: some View {
        ZStack {
            AppPalette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                GeometryReader { geo in
                    let size = geo.size
                    Color.clear
                        .onAppear { canvasSize = size }
                        .onChange(of: size) { _, newSize in canvasSize = newSize }

                    ZStack {
                        canvasBackgroundView(size: size)
                        dotGrid(size: size)

                        ForEach(elements.sorted(by: { $0.zIndex < $1.zIndex })) { element in
                            elementLayer(element, canvasSize: size)
                        }

                        if let selected = selectedElement {
                            selectionControls(for: selected, canvasSize: size)
                        }
                    }
                    .coordinateSpace(name: "collageSpace")
                    .scaleEffect(canvasScale)
                    .offset(canvasOffset)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(canvasPanGesture)
                    .simultaneousGesture(canvasMagnificationGesture)
                    .onTapGesture {
                        selectedElementID = nil
                    }
                }

                toolbar
            }
        }
        .preferredColorScheme(.dark)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoPickerItems, maxSelectionCount: 20, matching: .images)
        .onChange(of: photoPickerItems) { _, items in
            Task { await importPhotos(items) }
        }
        .sheet(isPresented: $showingTextEditor) {
            textCreationSheet
        }
        .sheet(isPresented: $showingStickerPicker) {
            StickerPickerView { name in
                addSticker(name)
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            colorBlockPickerSheet
        }
        .sheet(isPresented: $showingBackgroundPicker) {
            backgroundPickerSheet
        }
        .sheet(isPresented: $showingAudioPicker) {
            CollageAudioPickerSheet { url, title in
                addAudioSticker(url: url, title: title)
            }
        }
        .sheet(isPresented: Binding(
            get: { editingTextElementID != nil },
            set: { if !$0 { editingTextElementID = nil } }
        )) {
            if let elementID = editingTextElementID {
                textEditingSheet(elementID: elementID)
            }
        }
        .photosPicker(
            isPresented: Binding(
                get: { replacingImageElementID != nil },
                set: { if !$0 { replacingImageElementID = nil } }
            ),
            selection: $replacePhotoItem,
            matching: .images
        )
        .confirmationDialog("Share Collage", isPresented: $showingShareOptions, titleVisibility: .visible) {
            Button("Share") {
                renderAndShare(saveToPosts: false)
            }
            Button("Save to Posts") {
                renderAndShare(saveToPosts: true)
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingActivityShare) {
            if let renderedShareImage {
                ActivityView(items: [renderedShareImage])
            }
        }
        .onChange(of: replacePhotoItem) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let id = replacingImageElementID else { return }
                saveHistory()
                updateElement(id) { $0.imageData = data }
                replacingImageElementID = nil
                replacePhotoItem = nil
            }
        }
        .sheet(isPresented: $showingCustomBackgroundPicker) {
            NavigationStack {
                VStack(spacing: 20) {
                    ColorPicker("Custom background", selection: $customBackgroundColor, supportsOpacity: false)
                        .foregroundStyle(AppPalette.text)
                    Spacer()
                }
                .padding(16)
                .background(AppPalette.background.ignoresSafeArea())
                .navigationTitle("Custom Background")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingCustomBackgroundPicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            saveHistory()
                            if let hex = customBackgroundColor.toHex() {
                                canvasBackground = .gradient(startHex: hex, endHex: hex)
                            }
                            showingCustomBackgroundPicker = false
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .onDisappear {
            stopAudioPlayback()
        }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(AppPalette.trackBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Collage")
                .font(.inter(.semibold, size: 17))
                .foregroundStyle(AppPalette.text)

            Spacer()

            Button {
                showingShareOptions = true
            } label: {
                Text("Share")
                    .font(.inter(.semibold, size: 14))
                    .foregroundStyle(AppPalette.background)
                    .frame(width: 80, height: 36)
                    .background(AppPalette.lavender)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppPalette.background)
    }

    // MARK: Canvas

    @ViewBuilder
    private func canvasBackgroundView(size: CGSize) -> some View {
        switch canvasBackground {
        case .dark:
            AppPalette.background
        case .light:
            Color(hex: "F5F0E8")
        case .black:
            Color.black
        case .grain:
            ZStack {
                AppPalette.background
                Canvas { context, canvasSize in
                    for _ in 0..<800 {
                        let x = CGFloat.random(in: 0...canvasSize.width)
                        let y = CGFloat.random(in: 0...canvasSize.height)
                        let rect = CGRect(x: x, y: y, width: 1, height: 1)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.06)))
                    }
                }
            }
        case .gradient(let startHex, let endHex):
            LinearGradient(
                colors: [Color(hex: startHex), Color(hex: endHex)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func dotGrid(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let spacing: CGFloat = 24
            var x: CGFloat = 0
            while x < canvasSize.width {
                var y: CGFloat = 0
                while y < canvasSize.height {
                    let rect = CGRect(x: x, y: y, width: 1.5, height: 1.5)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.04)))
                    y += spacing
                }
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }

    private var canvasPanGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard selectedElementID == nil else { return }
                canvasOffset = CGSize(
                    width: canvasPanStart.width + value.translation.width,
                    height: canvasPanStart.height + value.translation.height
                )
            }
            .onEnded { _ in
                canvasPanStart = canvasOffset
            }
    }

    private var canvasMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                canvasScale = min(3, max(0.5, canvasMagnifyBase * value))
            }
            .onEnded { _ in
                canvasMagnifyBase = canvasScale
            }
    }

    @ViewBuilder
    private func elementLayer(_ element: CollageElement, canvasSize: CGSize) -> some View {
        CollageElementView(
            element: element,
            isSelected: selectedElementID == element.id,
            isPlaying: playingAudioElementID == element.id && audioIsPlaying,
            onToggleAudio: { toggleAudio(for: element) }
        )
        .frame(width: element.size.width, height: element.size.height)
        .scaleEffect(element.scale * (selectedElementID == element.id ? liveMagnification : 1))
        .rotationEffect(.degrees(element.rotation))
        .position(element.position)
        .opacity(element.opacity)
        .zIndex(element.zIndex)
        .onTapGesture {
            selectedElementID = element.id
        }
        .onTapGesture(count: 2) {
            handleDoubleTap(element)
        }
        .gesture(elementDragGesture(for: element))
        .simultaneousGesture(elementMagnificationGesture(for: element))
        .contextMenu {
            Button("Bring Forward") { bringForward(element) }
            Button("Send Backward") { sendBackward(element) }
            Button("Duplicate") { duplicateElement(element) }
            Button("Delete", role: .destructive) { deleteElement(element) }
        }
        .overlay {
            if selectedElementID == element.id {
                rotationHandle(for: element, canvasSize: canvasSize)
            }
        }
    }

    private func elementDragGesture(for element: CollageElement) -> some Gesture {
        DragGesture(coordinateSpace: .local)
            .onChanged { value in
                if dragStartPositions[element.id] == nil {
                    saveHistory()
                    dragStartPositions[element.id] = element.position
                }
                if let start = dragStartPositions[element.id] {
                    updateElement(element.id) {
                        $0.position = CGPoint(
                            x: start.x + value.translation.width / canvasScale,
                            y: start.y + value.translation.height / canvasScale
                        )
                    }
                }
            }
            .onEnded { _ in
                dragStartPositions[element.id] = nil
            }
    }

    private func elementMagnificationGesture(for element: CollageElement) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard selectedElementID == element.id else { return }
                if liveMagnification == 1.0 {
                    saveHistory()
                    magnifyBaseScale = element.scale
                }
                liveMagnification = value
                updateElement(element.id) { $0.scale = min(3, max(0.3, magnifyBaseScale * value)) }
            }
            .onEnded { _ in
                liveMagnification = 1.0
            }
    }

    private func rotationHandle(for element: CollageElement, canvasSize: CGSize) -> some View {
        let halfHeight = element.size.height * element.scale / 2
        let lineHeight: CGFloat = 20
        let handleY = element.position.y - halfHeight - lineHeight - 7

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: element.position.x, y: element.position.y - halfHeight))
                path.addLine(to: CGPoint(x: element.position.x, y: handleY + 7))
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 1)

            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .position(x: element.position.x, y: handleY)
                .gesture(
                    DragGesture(coordinateSpace: .named("collageSpace"))
                        .onChanged { value in
                            if dragStartPositions[element.id] == nil {
                                saveHistory()
                                dragStartPositions[element.id] = element.position
                            }
                            let dx = value.location.x - element.position.x
                            let dy = value.location.y - element.position.y
                            let angle = atan2(dy, dx) * 180 / .pi + 90
                            updateElement(element.id) { $0.rotation = angle }
                        }
                        .onEnded { _ in
                            dragStartPositions[element.id] = nil
                        }
                )
        }
    }

    @ViewBuilder
    private func selectionControls(for element: CollageElement, canvasSize: CGSize) -> some View {
        let topY = max(60, element.position.y - element.size.height * element.scale / 2 - 54)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Opacity")
                    .font(.inter(.regular, size: 10))
                    .foregroundStyle(AppPalette.tertiaryText)
                Slider(
                    value: Binding(
                        get: { element.opacity },
                        set: { newValue in
                            saveHistory()
                            updateElement(element.id) { $0.opacity = newValue }
                        }
                    ),
                    in: 0.1...1.0
                )
                .tint(AppPalette.lavender)
                .frame(width: 100)
            }

            if element.type == .image || element.type == .colorBlock {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Radius")
                        .font(.inter(.regular, size: 10))
                        .foregroundStyle(AppPalette.tertiaryText)
                    Slider(
                        value: Binding(
                            get: { element.cornerRadius },
                            set: { newValue in
                                saveHistory()
                                updateElement(element.id) { $0.cornerRadius = newValue }
                            }
                        ),
                        in: 0...40
                    )
                    .tint(AppPalette.lavender)
                    .frame(width: 100)
                }
            }

            Button {
                deleteElement(element)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.peach)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppPalette.card.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .position(x: canvasSize.width / 2, y: topY)
    }

    // MARK: Toolbar

    private var toolbar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppPalette.trackBackground)
                .frame(height: 1)

            HStack {
                toolButton(icon: "photo.badge.plus", label: "Photo") { showingPhotoPicker = true }
                toolButton(icon: "textformat", label: "Text") { showingTextEditor = true }
                toolButton(icon: "waveform.badge.plus", label: "Audio") { showingAudioPicker = true }
                toolButton(icon: "face.smiling", label: "Sticker") { showingStickerPicker = true }
                toolButton(icon: "paintpalette", label: "Color") { showingColorPicker = true }
                toolButton(icon: "rectangle.fill", label: "Background") { showingBackgroundPicker = true }
                toolButton(
                    icon: "arrow.uturn.backward",
                    label: "Undo",
                    enabled: !history.isEmpty
                ) { undo() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(AppPalette.background)
        }
    }

    private func toolButton(icon: String, label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(enabled ? AppPalette.lavender : AppPalette.tertiaryText)
                Text(label)
                    .font(.inter(.regular, size: 10))
                    .foregroundStyle(enabled ? AppPalette.text : AppPalette.tertiaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: Sheets

    private var textCreationSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Enter text", text: $newTextDraft)
                    .font(.inter(.regular, size: 16))
                    .foregroundStyle(AppPalette.text)
                    .padding(12)
                    .background(AppPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()
            }
            .padding(16)
            .background(AppPalette.background.ignoresSafeArea())
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingTextEditor = false; newTextDraft = "" }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let text = newTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        saveHistory()
                        addTextElement(text)
                        newTextDraft = ""
                        showingTextEditor = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func textEditingSheet(elementID: UUID) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $textEditDraft)
                    .font(.inter(.regular, size: 14))
                    .foregroundStyle(AppPalette.text)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(AppPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Toggle("Bold", isOn: $textEditBold)
                    .foregroundStyle(AppPalette.text)

                Slider(value: $textEditSize, in: 12...48) {
                    Text("Size")
                }
                .tint(AppPalette.lavender)

                ColorPicker("Text colour", selection: $textEditColor)

                Spacer()
            }
            .padding(16)
            .background(AppPalette.background.ignoresSafeArea())
            .navigationTitle("Edit Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveHistory()
                        updateElement(elementID) {
                            $0.text = textEditDraft
                            $0.textSize = CGFloat(textEditSize)
                            $0.textWeight = textEditBold ? .bold : .regular
                            $0.textColor = textEditColor
                        }
                        editingTextElementID = nil
                    }
                }
            }
            .onAppear {
                if let element = elements.first(where: { $0.id == elementID }) {
                    textEditDraft = element.text ?? ""
                    textEditSize = Double(element.textSize)
                    textEditBold = element.textWeight == .bold
                    textEditColor = element.textColor
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var colorBlockPickerSheet: some View {
        let swatches: [Color] = [
            Color(hex: "0D0D10"), Color(hex: "1A1A22"), Color(hex: "2A2A35"), Color(hex: "C9B8E8"),
            Color(hex: "B8D8C8"), Color(hex: "F2C4A0"), Color(hex: "3E345F"), Color(hex: "2A413A"),
            Color(hex: "5D4338"), Color(hex: "38465D"), Color(hex: "4C395B"), Color(hex: "324457"),
            Color(hex: "FF6B6B"), Color(hex: "FFD93D"), Color(hex: "6BCB77"), Color(hex: "4D96FF")
        ]

        return NavigationStack {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(Array(swatches.enumerated()), id: \.offset) { _, color in
                    Button {
                        saveHistory()
                        addColorBlock(color)
                        showingColorPicker = false
                    } label: {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(color)
                            .frame(height: 56)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(AppPalette.background.ignoresSafeArea())
            .navigationTitle("Add Colour Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingColorPicker = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var backgroundPickerSheet: some View {
        let options: [(String, CollageBackground)] = [
            ("Dark", .dark),
            ("Pure Black", .black),
            ("Cream", .light),
            ("Deep Purple", .gradient(startHex: "0D0020", endHex: "1A0040")),
            ("Midnight Blue", .gradient(startHex: "000814", endHex: "023E8A")),
            ("Warm Dark", .gradient(startHex: "1A0800", endHex: "3D1400")),
            ("Sage Dark", .gradient(startHex: "0A1A0F", endHex: "1A3320")),
            ("Film Grain", .grain),
            ("Custom", .gradient(startHex: "1A0040", endHex: "1A0040"))
        ]

        return NavigationStack {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button {
                        if option.0 == "Custom" {
                            showingBackgroundPicker = false
                            showingCustomBackgroundPicker = true
                        } else {
                            saveHistory()
                            canvasBackground = option.1
                            showingBackgroundPicker = false
                        }
                    } label: {
                        VStack(spacing: 8) {
                            backgroundSwatch(option.1)
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Text(option.0)
                                .font(.inter(.medium, size: 12))
                                .foregroundStyle(AppPalette.text)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(AppPalette.background.ignoresSafeArea())
            .navigationTitle("Canvas Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingBackgroundPicker = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func backgroundSwatch(_ background: CollageBackground) -> some View {
        switch background {
        case .dark: AppPalette.background
        case .light: Color(hex: "F5F0E8")
        case .black: Color.black
        case .grain: AppPalette.card
        case .gradient(let start, let end):
            LinearGradient(colors: [Color(hex: start), Color(hex: end)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: Element CRUD

    private var canvasCentre: CGPoint {
        CGPoint(x: max(canvasSize.width, 300) / 2, y: max(canvasSize.height, 400) / 2)
    }

    private func nextZIndex() -> Double {
        (elements.map(\.zIndex).max() ?? 0) + 1
    }

    private func offsetPosition(index: Int) -> CGPoint {
        CGPoint(
            x: canvasCentre.x + CGFloat(index * 14),
            y: canvasCentre.y + CGFloat(index * 10)
        )
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        saveHistory()
        for (index, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let element = CollageElement(
                    type: .image,
                    position: offsetPosition(index: elements.count + index),
                    size: CGSize(width: 200, height: 200),
                    zIndex: nextZIndex() + Double(index),
                    imageData: data
                )
                elements.append(element)
            }
        }
        photoPickerItems = []
        showingPhotoPicker = false
    }

    private func addTextElement(_ text: String) {
        elements.append(
            CollageElement(
                type: .text,
                position: canvasCentre,
                size: CGSize(width: 160, height: 60),
                zIndex: nextZIndex(),
                text: text
            )
        )
        selectedElementID = elements.last?.id
    }

    private func addAudioSticker(url: URL?, title: String) {
        saveHistory()
        elements.append(
            CollageElement(
                type: .audioSticker,
                position: canvasCentre,
                size: CGSize(width: 200, height: 56),
                zIndex: nextZIndex(),
                audioURL: url,
                audioTitle: title
            )
        )
        selectedElementID = elements.last?.id
    }

    private func addSticker(_ name: String) {
        saveHistory()
        elements.append(
            CollageElement(
                type: .sticker,
                position: canvasCentre,
                size: CGSize(width: 80, height: 80),
                zIndex: nextZIndex(),
                stickerName: name
            )
        )
        selectedElementID = elements.last?.id
    }

    private func addColorBlock(_ color: Color) {
        elements.append(
            CollageElement(
                type: .colorBlock,
                position: canvasCentre,
                size: CGSize(width: 120, height: 120),
                zIndex: nextZIndex(),
                backgroundColor: color
            )
        )
        selectedElementID = elements.last?.id
    }

    private func updateElement(_ id: UUID, _ update: (inout CollageElement) -> Void) {
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
        update(&elements[index])
    }

    private func deleteElement(_ element: CollageElement) {
        saveHistory()
        elements.removeAll { $0.id == element.id }
        if selectedElementID == element.id { selectedElementID = nil }
    }

    private func duplicateElement(_ element: CollageElement) {
        saveHistory()
        var copy = element
        copy.id = UUID()
        copy.position = CGPoint(x: element.position.x + 20, y: element.position.y + 20)
        copy.zIndex = nextZIndex()
        elements.append(copy)
        selectedElementID = copy.id
    }

    private func bringForward(_ element: CollageElement) {
        saveHistory()
        updateElement(element.id) { $0.zIndex = nextZIndex() }
    }

    private func sendBackward(_ element: CollageElement) {
        saveHistory()
        let minZ = elements.map(\.zIndex).min() ?? 0
        updateElement(element.id) { $0.zIndex = minZ - 1 }
    }

    private func handleDoubleTap(_ element: CollageElement) {
        switch element.type {
        case .text:
            if selectedElementID == element.id {
                editingTextElementID = element.id
            }
        case .image:
            replacingImageElementID = element.id
        default:
            break
        }
    }

    // MARK: History

    private func saveHistory() {
        history.append(elements)
        if history.count > 20 { history.removeFirst() }
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        withAnimation(.spring(response: 0.3)) {
            elements = last
            selectedElementID = nil
        }
    }

    // MARK: Audio playback

    private func toggleAudio(for element: CollageElement) {
        if playingAudioElementID == element.id && audioIsPlaying {
            stopAudioPlayback()
        } else {
            playingAudioElementID = element.id
            audioPlaybackProgress = 0
            audioIsPlaying = true
            startAudioTimer(duration: 214)
        }
    }

    private func startAudioTimer(duration: TimeInterval) {
        stopAudioPlaybackTimer()
        audioTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let increment = 0.1 / duration
            if audioPlaybackProgress + increment >= 1.0 {
                stopAudioPlayback()
            } else {
                audioPlaybackProgress += increment
            }
        }
    }

    private func stopAudioPlaybackTimer() {
        audioTimer?.invalidate()
        audioTimer = nil
    }

    private func stopAudioPlayback() {
        stopAudioPlaybackTimer()
        audioIsPlaying = false
        audioPlaybackProgress = 0
        playingAudioElementID = nil
    }

    // MARK: Export

    private func renderAndShare(saveToPosts: Bool) {
        let exportView = CollageExportView(
            elements: elements,
            background: canvasBackground,
            size: CGSize(width: 390, height: 700)
        )
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = UIScreen.main.scale * 2
        guard let image = renderer.uiImage,
              let data = image.jpegData(compressionQuality: 0.92) else { return }

        if saveToPosts {
            onSaveToPosts(data)
            dismiss()
        } else {
            renderedShareImage = image
            showingActivityShare = true
        }
    }
}

// MARK: - Element View

private struct CollageElementView: View {
    let element: CollageElement
    let isSelected: Bool
    let isPlaying: Bool
    let onToggleAudio: () -> Void

    var body: some View {
        ZStack {
            content
            if isSelected {
                RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous)
                    .stroke(AppPalette.lavender, lineWidth: 2)
                resizeHandles
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch element.type {
        case .image:
            Group {
                if let data = element.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    AppPalette.card
                }
            }
            .frame(width: element.size.width, height: element.size.height)
            .clipShape(RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous))

        case .text:
            Text(element.text ?? "")
                .font(.system(size: element.textSize, weight: element.textWeight))
                .foregroundStyle(element.textColor)
                .padding(8)
                .frame(width: element.size.width, height: element.size.height)
                .background(element.backgroundColor == .clear ? Color.clear : element.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        case .audioSticker:
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .foregroundStyle(AppPalette.lavender)
                Text(element.audioTitle ?? "Untitled track")
                    .font(.inter(.medium, size: 13))
                    .foregroundStyle(AppPalette.text)
                    .lineLimit(1)
                Spacer()
                Button(action: onToggleAudio) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundStyle(AppPalette.lavender)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(width: element.size.width, height: element.size.height)
            .background(AppPalette.card.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        case .sticker:
            Image(systemName: element.stickerName ?? "star.fill")
                .font(.system(size: min(element.size.width, element.size.height) * 0.55))
                .foregroundStyle(element.stickerColor)
                .frame(width: element.size.width, height: element.size.height)

        case .colorBlock:
            RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous)
                .fill(element.backgroundColor)
                .frame(width: element.size.width, height: element.size.height)
        }
    }

    private var resizeHandles: some View {
        ZStack {
            ForEach(handlePoints, id: \.self) { point in
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .position(point)
            }
        }
    }

    private var handlePoints: [CGPoint] {
        let w = element.size.width
        let h = element.size.height
        return [
            CGPoint(x: 0, y: 0),
            CGPoint(x: w, y: 0),
            CGPoint(x: 0, y: h),
            CGPoint(x: w, y: h)
        ]
    }
}

// MARK: - Export View

private struct CollageExportView: View {
    let elements: [CollageElement]
    let background: CollageBackground
    let size: CGSize

    var body: some View {
        ZStack {
            backgroundView
            ForEach(elements.sorted(by: { $0.zIndex < $1.zIndex })) { element in
                CollageElementView(
                    element: element,
                    isSelected: false,
                    isPlaying: false,
                    onToggleAudio: {}
                )
                .frame(width: element.size.width, height: element.size.height)
                .scaleEffect(element.scale)
                .rotationEffect(.degrees(element.rotation))
                .position(element.position)
                .opacity(element.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch background {
        case .dark: AppPalette.background
        case .light: Color(hex: "F5F0E8")
        case .black: Color.black
        case .grain: AppPalette.background
        case .gradient(let start, let end):
            LinearGradient(colors: [Color(hex: start), Color(hex: end)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Sticker Picker

struct StickerPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void

    private let categories: [(String, [String])] = [
        ("Music", ["music.note", "waveform", "guitars", "music.mic", "headphones", "music.quarternote.3", "radio", "hifispeaker"]),
        ("Mood", ["moon.stars", "sun.max", "flame", "drop", "wind", "sparkles", "star", "bolt"]),
        ("People", ["person.wave.2", "hands.clap", "figure.dance", "ear", "eye"]),
        ("Shapes", ["circle", "triangle", "square", "diamond", "seal"])
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(categories, id: \.0) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.0)
                                .font(.inter(.semibold, size: 15))
                                .foregroundStyle(AppPalette.text)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 12) {
                                ForEach(category.1, id: \.self) { symbol in
                                    Button {
                                        onSelect(symbol)
                                        dismiss()
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: symbol)
                                                .font(.system(size: 32))
                                                .foregroundStyle(AppPalette.lavender)
                                                .frame(height: 40)
                                            Text(symbol)
                                                .font(.inter(.regular, size: 9))
                                                .foregroundStyle(AppPalette.secondaryText)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppPalette.background.ignoresSafeArea())
            .navigationTitle("Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Audio Picker Sheet

private struct CollageAudioPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var trackTitle = ""
    @State private var showingFilePicker = false
    @State private var pickedURL: URL?

    let onAdd: (URL?, String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Track name", text: $trackTitle)
                    .font(.inter(.regular, size: 14))
                    .foregroundStyle(AppPalette.text)
                    .padding(12)
                    .background(AppPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    showingFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(AppPalette.lavender)
                        Text(pickedURL == nil ? "Pick audio file" : "Audio selected")
                        Spacer()
                    }
                    .font(.inter(.medium, size: 14))
                    .foregroundStyle(AppPalette.text)
                    .padding(12)
                    .background(AppPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(16)
            .background(AppPalette.background.ignoresSafeArea())
            .navigationTitle("Add Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let title = trackTitle.isEmpty ? (pickedURL?.deletingPathExtension().lastPathComponent ?? "Untitled track") : trackTitle
                        onAdd(pickedURL, title)
                        dismiss()
                    }
                    .disabled(trackTitle.isEmpty && pickedURL == nil)
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                AudioDocumentPicker { url in
                    pickedURL = url
                    if trackTitle.isEmpty {
                        trackTitle = url.deletingPathExtension().lastPathComponent
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Activity View

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
