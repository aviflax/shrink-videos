import AVFoundation
import CoreMedia

enum VideoInspector {
    static func isMJPEG(_ avAsset: AVAsset) async -> Bool {
        do {
            let videoTracks = try await avAsset.loadTracks(withMediaType: .video)
            guard let track = videoTracks.first else { return false }

            let formatDescriptions = try await track.load(.formatDescriptions)
            for desc in formatDescriptions {
                let subType = CMFormatDescriptionGetMediaSubType(desc)
                // kCMVideoCodecType_JPEG = 'jpeg' = 0x6A706567
                // kCMVideoCodecType_JPEG_OpenDML = 'dmb1' = 0x646D6231
                if subType == kCMVideoCodecType_JPEG || subType == kCMVideoCodecType_JPEG_OpenDML {
                    return true
                }
            }
        } catch {
            // If we can't inspect, skip this asset
        }
        return false
    }

    static func codecName(for avAsset: AVAsset) async -> String? {
        do {
            let videoTracks = try await avAsset.loadTracks(withMediaType: .video)
            guard let track = videoTracks.first else { return nil }

            let formatDescriptions = try await track.load(.formatDescriptions)
            guard let desc = formatDescriptions.first else { return nil }

            let subType = CMFormatDescriptionGetMediaSubType(desc)
            let bytes = withUnsafeBytes(of: subType.bigEndian) { Array($0) }
            return String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces)
        } catch {
            return nil
        }
    }
}
