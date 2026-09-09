import CryptoKit
import Foundation
import SwiftUI
import UIKit

nonisolated private enum ProductImageCacheError: Error {
    case invalidResponse
    case invalidImageData
}

private actor ProductImageDiskCache {

    static let shared = ProductImageDiskCache()

    private let fileManager = FileManager.default
    private let directoryURL: URL
    private var memoryData: [URL: Data] = [:]

    private init() {
        let cachesDirectory =
            FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first
            ?? FileManager.default.temporaryDirectory

        directoryURL = cachesDirectory
            .appendingPathComponent(
                "PantryBuddyProductImages",
                isDirectory: true
            )

        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    func data(for url: URL) async throws -> Data {
        if let data = memoryData[url],
           UIImage(data: data) != nil {
            return data
        }

        let localURL = fileURL(for: url)

        if let data = try? Data(contentsOf: localURL),
           UIImage(data: data) != nil {
            memoryData[url] = data
            return data
        }

        try? fileManager.removeItem(at: localURL)

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw ProductImageCacheError.invalidResponse
        }

        guard UIImage(data: data) != nil else {
            throw ProductImageCacheError.invalidImageData
        }

        memoryData[url] = data

        try? data.write(
            to: localURL,
            options: .atomic
        )

        return data
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(
            data: Data(url.absoluteString.utf8)
        )

        let fileName = digest.map {
            String(format: "%02x", $0)
        }.joined()

        return directoryURL
            .appendingPathComponent(fileName)
            .appendingPathExtension("image")
    }
}

@MainActor
final class ProductImageCache {

    static let shared = ProductImageCache()

    private let images = NSCache<NSURL, UIImage>()

    private init() {
        images.countLimit = 180
        images.totalCostLimit = 80 * 1024 * 1024
    }

    func cachedImage(for url: URL) -> UIImage? {
        images.object(
            forKey: url as NSURL
        )
    }

    func loadImage(for url: URL) async throws -> UIImage {
        if let cachedImage = cachedImage(for: url) {
            return cachedImage
        }

        let data = try await ProductImageDiskCache.shared.data(
            for: url
        )

        guard let image = UIImage(data: data) else {
            throw ProductImageCacheError.invalidImageData
        }

        images.setObject(
            image,
            forKey: url as NSURL,
            cost: data.count
        )

        return image
    }
}

@MainActor
struct PBCachedRemoteImage<
    Content: View,
    Failure: View
>: View {

    let url: URL

    private let content: (Image) -> Content
    private let failure: () -> Failure

    @State private var loadedImage: UIImage?
    @State private var loadingFailed = false

    init(
        url: URL,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.content = content
        self.failure = failure

        _loadedImage = State(
            initialValue:
                ProductImageCache.shared.cachedImage(
                    for: url
                )
        )
    }

    var body: some View {
        Group {
            if let loadedImage {
                content(
                    Image(uiImage: loadedImage)
                )
            } else if loadingFailed {
                failure()
            } else {
                ProgressView()
                    .tint(PantryTheme.forest)
            }
        }
        .task(id: url) {
            await loadImageIfNeeded()
        }
    }

    private func loadImageIfNeeded() async {
        guard loadedImage == nil else {
            return
        }

        loadingFailed = false

        do {
            let image = try await ProductImageCache.shared
                .loadImage(for: url)

            guard !Task.isCancelled else {
                return
            }

            loadedImage = image
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else {
                return
            }

            loadingFailed = true
        }
    }
}
