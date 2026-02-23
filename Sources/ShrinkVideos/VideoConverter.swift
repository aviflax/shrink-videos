import Foundation

enum ConversionError: Error, CustomStringConvertible {
    case noSourceURL
    case ffmpegNotFound
    case conversionFailed(Int32)

    var description: String {
        switch self {
        case .noSourceURL:
            return "Could not determine source file URL for video."
        case .ffmpegNotFound:
            return "ffmpeg not found. Install it with: brew install ffmpeg"
        case .conversionFailed(let code):
            return "ffmpeg exited with code \(code)."
        }
    }
}

enum VideoConverter {
    static func findFFmpeg() -> String? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    static func convert(video: VideoInfo) throws -> URL {
        guard let sourceURL = video.sourceURL else {
            throw ConversionError.noSourceURL
        }

        guard let ffmpeg = findFFmpeg() else {
            throw ConversionError.ffmpegNotFound
        }

        let outputFilename = (video.filename as NSString)
            .deletingPathExtension + "-shrinked.mp4"
        let outputPath = "/tmp/\(outputFilename)"

        // Remove existing output file if present
        try? FileManager.default.removeItem(atPath: outputPath)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = [
            "-i", sourceURL.path,
            "-c:v", "hevc_videotoolbox",
            "-q:v", "65",
            "-tag:v", "hvc1",
            "-c:a", "copy",
            "-map", "0",
            "-map_metadata", "0",
            "-movflags", "use_metadata_tags",
            "-y",
            outputPath,
        ]

        process.standardInput = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ConversionError.conversionFailed(process.terminationStatus)
        }

        return URL(fileURLWithPath: outputPath)
    }
}
