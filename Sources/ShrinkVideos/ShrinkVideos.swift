import ArgumentParser
import Foundation
import Photos
import AVFoundation

@main
struct ShrinkVideos: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "shrink-videos",
        abstract: "Find and convert Motion JPEG videos in your Photos library to HEVC."
    )

    @Option(name: .long, help: "Find videos without converting (default: true)")
    var dryRun: Bool = true

    @Flag(name: .long, help: "Process all found videos instead of just the first")
    var all: Bool = false

    func run() async throws {
        if !dryRun && all {
            print("--dry-run false --all is not yet implemented.")
            return
        }

        // Request Photos access
        do {
            try await PhotosLibrary.requestAuthorization()
        } catch {
            print("Error: \(error)")
            Foundation.exit(1)
        }

        print("Scanning Photos library for Motion JPEG videos...")

        let assets = PhotosLibrary.fetchAllVideoAssets()
        print("Found \(assets.count) total videos. Checking codecs...\n")

        var mjpegVideos: [VideoInfo] = []

        for asset in assets {
            let avAsset: AVAsset
            do {
                avAsset = try await PhotosLibrary.getAVAsset(for: asset)
            } catch {
                continue
            }

            guard await VideoInspector.isMJPEG(avAsset) else {
                continue
            }

            let (filename, fileSize) = PhotosLibrary.getFileInfo(for: asset)
            let sourceURL = (avAsset as? AVURLAsset)?.url

            let info = VideoInfo(
                asset: asset,
                avAsset: avAsset,
                filename: filename,
                duration: asset.duration,
                fileSize: fileSize,
                creationDate: asset.creationDate,
                width: asset.pixelWidth,
                height: asset.pixelHeight,
                sourceURL: sourceURL
            )

            mjpegVideos.append(info)
            print("  [\(mjpegVideos.count)] \(info.summary)")

            if !all {
                break
            }
        }

        if mjpegVideos.isEmpty {
            print("No Motion JPEG videos found.")
            return
        }

        print("\nFound \(mjpegVideos.count) Motion JPEG video(s).")

        if dryRun {
            return
        }

        // Convert first video
        let video = mjpegVideos[0]
        print("\nConverting \(video.filename) to HEVC...")

        do {
            let outputURL = try VideoConverter.convert(video: video)
            let outputSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0
            let outputMB = String(format: "%.1f MB", Double(outputSize) / 1_000_000)

            print("Done! Saved to: \(outputURL.path)")
            print("Original: \(video.formattedSize) → Converted: \(outputMB)")
        } catch {
            print("Error converting video: \(error)")
            Foundation.exit(1)
        }
    }
}
