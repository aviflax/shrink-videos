//  Copyright © 2026 Avi Flax. ALL RIGHTS RESERVED; see ../COPYRIGHT

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

    @Option(name: .long, help: "Number of found videos to skip before processing")
    var skip: Int = 0

    @Flag(name: .long, help: "Add converted video to Photos library with original metadata")
    var add: Bool = false

    @Flag(name: .long, help: "Add converted video to Photos library and delete the original")
    var replace: Bool = false

    @Flag(name: .long, help: "Scan all videos and report codec distribution")
    var scan: Bool = false

    func run() async throws {
        if add && replace {
            print("Error: --add and --replace are mutually exclusive.")
            Foundation.exit(1)
        }

        // Request Photos access
        do {
            try await PhotosLibrary.requestAuthorization()
        } catch {
            print("Error: \(error)")
            Foundation.exit(1)
        }

        let assets = PhotosLibrary.fetchAllVideoAssets()

        if scan {
            print("Scanning \(assets.count) videos for codec distribution...")

            struct CodecStats {
                var count: Int = 0
                var totalSize: Int64 = 0
            }
            var statsByCodec: [String: CodecStats] = [:]

            for asset in assets {
                let avAsset: AVAsset
                do {
                    avAsset = try await PhotosLibrary.getAVAsset(for: asset)
                } catch {
                    continue
                }

                let codec = await VideoInspector.codecName(for: avAsset) ?? "unknown"
                let (_, fileSize) = PhotosLibrary.getFileInfo(for: asset)
                statsByCodec[codec, default: CodecStats()].count += 1
                statsByCodec[codec, default: CodecStats()].totalSize += fileSize
            }

            let sorted = statsByCodec.sorted { $0.value.totalSize > $1.value.totalSize }

            let codecWidth = max(5, sorted.map(\.key.count).max() ?? 5)
            print("\("Codec".padding(toLength: codecWidth, withPad: " ", startingAt: 0))  \("Count".leftPadded(to: 5))  \("Total Size".leftPadded(to: 10))")
            for (codec, stats) in sorted {
                let size = Double(stats.totalSize) / 1_000_000_000
                let sizeStr: String
                if size >= 1 {
                    sizeStr = String(format: "%.1f GB", size)
                } else {
                    sizeStr = String(format: "%.1f MB", size * 1000)
                }
                print("\(codec.padding(toLength: codecWidth, withPad: " ", startingAt: 0))  \(String(stats.count).leftPadded(to: 5))  \(sizeStr.leftPadded(to: 10))")
            }
            return
        }

        print("Scanning Photos library for Motion JPEG videos...")
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
        }

        if mjpegVideos.isEmpty {
            print("No Motion JPEG videos found.")
            return
        }

        mjpegVideos.sort { $0.fileSize > $1.fileSize }

        for (i, info) in mjpegVideos.enumerated() {
            print("  [\(i + 1)] \(info.summary)")
        }

        print("\nFound \(mjpegVideos.count) Motion JPEG video(s).")

        if dryRun {
            return
        }

        guard skip < mjpegVideos.count else {
            print("--skip \(skip) but only found \(mjpegVideos.count) video(s).")
            return
        }

        let videosToProcess = all
            ? Array(mjpegVideos.dropFirst(skip))
            : [mjpegVideos[skip]]

        for (i, video) in videosToProcess.enumerated() {
            if videosToProcess.count > 1 {
                print("\n[\(i + 1)/\(videosToProcess.count)] Converting \(video.filename) to HEVC...")
            } else {
                print("\nConverting \(video.filename) to HEVC...")
            }

            do {
                let outputURL = try VideoConverter.convert(video: video)
                let outputSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0
                let outputMB = String(format: "%.1f MB", Double(outputSize) / 1_000_000)

                print("Done! Saved to: \(outputURL.path)")
                print("Original: \(video.formattedSize) → Converted: \(outputMB)")

                let historyPath = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".shrink-videos.history.csv").path
                let now = ISO8601DateFormatter()
                now.formatOptions = [.withInternetDateTime]
                now.timeZone = .current
                let when = now.string(from: Date())
                let csvLine = "\(when),\(video.filename),\(video.fileSize),\(outputSize)\n"
                if let handle = FileHandle(forWritingAtPath: historyPath) {
                    handle.seekToEndOfFile()
                    handle.write(csvLine.data(using: .utf8)!)
                    handle.closeFile()
                } else {
                    let header = "when,filename,original_size,new_size\n"
                    try (header + csvLine).write(toFile: historyPath, atomically: true, encoding: .utf8)
                }

                if add || replace {
                    print("Adding to Photos library...")
                    try await PhotosLibrary.addToLibrary(
                        videoURL: outputURL,
                        originalAsset: video.asset,
                        caption: "(shrunk with shrink-videos; original Motion-JPEG file was \(video.filename) which was \(video.formattedSize))"
                    )
                    print("Added to Photos library.")

                    if replace {
                        print("Deleting original from Photos library...")
                        try await PhotosLibrary.deleteAsset(video.asset)
                        print("Original moved to Recently Deleted.")
                    }
                }
            } catch {
                print("Error converting \(video.filename): \(error)")
                Foundation.exit(1)
            }
        }
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        if count >= length { return self }
        return String(repeating: " ", count: length - count) + self
    }
}
