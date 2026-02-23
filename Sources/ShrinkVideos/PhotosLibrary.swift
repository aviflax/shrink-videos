import Foundation
import Photos
import AVFoundation

enum PhotosLibraryError: Error, CustomStringConvertible {
    case accessDenied
    case assetNotAvailable
    case noVideoResource

    var description: String {
        switch self {
        case .accessDenied:
            return "Photos access denied. Grant access in System Settings > Privacy & Security > Photos."
        case .assetNotAvailable:
            return "Could not load video asset from Photos library."
        case .noVideoResource:
            return "No video resource found for asset."
        }
    }
}

enum PhotosLibrary {
    static func requestAuthorization() async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized else {
            throw PhotosLibraryError.accessDenied
        }
    }

    static func fetchAllVideoAssets() -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let results = PHAsset.fetchAssets(with: .video, options: fetchOptions)

        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    static func getAVAsset(for phAsset: PHAsset) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .original
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, _ in
                if let avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    continuation.resume(throwing: PhotosLibraryError.assetNotAvailable)
                }
            }
        }
    }

    static func getFileInfo(for phAsset: PHAsset) -> (filename: String, fileSize: Int64) {
        let resources = PHAssetResource.assetResources(for: phAsset)
        let videoResource = resources.first(where: { $0.type == .video })
            ?? resources.first

        let filename = videoResource?.originalFilename ?? "unknown"
        let fileSize = (videoResource?.value(forKey: "fileSize") as? Int64) ?? 0

        return (filename, fileSize)
    }
}
