import Foundation
import SwiftData

/// The athlete's profile containing personal info and training history summary.
@Model
final class AthleteProfile {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date

    // Personal info
    var name: String
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var gender: String                  // "male", "female", "other"
    var rowingExperience: String        // "beginner", "intermediate", "advanced", "elite"

    // Physiological data
    var restingHeartRate: Int?
    var maxHeartRate: Int?
    var estimatedVO2Max: Double?

    // Personal records (stored as split in seconds per 500m)
    var pr2kSplit: Double?
    var pr2kTime: Double?
    var pr5kSplit: Double?
    var pr5kTime: Double?
    var pr6kSplit: Double?
    var pr6kTime: Double?
    var pr30minDistance: Int?
    var pr60minDistance: Int?
    var pr500mTime: Double?
    var pr100mTime: Double?

    // Training preferences
    var weeklySessionsGoal: Int
    var weeklyMetersGoal: Int
    var primaryGoal: String             // "2k_pr", "fitness", "weight_loss", "marathon", "competitive"
    var availableDaysPerWeek: Int

    // AI learning data
    var steadyStateSplitRange: String?  // e.g., "2:05-2:15"
    var intervalSplitRange: String?     // e.g., "1:45-1:55"
    var totalLifetimeMeters: Int
    var totalWorkouts: Int
    var currentWeekMeters: Int
    var currentWeekSessions: Int
    var streakDays: Int

    // Fitness trend tracking
    var fitnessScore: Double            // 0-100, calculated from recent performance
    var fatigueScore: Double            // 0-100, calculated from training load
    var formScore: Double               // fitness - fatigue

    init(name: String = "", age: Int = 25, weightKg: Double = 80, heightCm: Double = 180, gender: String = "male") {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.name = name
        self.age = age
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.gender = gender
        self.rowingExperience = "intermediate"
        self.weeklySessionsGoal = 5
        self.weeklyMetersGoal = 50000
        self.primaryGoal = "2k_pr"
        self.availableDaysPerWeek = 5
        self.totalLifetimeMeters = 0
        self.totalWorkouts = 0
        self.currentWeekMeters = 0
        self.currentWeekSessions = 0
        self.streakDays = 0
        self.fitnessScore = 50
        self.fatigueScore = 20
        self.formScore = 30
    }

    /// Estimated max HR using age formula if not manually set.
    var effectiveMaxHR: Int {
        maxHeartRate ?? (220 - age)
    }

    /// Heart rate zones for this athlete.
    var heartRateZones: HeartRateZones {
        HeartRateZones(maxHR: effectiveMaxHR)
    }

    /// Update personal records from a new score.
    func updatePRs(from score: ErgScore) {
        switch score.workoutType {
        case "2k":
            if score.distanceMeters >= 2000 {
                if pr2kTime == nil || score.timeSeconds < pr2kTime! {
                    pr2kTime = score.timeSeconds
                    pr2kSplit = score.splitSeconds
                }
            }
        case "5k":
            if score.distanceMeters >= 5000 {
                if pr5kTime == nil || score.timeSeconds < pr5kTime! {
                    pr5kTime = score.timeSeconds
                    pr5kSplit = score.splitSeconds
                }
            }
        case "6k":
            if score.distanceMeters >= 6000 {
                if pr6kTime == nil || score.timeSeconds < pr6kTime! {
                    pr6kTime = score.timeSeconds
                    pr6kSplit = score.splitSeconds
                }
            }
        case "30min":
            if let current = pr30minDistance {
                if score.distanceMeters > current {
                    pr30minDistance = score.distanceMeters
                }
            } else {
                pr30minDistance = score.distanceMeters
            }
        case "60min":
            if let current = pr60minDistance {
                if score.distanceMeters > current {
                    pr60minDistance = score.distanceMeters
                }
            } else {
                pr60minDistance = score.distanceMeters
            }
        default:
            break
        }

        totalWorkouts += 1
        totalLifetimeMeters += score.distanceMeters
        currentWeekSessions += 1
        currentWeekMeters += score.distanceMeters
        updatedAt = Date()
    }
}
