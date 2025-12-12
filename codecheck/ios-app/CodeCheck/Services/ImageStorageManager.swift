//
//  ImageStorageManager.swift
//  CodeCheck
//
//  Phase 3 Optimization: Persistent Image Storage
//  Manages image persistence with thumbnails for efficient loading
//

import Foundation
import UIKit

/// Manages persistent image storage with automatic thumbnail generation
actor ImageStorageManager {
    static let shared = ImageStorageManager()

    // MARK: - Configuration

    struct Configuration {
        /// Maximum thumbnail dimension (width or height)
        let thumbnailMaxSize: CGFloat

        /// JPEG compression quality for originals (0.0 - 1.0)
        let originalQuality: CGFloat

        /// JPEG compression quality for thumbnails (0.0 - 1.0)
        let thumbnailQuality: CGFloat

        /// Maximum age for cached images before cleanup (in seconds)
        let maxCacheAge: TimeInterval

        static let `default` = Configuration(
            thumbnailMaxSize: 200,
            originalQuality: 0.8,
            thumbnailQuality: 0.6,
            maxCacheAge: 60 * 60 * 24 * 30  // 30 days
        )
    }

    // MARK: - Properties

    private let config: Configuration
    private let fileManager: FileManager
    private let originalsDirectory: URL
    private let thumbnailsDirectory: URL

    /// In-memory cache for recently accessed images
    private let imageCache = NSCache<NSString, UIImage>()
    private let thumbnailCache = NSCache<NSString, UIImage>()

    // MARK: - Initialization

    private init(config: Configuration = .default) {
        self.config = config
        self.fileManager = FileManager.default

        // Set up directories
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesPath = documentsPath.appendingPathComponent("Images", isDirectory: true)

        self.originalsDirectory = imagesPath.appendingPathComponent("Originals", isDirectory: true)
        self.thumbnailsDirectory = imagesPath.appendingPathComponent("Thumbnails", isDirectory: true)

        // Configure memory caches
        imageCache.countLimit = 20
        imageCache.totalCostLimit = 50 * 1024 * 1024  // 50MB

        thumbnailCache.countLimit = 100
        thumbnailCache.totalCostLimit = 10 * 1024 * 1024  // 10MB

        // Create directories if needed
        Task {
            await createDirectoriesIfNeeded()
        }
    }

    // MARK: - Directory Management

    private func createDirectoriesIfNeeded() {
        do {
            try fileManager.createDirectory(at: originalsDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create image directories: \(error)")
        }
    }

    // MARK: - Save Operations

    /// Save an image and generate thumbnail
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - id: Unique identifier for the image
    /// - Returns: URL to the saved original image
    @discardableResult
    func saveImage(_ image: UIImage, id: UUID) async throws -> URL {
        // Generate and save original
        guard let originalData = image.jpegData(compressionQuality: config.originalQuality) else {
            throw ImageStorageError.compressionFailed
        }

        let originalURL = originalsDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try originalData.write(to: originalURL)

        // Generate and save thumbnail
        let thumbnail = generateThumbnail(from: image)
        if let thumbnailData = thumbnail.jpegData(compressionQuality: config.thumbnailQuality) {
            let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg")
            try thumbnailData.write(to: thumbnailURL)

            // Cache thumbnail
            thumbnailCache.setObject(thumbnail, forKey: id.uuidString as NSString)
        }

        // Cache original
        imageCache.setObject(image, forKey: id.uuidString as NSString)

        return originalURL
    }

    /// Save image data directly
    func saveImageData(_ data: Data, id: UUID, generateThumbnail: Bool = true) async throws -> URL {
        let originalURL = originalsDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try data.write(to: originalURL)

        if generateThumbnail, let image = UIImage(data: data) {
            let thumbnail = self.generateThumbnail(from: image)
            if let thumbnailData = thumbnail.jpegData(compressionQuality: config.thumbnailQuality) {
                let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg")
                try thumbnailData.write(to: thumbnailURL)
                thumbnailCache.setObject(thumbnail, forKey: id.uuidString as NSString)
            }
        }

        return originalURL
    }

    // MARK: - Load Operations

    /// Load original image by ID
    func loadImage(id: UUID) async -> UIImage? {
        let key = id.uuidString as NSString

        // Check memory cache first
        if let cached = imageCache.object(forKey: key) {
            return cached
        }

        // Load from disk
        let url = originalsDirectory.appendingPathComponent("\(id.uuidString).jpg")

        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }

        // Cache for future access
        imageCache.setObject(image, forKey: key)

        return image
    }

    /// Load thumbnail by ID (faster for list views)
    func loadThumbnail(id: UUID) async -> UIImage? {
        let key = id.uuidString as NSString

        // Check memory cache first
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }

        // Load from disk
        let url = thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg")

        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            // Fallback to generating thumbnail from original
            if let original = await loadImage(id: id) {
                let thumbnail = generateThumbnail(from: original)
                thumbnailCache.setObject(thumbnail, forKey: key)
                return thumbnail
            }
            return nil
        }

        // Cache for future access
        thumbnailCache.setObject(image, forKey: key)

        return image
    }

    /// Check if an image exists
    func imageExists(id: UUID) -> Bool {
        let url = originalsDirectory.appendingPathComponent("\(id.uuidString).jpg")
        return fileManager.fileExists(atPath: url.path)
    }

    // MARK: - Thumbnail Generation

    /// Generate a thumbnail from an image
    func generateThumbnail(from image: UIImage, maxSize: CGFloat? = nil) -> UIImage {
        let targetSize = maxSize ?? config.thumbnailMaxSize
        let size = image.size

        // Calculate scale to fit within maxSize while maintaining aspect ratio
        let widthRatio = targetSize / size.width
        let heightRatio = targetSize / size.height
        let scale = min(widthRatio, heightRatio)

        // If image is already smaller than target, return as-is
        if scale >= 1.0 {
            return image
        }

        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        // Use UIGraphicsImageRenderer for better performance
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Delete Operations

    /// Delete an image and its thumbnail
    func deleteImage(id: UUID) throws {
        let originalURL = originalsDirectory.appendingPathComponent("\(id.uuidString).jpg")
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(id.uuidString).jpg")

        // Remove from caches
        let key = id.uuidString as NSString
        imageCache.removeObject(forKey: key)
        thumbnailCache.removeObject(forKey: key)

        // Remove files
        if fileManager.fileExists(atPath: originalURL.path) {
            try fileManager.removeItem(at: originalURL)
        }

        if fileManager.fileExists(atPath: thumbnailURL.path) {
            try fileManager.removeItem(at: thumbnailURL)
        }
    }

    /// Delete multiple images
    func deleteImages(ids: [UUID]) async {
        for id in ids {
            try? deleteImage(id: id)
        }
    }

    // MARK: - Cleanup Operations

    /// Remove orphaned images (images not in the valid IDs set)
    func cleanupOrphanedImages(validIds: Set<UUID>) async {
        let validIdStrings = Set(validIds.map { $0.uuidString })

        // Cleanup originals
        if let originalFiles = try? fileManager.contentsOfDirectory(at: originalsDirectory, includingPropertiesForKeys: nil) {
            for file in originalFiles {
                let filename = file.deletingPathExtension().lastPathComponent
                if !validIdStrings.contains(filename) {
                    try? fileManager.removeItem(at: file)
                }
            }
        }

        // Cleanup thumbnails
        if let thumbnailFiles = try? fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil) {
            for file in thumbnailFiles {
                let filename = file.deletingPathExtension().lastPathComponent
                if !validIdStrings.contains(filename) {
                    try? fileManager.removeItem(at: file)
                }
            }
        }
    }

    /// Remove old cached images beyond the max age
    func cleanupOldImages() async {
        let cutoffDate = Date().addingTimeInterval(-config.maxCacheAge)

        let directories = [originalsDirectory, thumbnailsDirectory]

        for directory in directories {
            guard let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey]
            ) else { continue }

            for file in files {
                guard let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                      let creationDate = attributes[.creationDate] as? Date else {
                    continue
                }

                if creationDate < cutoffDate {
                    try? fileManager.removeItem(at: file)
                }
            }
        }
    }

    /// Clear all caches (memory and disk)
    func clearAllCaches() async {
        // Clear memory caches
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()

        // Clear disk caches
        if let originalFiles = try? fileManager.contentsOfDirectory(at: originalsDirectory, includingPropertiesForKeys: nil) {
            for file in originalFiles {
                try? fileManager.removeItem(at: file)
            }
        }

        if let thumbnailFiles = try? fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil) {
            for file in thumbnailFiles {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    // MARK: - Storage Info

    /// Get storage usage information
    func getStorageInfo() async -> StorageInfo {
        var originalsSize: UInt64 = 0
        var thumbnailsSize: UInt64 = 0
        var originalsCount = 0
        var thumbnailsCount = 0

        if let files = try? fileManager.contentsOfDirectory(at: originalsDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            originalsCount = files.count
            for file in files {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    originalsSize += UInt64(size)
                }
            }
        }

        if let files = try? fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            thumbnailsCount = files.count
            for file in files {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    thumbnailsSize += UInt64(size)
                }
            }
        }

        return StorageInfo(
            originalsCount: originalsCount,
            originalsSize: originalsSize,
            thumbnailsCount: thumbnailsCount,
            thumbnailsSize: thumbnailsSize
        )
    }

    /// Get all stored image IDs
    func getAllImageIds() async -> [UUID] {
        guard let files = try? fileManager.contentsOfDirectory(at: originalsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        return files.compactMap { file in
            let filename = file.deletingPathExtension().lastPathComponent
            return UUID(uuidString: filename)
        }
    }
}

