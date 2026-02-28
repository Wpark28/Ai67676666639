import Foundation
import SwiftData

/// Daily recovery, strain, energy, and sleep data aggregated from Apple Watch Ultra + activity.
@Model
final class DailyStatus {
    var id: UUID
    var date: Date

    // Recovery Score (0-100, calculated from Apple Watch data)
    var recoveryScore: Double
    var recoveryTrend: String           // "improving", "declining", "stable"

    // Sleep
    var sleepStartTime: Date?
    var sleepEndTime: Date?
    var totalSleepMinutes: Int
    var remSleepMinutes: Int
    var deepSleepMinutes: Int
    var lightSleepMinutes: Int
    var awakeMinutes: Int
    var sleepScore: Double              // 0-100

    // Apple Watch Ultra biometrics (pulled from HealthKit)
    var restingHeartRate: Double?       // bpm
    var heartRateVariability: Double?   // ms (SDNN)
    var respiratoryRate: Double?        // breaths/min
    var bloodOxygen: Double?            // SpO2 percentage
    var wristTemperature: Double?       // deviation from baseline in °C
    var bodyTemperature: Double?        // if available

    // Strain (0-100 scale, accumulates through the day)
    var strainScore: Double
    var strainBreakdown: [String: Double]   // "rowing": 35, "gym": 25, "walking": 10

    // Energy (starts at 100, decreases with activity)
    var energyLevel: Double             // 0-100, starts at recovery score and decreases
    var energyBaseline: Double          // Starting energy based on recovery/sleep
    var energyDrains: [EnergyDrain]     // Log of what drained energy

    // Activity
    var activeCaloriesBurned: Int
    var totalCaloriesBurned: Int        // active + BMR
    var stepsCount: Int
    var activeMinutes: Int
    var maxHeartRate: Int?
    var averageHeartRate: Int?

    init(date: Date = Date()) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.recoveryScore = 50
        self.recoveryTrend = "stable"
        self.totalSleepMinutes = 0
        self.remSleepMinutes = 0
        self.deepSleepMinutes = 0
        self.lightSleepMinutes = 0
        self.awakeMinutes = 0
        self.sleepScore = 0
        self.strainScore = 0
        self.strainBreakdown = [:]
        self.energyLevel = 100
        self.energyBaseline = 100
        self.energyDrains = []
        self.activeCaloriesBurned = 0
        self.totalCaloriesBurned = 0
        self.stepsCount = 0
        self.activeMinutes = 0
    }

    var totalSleepHours: Double { Double(totalSleepMinutes) / 60.0 }

    var formattedSleepDuration: String {
        let hours = totalSleepMinutes / 60
        let mins = totalSleepMinutes % 60
        return "\(hours)h \(mins)m"
    }

    var recoveryCategory: RecoveryCategory {
        if recoveryScore >= 67 { return .green }
        if recoveryScore >= 34 { return .yellow }
        return .red
    }

    var strainCategory: String {
        if strainScore < 25 { return "Light" }
        if strainScore < 50 { return "Moderate" }
        if strainScore < 75 { return "High" }
        return "Overreaching"
    }

    var energyCategory: String {
        if energyLevel >= 70 { return "High" }
        if energyLevel >= 40 { return "Moderate" }
        if energyLevel >= 20 { return "Low" }
        return "Depleted"
    }

    /// Drain energy based on an activity.
    mutating func drainEnergy(amount: Double, source: String, durationMinutes: Int) {
        let drain = EnergyDrain(source: source, amount: amount, time: Date(), durationMinutes: durationMinutes)
        energyDrains.append(drain)
        energyLevel = max(0, energyLevel - amount)
    }

    /// Add strain from an activity.
    mutating func addStrain(_ strain: Double, source: String) {
        strainBreakdown[source] = (strainBreakdown[source] ?? 0) + strain
        strainScore = min(100, strainBreakdown.values.reduce(0, +))
    }
}

/// Tracks what drained energy throughout the day.
struct EnergyDrain: Codable, Hashable, Identifiable {
    var id = UUID()
    var source: String          // "Erg - 60min SS", "Gym - Push Day", "Walking", "Work Stress"
    var amount: Double          // How much energy it cost (0-100 scale contribution)
    var time: Date
    var durationMinutes: Int
}

/// Recovery category for color coding.
enum RecoveryCategory: String, Codable {
    case green = "green"
    case yellow = "yellow"
    case red = "red"

    var label: String {
        switch self {
        case .green: return "Recovered"
        case .yellow: return "Moderate"
        case .red: return "Under-recovered"
        }
    }

    var recommendation: String {
        switch self {
        case .green: return "You're well recovered. Great day for high-intensity or test pieces."
        case .yellow: return "Moderate recovery. Steady state or moderate intensity recommended."
        case .red: return "Under-recovered. Prioritize rest, easy movement, or take the day off."
        }
    }
}

/// Historical recovery trends for long-term tracking.
@Model
final class RecoveryTrend {
    var id: UUID
    var weekStartDate: Date
    var averageRecovery: Double
    var averageSleep: Double        // hours
    var averageStrain: Double
    var averageHRV: Double?
    var averageRHR: Double?

    init(weekStartDate: Date) {
        self.id = UUID()
        self.weekStartDate = weekStartDate
        self.averageRecovery = 0
        self.averageSleep = 0
        self.averageStrain = 0
    }
}
