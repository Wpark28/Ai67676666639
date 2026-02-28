import SwiftUI
import SwiftData

@main
struct ErgAIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            ErgScore.self,
            HeartRateData.self,
            HeartRateSession.self,
            AthleteProfile.self,
            WorkoutPlan.self,
            WeekSummary.self
        ])
    }
}
