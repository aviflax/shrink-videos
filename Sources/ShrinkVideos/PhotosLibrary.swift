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

    static func addToLibrary(videoURL: URL, originalAsset: PHAsset, caption: String? = nil) async throws {
        // Read title and caption from the original asset via AppleScript
        let originalMetadata = try getMediaItemMetadata(assetIdentifier: originalAsset.localIdentifier)

        var localIdentifier: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = videoURL.lastPathComponent
            request.addResource(with: .video, fileURL: videoURL, options: options)
            request.creationDate = originalAsset.creationDate
            request.location = originalAsset.location
            request.isFavorite = originalAsset.isFavorite
            localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
        }

        if let localIdentifier {
            var fullCaption = originalMetadata.caption ?? ""
            if let caption {
                if !fullCaption.isEmpty {
                    fullCaption += "\n\n"
                }
                fullCaption += caption
            }
            try setMediaItemMetadata(
                assetIdentifier: localIdentifier,
                title: originalMetadata.title,
                caption: fullCaption.isEmpty ? nil : fullCaption
            )
        }
    }

    private static func getMediaItemMetadata(assetIdentifier: String) throws -> (title: String?, caption: String?) {
        let escapedId = escapeForAppleScript(assetIdentifier)
        let script = """
            tell application "Photos"
                set theItem to media item id "\(escapedId)"
                set theTitle to name of theItem
                set theDesc to description of theItem
                return theTitle & "\\n---SEPARATOR---\\n" & theDesc
            end tell
            """
        let (output, status) = runAppleScript(script)
        guard status == 0, let output else { return (nil, nil) }

        let parts = output.components(separatedBy: "\n---SEPARATOR---\n")
        let title = parts.first.flatMap { $0.isEmpty ? nil : $0 }
        let caption = parts.count > 1 ? (parts[1].isEmpty ? nil : parts[1]) : nil
        return (title, caption)
    }

    private static func setMediaItemMetadata(assetIdentifier: String, title: String?, caption: String?) throws {
        let escapedId = escapeForAppleScript(assetIdentifier)
        var statements = "set theItem to media item id \"\(escapedId)\"\n"
        if let title {
            statements += "set name of theItem to \"\(escapeForAppleScript(title))\"\n"
        }
        if let caption {
            statements += "set description of theItem to \"\(escapeForAppleScript(caption))\"\n"
        }
        let script = """
            tell application "Photos"
                \(statements)
            end tell
            """
        let (_, status) = runAppleScript(script)
        if status != 0 {
            print("Warning: failed to set metadata via AppleScript (exit code \(status))")
        }
    }

    private static func escapeForAppleScript(_ string: String) -> String {
        string.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func runAppleScript(_ script: String) -> (output: String?, status: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
        } catch {
            return (nil, -1)
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (output, process.terminationStatus)
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
