import Foundation
import SwiftData

/// A single set within an exercise.
struct LiftSet: Codable, Hashable, Identifiable {
    var id = UUID()
    var reps: Int
    var weightKg: Double
    var rpe: Double?            // Rate of Perceived Exertion 1-10
    var isWarmup: Bool
    var isDropSet: Bool
    var isFailure: Bool         // Hit failure on this set

    var weightLbs: Double { weightKg * 2.20462 }

    var volume: Double { Double(reps) * weightKg }

    init(reps: Int, weightKg: Double, rpe: Double? = nil, isWarmup: Bool = false, isDropSet: Bool = false, isFailure: Bool = false) {
        self.reps = reps
        self.weightKg = weightKg
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.isDropSet = isDropSet
        self.isFailure = isFailure
    }
}

/// A single exercise performed during a gym session.
@Model
final class GymExercise {
    var id: UUID
    var name: String
    var muscleGroup: String         // "chest", "back", "legs", "shoulders", "arms", "core", "full_body"
    var category: String            // "barbell", "dumbbell", "machine", "cable", "bodyweight", "cardio"
    var sets: [LiftSet]
    var notes: String?
    var orderIndex: Int             // Order within the session

    init(name: String, muscleGroup: String, category: String = "barbell") {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.category = category
        self.sets = []
        self.orderIndex = 0
    }

    var workingSets: [LiftSet] { sets.filter { !$0.isWarmup } }
    var totalVolume: Double { workingSets.reduce(0) { $0 + $1.volume } }
    var topSetWeight: Double { workingSets.map(\.weightKg).max() ?? 0 }
    var topSetReps: Int {
        guard let maxWeight = workingSets.map(\.weightKg).max() else { return 0 }
        return workingSets.filter { $0.weightKg == maxWeight }.map(\.reps).max() ?? 0
    }

    /// Estimated 1RM using Epley formula
    var estimated1RM: Double {
        guard let bestSet = workingSets.max(by: { ($0.weightKg * (1 + Double($0.reps) / 30)) < ($1.weightKg * (1 + Double($1.reps) / 30)) }) else { return 0 }
        if bestSet.reps == 1 { return bestSet.weightKg }
        return bestSet.weightKg * (1 + Double(bestSet.reps) / 30)
    }
}

/// A full gym session containing multiple exercises.
@Model
final class GymSession {
    var id: UUID
    var date: Date
    var startTime: Date
    var endTime: Date?
    var sessionName: String         // "Push Day", "Pull Day", "Leg Day", etc.
    var sessionType: String         // "push", "pull", "legs", "upper", "lower", "full_body", "custom"
    var exercises: [GymExercise]
    var notes: String?

    // Metrics
    var totalVolume: Double         // Total weight x reps
    var totalSets: Int
    var durationMinutes: Int
    var caloriesBurned: Int?
    var averageHeartRate: Int?

    // Strain contribution
    var strainScore: Double         // 0-21 scale like WHOOP

    init(sessionName: String, sessionType: String = "custom") {
        self.id = UUID()
        self.date = Date()
        self.startTime = Date()
        self.sessionName = sessionName
        self.sessionType = sessionType
        self.exercises = []
        self.totalVolume = 0
        self.totalSets = 0
        self.durationMinutes = 0
        self.strainScore = 0
    }

    func recalculate() {
        totalVolume = exercises.reduce(0) { $0 + $1.totalVolume }
        totalSets = exercises.reduce(0) { $0 + $1.workingSets.count }
        if let end = endTime {
            durationMinutes = Int(end.timeIntervalSince(startTime) / 60)
        }
    }

    var formattedVolume: String {
        if totalVolume >= 1000 {
            return String(format: "%.1fk kg", totalVolume / 1000)
        }
        return String(format: "%.0f kg", totalVolume)
    }
}

/// Library of known exercises with muscle group mappings.
struct ExerciseLibrary {
    static let exercises: [(name: String, muscle: String, category: String)] = [
        // Chest
        ("Bench Press", "chest", "barbell"),
        ("Incline Bench Press", "chest", "barbell"),
        ("Dumbbell Bench Press", "chest", "dumbbell"),
        ("Incline Dumbbell Press", "chest", "dumbbell"),
        ("Cable Fly", "chest", "cable"),
        ("Dips (Chest)", "chest", "bodyweight"),
        ("Machine Chest Press", "chest", "machine"),
        ("Push Ups", "chest", "bodyweight"),

        // Back
        ("Barbell Row", "back", "barbell"),
        ("Deadlift", "back", "barbell"),
        ("Pull Ups", "back", "bodyweight"),
        ("Chin Ups", "back", "bodyweight"),
        ("Lat Pulldown", "back", "cable"),
        ("Seated Cable Row", "back", "cable"),
        ("Dumbbell Row", "back", "dumbbell"),
        ("T-Bar Row", "back", "barbell"),
        ("Face Pulls", "back", "cable"),

        // Legs
        ("Squat", "legs", "barbell"),
        ("Front Squat", "legs", "barbell"),
        ("Leg Press", "legs", "machine"),
        ("Romanian Deadlift", "legs", "barbell"),
        ("Leg Extension", "legs", "machine"),
        ("Leg Curl", "legs", "machine"),
        ("Bulgarian Split Squat", "legs", "dumbbell"),
        ("Calf Raises", "legs", "machine"),
        ("Hip Thrust", "legs", "barbell"),
        ("Lunges", "legs", "dumbbell"),

        // Shoulders
        ("Overhead Press", "shoulders", "barbell"),
        ("Dumbbell Shoulder Press", "shoulders", "dumbbell"),
        ("Lateral Raise", "shoulders", "dumbbell"),
        ("Front Raise", "shoulders", "dumbbell"),
        ("Rear Delt Fly", "shoulders", "dumbbell"),
        ("Arnold Press", "shoulders", "dumbbell"),
        ("Upright Row", "shoulders", "barbell"),

        // Arms
        ("Barbell Curl", "arms", "barbell"),
        ("Dumbbell Curl", "arms", "dumbbell"),
        ("Hammer Curl", "arms", "dumbbell"),
        ("Tricep Pushdown", "arms", "cable"),
        ("Skull Crushers", "arms", "barbell"),
        ("Overhead Tricep Extension", "arms", "dumbbell"),
        ("Preacher Curl", "arms", "barbell"),
        ("Dips (Tricep)", "arms", "bodyweight"),

        // Core
        ("Plank", "core", "bodyweight"),
        ("Hanging Leg Raise", "core", "bodyweight"),
        ("Cable Crunch", "core", "cable"),
        ("Ab Wheel Rollout", "core", "bodyweight"),
        ("Russian Twist", "core", "bodyweight"),
    ]

    static func search(_ query: String) -> [(name: String, muscle: String, category: String)] {
        if query.isEmpty { return exercises }
        return exercises.filter { $0.name.lowercased().contains(query.lowercased()) }
    }

    static func byMuscle(_ muscle: String) -> [(name: String, muscle: String, category: String)] {
        exercises.filter { $0.muscle == muscle }
    }
}
