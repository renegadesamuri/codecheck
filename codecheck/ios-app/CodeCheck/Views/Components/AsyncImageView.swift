//
//  AsyncImageView.swift
//  CodeCheck
//
//  Phase 3 Optimization: Lazy Image Loading Component
//  Efficiently loads images from persistent storage with thumbnails
//

import SwiftUI

/// A view that asynchronously loads an image from persistent storage
/// Displays a placeholder while loading and supports thumbnails for faster initial load
struct AsyncImageView: View {
    let imageId: UUID

    /// Whether to load thumbnail (faster) or full image
    let useThumbnail: Bool

    /// Placeholder to show while loading
    let placeholder: AnyView

    /// Content mode for the image
    let contentMode: ContentMode

    @State private var image: UIImage?
    @State private var isLoading = true

    init(
        imageId: UUID,
        useThumbnail: Bool = true,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> some View = { defaultPlaceholder }
    ) {
        self.imageId = imageId
        self.useThumbnail = useThumbnail
        self.contentMode = contentMode
        self.placeholder = AnyView(placeholder())
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                placeholder
            } else {
                // Failed to load - show error placeholder
                errorPlaceholder
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true

        if useThumbnail {
            image = await ImageStorageManager.shared.loadThumbnail(id: imageId)
        } else {
            image = await ImageStorageManager.shared.loadImage(id: imageId)
        }

        isLoading = false
    }

    private var errorPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }

    private static var defaultPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.1)
            ProgressView()
        }
    }
}

// MARK: - Convenience Initializers

extension AsyncImageView {
    /// Create with a simple loading indicator placeholder
    static func withProgress(
        imageId: UUID,
        useThumbnail: Bool = true,
        contentMode: ContentMode = .fill
    ) -> AsyncImageView {
        AsyncImageView(
            imageId: imageId,
            useThumbnail: useThumbnail,
            contentMode: contentMode
        ) {
            ZStack {
                Color.gray.opacity(0.1)
                ProgressView()
            }
        }
    }

    /// Create with a gradient placeholder
    static func withGradient(
        imageId: UUID,
        useThumbnail: Bool = true,
        contentMode: ContentMode = .fill
    ) -> AsyncImageView {
        AsyncImageView(
            imageId: imageId,
            useThumbnail: useThumbnail,
            contentMode: contentMode
        ) {
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ProgressView()
            }
        }
    }

    /// Create with an icon placeholder
    static func withIcon(
        imageId: UUID,
        icon: String = "photo",
        useThumbnail: Bool = true,
        contentMode: ContentMode = .fill
    ) -> AsyncImageView {
        AsyncImageView(
            imageId: imageId,
            useThumbnail: useThumbnail,
            contentMode: contentMode
        ) {
            ZStack {
                Color.gray.opacity(0.1)
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
    }
}

// MARK: - Photo Grid Item

/// A styled version for use in photo grids
struct PhotoGridItem: View {
    let imageId: UUID
    let aspectRatio: CGFloat
    var onTap: (() -> Void)?

    init(
        imageId: UUID,
        aspectRatio: CGFloat = 1.0,
        onTap: (() -> Void)? = nil
    ) {
        self.imageId = imageId
        self.aspectRatio = aspectRatio
        self.onTap = onTap
    }

    var body: some View {
        AsyncImageView.withProgress(
            imageId: imageId,
            useThumbnail: true,
            contentMode: .fill
        )
        .aspectRatio(aspectRatio, contentMode: .fill)
        .clipped()
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Photo Detail View

/// Full-screen image view with loading from storage
struct PhotoDetailView: View {
    let imageId: UUID

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                // Limit zoom range
                                if scale < 1.0 { scale = 1.0 }
                                if scale > 5.0 { scale = 5.0 }
                                lastScale = scale
                            }
                    )
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                    } else {
                                        scale = 2.0
                                        lastScale = 2.0
                                    }
                                }
                            }
                    )
            } else if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Image not found")
                        .foregroundColor(.gray)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .task {
            // Load full resolution image
            image = await ImageStorageManager.shared.loadImage(id: imageId)
            isLoading = false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AsyncImageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Preview with mock UUID (won't load actual image)
            AsyncImageView.withProgress(imageId: UUID())
                .frame(width: 150, height: 150)
                .cornerRadius(12)

            AsyncImageView.withGradient(imageId: UUID())
                .frame(width: 150, height: 150)
                .cornerRadius(12)

            AsyncImageView.withIcon(imageId: UUID(), icon: "camera.fill")
                .frame(width: 150, height: 150)
                .cornerRadius(12)
        }
        .padding()
    }
}
#endif
