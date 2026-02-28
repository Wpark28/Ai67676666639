import Foundation
import SwiftData

/// Represents a single erg (ergometer) score captured via photo or manual entry.
@Model
final class ErgScore {
    var id: UUID
    var date: Date

    // Core split/pace data
    var distanceMeters: Int
    var timeSeconds: Double
    var splitSeconds: Double       // /500m split
    var strokeRate: Int            // strokes per minute
    var averageWatts: Double
    var calories: Int
    var averageDragFactor: Int?

    // Piece type
    var workoutType: String        // "2k", "5k", "6k", "30min", "60min", "interval", "steady_state"
    var intervalNumber: Int?       // for interval pieces
    var restSeconds: Double?       // rest between intervals

    // Heart rate data (if HR monitor was connected)
    var averageHeartRate: Int?
    var maxHeartRate: Int?

    // OCR capture metadata
    var capturedFromPhoto: Bool
    var ocrConfidence: Double?     // 0.0 - 1.0
    var rawOCRText: String?

    // Photo reference
    var photoData: Data?

    // Notes
    var notes: String?

    init(
        distanceMeters: Int,
        timeSeconds: Double,
        splitSeconds: Double,
        strokeRate: Int,
        averageWatts: Double = 0,
        calories: Int = 0,
        workoutType: String = "2k",
        capturedFromPhoto: Bool = false
    ) {
        self.id = UUID()
        self.date = Date()
        self.distanceMeters = distanceMeters
        self.timeSeconds = timeSeconds
        self.splitSeconds = splitSeconds
        self.strokeRate = strokeRate
        self.averageWatts = averageWatts
        self.calories = calories
        self.workoutType = workoutType
        self.capturedFromPhoto = capturedFromPhoto
    }

    /// Formatted split time string (e.g., "1:45.3")
    var formattedSplit: String {
        let minutes = Int(splitSeconds) / 60
        let seconds = splitSeconds - Double(minutes * 60)
        return String(format: "%d:%04.1f", minutes, seconds)
    }

    /// Formatted total time string (e.g., "6:32.4")
    var formattedTime: String {
        let minutes = Int(timeSeconds) / 60
        let seconds = timeSeconds - Double(minutes * 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%04.1f", hours, remainingMinutes, seconds)
        }
        return String(format: "%d:%04.1f", minutes, seconds)
    }

    /// Formatted distance string
    var formattedDistance: String {
        if distanceMeters >= 1000 {
            return String(format: "%.1fk", Double(distanceMeters) / 1000.0)
        }
        return "\(distanceMeters)m"
    }

    /// Calculate watts from split if not provided
    static func wattsFromSplit(_ splitSeconds: Double) -> Double {
        // Concept2 formula: P = 2.80 / (split/500)^3
        let pace = splitSeconds / 500.0
        return 2.80 / pow(pace, 3)
    }
}
