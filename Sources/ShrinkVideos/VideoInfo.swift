//  Copyright © 2026 Avi Flax. ALL RIGHTS RESERVED; see ../COPYRIGHT

import Foundation
import Photos
import AVFoundation

struct VideoInfo {
    let asset: PHAsset
    let avAsset: AVAsset
    let filename: String
    let duration: TimeInterval
    let fileSize: Int64
    let creationDate: Date?
    let width: Int
    let height: Int
    let sourceURL: URL?

    var formattedSize: String {
        let mb = Double(fileSize) / 1_000_000
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1000)
        }
        return String(format: "%.1f MB", mb)
    }

    var formattedDuration: String {
        if duration >= 3600 {
            let h = Int(duration) / 3600
            let m = (Int(duration) % 3600) / 60
            let s = Int(duration) % 60
            return String(format: "%d:%02d:%02d", h, m, s)
        } else if duration >= 60 {
            let m = Int(duration) / 60
            let s = Int(duration) % 60
            return String(format: "%d:%02d", m, s)
        }
        return String(format: "%.1fs", duration)
    }

    var summary: String {
        let dateStr: String
        if let date = creationDate {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateStr = fmt.string(from: date)
        } else {
            dateStr = "unknown date"
        }
        return "\(filename) | \(width)x\(height) | \(formattedDuration) | \(formattedSize) | \(dateStr)"
    }
}