// MARK: - Supporting Types

extension ImageStorageManager {
    enum ImageStorageError: LocalizedError {
        case compressionFailed
        case saveFailed(Error)
        case loadFailed
        case imageNotFound

        var errorDescription: String? {
            switch self {
            case .compressionFailed:
                return "Failed to compress image"
            case .saveFailed(let error):
                return "Failed to save image: \(error.localizedDescription)"
            case .loadFailed:
                return "Failed to load image"
            case .imageNotFound:
                return "Image not found"
            }
        }
    }

    struct StorageInfo {
        let originalsCount: Int
        let originalsSize: UInt64
        let thumbnailsCount: Int
        let thumbnailsSize: UInt64

        var totalSize: UInt64 { originalsSize + thumbnailsSize }
        var totalCount: Int { originalsCount + thumbnailsCount }

        var formattedTotalSize: String {
            ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
        }

        var formattedOriginalsSize: String {
            ByteCountFormatter.string(fromByteCount: Int64(originalsSize), countStyle: .file)
        }

        var formattedThumbnailsSize: String {
            ByteCountFormatter.string(fromByteCount: Int64(thumbnailsSize), countStyle: .file)
        }
    }
}

// MARK: - Convenience Extensions

extension UIImage {
    /// Save this image to persistent storage
    func saveToStorage(id: UUID = UUID()) async throws -> UUID {
        try await ImageStorageManager.shared.saveImage(self, id: id)
        return id
    }

    /// Load an image from persistent storage
    static func loadFromStorage(id: UUID) async -> UIImage? {
        await ImageStorageManager.shared.loadImage(id: id)
    }

    /// Load a thumbnail from persistent storage
    static func loadThumbnailFromStorage(id: UUID) async -> UIImage? {
        await ImageStorageManager.shared.loadThumbnail(id: id)
    }
}
