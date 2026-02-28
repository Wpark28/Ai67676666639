import Foundation
import SwiftData

/// Represents heart rate data from a Polar H10/H9 monitor session.
@Model
final class HeartRateData {
    var id: UUID
    var timestamp: Date
    var heartRate: Int              // BPM
    var rrIntervals: [Double]?      // R-R intervals in ms (Polar H10 feature)
    var sessionId: UUID?            // Links to a workout session

    init(heartRate: Int, sessionId: UUID? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.heartRate = heartRate
        self.sessionId = sessionId
    }
}

/// A full heart rate session from a workout.
@Model
final class HeartRateSession {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var averageHR: Int
    var maxHR: Int
    var minHR: Int
    var timeInZones: [Double]      // seconds spent in each zone (5 zones)
    var dataPoints: [Int]          // all HR readings in order
    var dataTimestamps: [Date]     // timestamps for each reading

    init() {
        self.id = UUID()
        self.startTime = Date()
        self.averageHR = 0
        self.maxHR = 0
        self.minHR = 999
        self.timeInZones = [0, 0, 0, 0, 0]
        self.dataPoints = []
        self.dataTimestamps = []
    }

    func addReading(_ hr: Int) {
        dataPoints.append(hr)
        dataTimestamps.append(Date())

        if hr > maxHR { maxHR = hr }
        if hr < minHR { minHR = hr }

        let sum = dataPoints.reduce(0, +)
        averageHR = sum / dataPoints.count
    }
}

/// Heart rate training zones based on max HR.
struct HeartRateZones {
    let maxHR: Int

    var zone1Range: ClosedRange<Int> { // Recovery / Easy
        let low = Int(Double(maxHR) * 0.50)
        let high = Int(Double(maxHR) * 0.60)
        return low...high
    }

    var zone2Range: ClosedRange<Int> { // Aerobic / Steady State
        let low = Int(Double(maxHR) * 0.60)
        let high = Int(Double(maxHR) * 0.70)
        return low...high
    }

    var zone3Range: ClosedRange<Int> { // Tempo / Threshold
        let low = Int(Double(maxHR) * 0.70)
        let high = Int(Double(maxHR) * 0.80)
        return low...high
    }

    var zone4Range: ClosedRange<Int> { // Anaerobic
        let low = Int(Double(maxHR) * 0.80)
        let high = Int(Double(maxHR) * 0.90)
        return low...high
    }

    var zone5Range: ClosedRange<Int> { // Max effort
        let low = Int(Double(maxHR) * 0.90)
        return low...maxHR
    }

    func zone(for hr: Int) -> Int {
        if zone1Range.contains(hr) { return 1 }
        if zone2Range.contains(hr) { return 2 }
        if zone3Range.contains(hr) { return 3 }
        if zone4Range.contains(hr) { return 4 }
        if zone5Range.contains(hr) { return 5 }
        return hr < zone1Range.lowerBound ? 0 : 5
    }

    func zoneName(_ zone: Int) -> String {
        switch zone {
        case 1: return "Recovery"
        case 2: return "Steady State"
        case 3: return "Tempo"
        case 4: return "Anaerobic"
        case 5: return "Max Effort"
        default: return "Rest"
        }
    }

    func zoneColor(_ zone: Int) -> String {
        switch zone {
        case 1: return "zoneBlue"
        case 2: return "zoneGreen"
        case 3: return "zoneYellow"
        case 4: return "zoneOrange"
        case 5: return "zoneRed"
        default: return "gray"
        }
    }
}
