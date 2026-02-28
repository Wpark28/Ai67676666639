import Foundation
import SwiftData
import Combine

/// The AI Coach engine that analyzes athlete performance, learns patterns over time,
/// and generates personalized training plans and recommendations.
final class AICoachService: ObservableObject {

    @Published var todayRecommendation: CoachRecommendation?
    @Published var weeklyPlan: [WorkoutPlan] = []
    @Published var insights: [CoachInsight] = []
    @Published var isAnalyzing = false

    // MARK: - Types

    struct CoachRecommendation {
        let title: String
        let message: String
        let suggestedWorkout: WorkoutPlan?
        let priority: Priority
        let category: Category

        enum Priority: Int, Comparable {
            case low = 1, medium = 2, high = 3, critical = 4
            static func < (lhs: Priority, rhs: Priority) -> Bool { lhs.rawValue < rhs.rawValue }
        }

        enum Category: String {
            case workout = "Workout"
            case recovery = "Recovery"
            case technique = "Technique"
            case milestone = "Milestone"
            case warning = "Warning"
        }
    }

    struct CoachInsight {
        let id = UUID()
        let title: String
        let detail: String
        let icon: String        // SF Symbol name
        let trend: Trend
        let date: Date

        enum Trend {
            case improving, declining, stable, neutral
        }
    }

    // MARK: - Core Analysis

    /// Generate today's recommendation based on athlete profile and history.
    func generateDailyRecommendation(profile: AthleteProfile, recentScores: [ErgScore], recentPlans: [WorkoutPlan]) -> CoachRecommendation {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Check for recovery needs first
        if let recoveryRec = checkRecoveryNeeds(profile: profile, recentScores: recentScores) {
            return recoveryRec
        }

        // Determine what type of workout is most needed
        let workoutDistribution = analyzeWorkoutDistribution(recentScores: recentScores)
        let fitnessPhase = determineFitnessPhase(profile: profile)
        let todayType = selectWorkoutType(distribution: workoutDistribution, phase: fitnessPhase, profile: profile)

        // Generate the workout
        let workout = generateWorkout(type: todayType, profile: profile, recentScores: recentScores)

        let recommendation = CoachRecommendation(
            title: workout.title,
            message: workout.aiReasoning,
            suggestedWorkout: workout,
            priority: .medium,
            category: .workout
        )

        todayRecommendation = recommendation
        return recommendation
    }

    /// Generate a full weekly training plan.
    func generateWeeklyPlan(profile: AthleteProfile, recentScores: [ErgScore]) -> [WorkoutPlan] {
        isAnalyzing = true
        defer { isAnalyzing = false }

        var plans: [WorkoutPlan] = []
        let sessionsPerWeek = min(profile.availableDaysPerWeek, profile.weeklySessionsGoal)
        let phase = determineFitnessPhase(profile: profile)

        // Standard training distribution
        let distribution = getWeeklyDistribution(sessions: sessionsPerWeek, phase: phase)

        for (dayOffset, workoutType) in distribution.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
            var workout = generateWorkout(type: workoutType, profile: profile, recentScores: recentScores)
            workout.scheduledDate = date
            plans.append(workout)
        }

        weeklyPlan = plans
        return plans
    }

    /// Analyze a newly logged score and provide feedback.
    func analyzeScore(_ score: ErgScore, profile: AthleteProfile, history: [ErgScore]) -> [CoachInsight] {
        var newInsights: [CoachInsight] = []

        // Compare to PR
        if let prInsight = checkForPR(score: score, profile: profile) {
            newInsights.append(prInsight)
        }

        // Analyze split consistency
        let consistencyInsight = analyzeSplitConsistency(score: score, history: history)
        newInsights.append(consistencyInsight)

        // Trend analysis
        if let trendInsight = analyzeTrend(score: score, history: history) {
            newInsights.append(trendInsight)
        }

        // Heart rate correlation
        if let hrInsight = analyzeHeartRateCorrelation(score: score, history: history) {
            newInsights.append(hrInsight)
        }

        // Volume analysis
        let volumeInsight = analyzeVolume(profile: profile)
        newInsights.append(volumeInsight)

        insights = newInsights
        return newInsights
    }

    // MARK: - Workout Generation

    private func generateWorkout(type: WorkoutType, profile: AthleteProfile, recentScores: [ErgScore]) -> WorkoutPlan {
        switch type {
        case .steadyState:
            return generateSteadyState(profile: profile, recentScores: recentScores)
        case .interval:
            return generateIntervals(profile: profile, recentScores: recentScores)
        case .threshold:
            return generateThreshold(profile: profile, recentScores: recentScores)
        case .test:
            return generateTestPiece(profile: profile)
        case .recovery:
            return generateRecovery(profile: profile)
        case .power:
            return generatePowerSession(profile: profile, recentScores: recentScores)
        }
    }

    private func generateSteadyState(profile: AthleteProfile, recentScores: [ErgScore]) -> WorkoutPlan {
        // Calculate steady state split from recent 2k or best effort
        let ssSplit = calculateSteadyStateSplit(profile: profile, recentScores: recentScores)
        let duration = profile.rowingExperience == "beginner" ? 20 : (profile.rowingExperience == "intermediate" ? 40 : 60)
        let targetSR = profile.rowingExperience == "beginner" ? 18 : 20

        let plan = WorkoutPlan(
            title: "\(duration) Min Steady State",
            workoutDescription: """
                \(duration) minutes of steady state rowing at a conversational pace. \
                Focus on long, powerful strokes with clean technique. \
                Target split: \(formatSplit(ssSplit)) /500m at \(targetSR)-\(targetSR + 2) s/m. \
                Stay in HR Zone 2 (60-70% max HR).
                """,
            workoutType: "steady_state",
            aiReasoning: generateSSReasoning(profile: profile, duration: duration),
            difficultyRating: 4,
            focusArea: "aerobic_base"
        )

        plan.targetTimeSeconds = Double(duration * 60)
        plan.targetSplit = ssSplit
        plan.targetStrokeRate = targetSR
        plan.targetHeartRateZone = 2

        return plan
    }

    private func generateIntervals(profile: AthleteProfile, recentScores: [ErgScore]) -> WorkoutPlan {
        let intervalSplit = calculateIntervalSplit(profile: profile, recentScores: recentScores)
        let targetSR = 26

        // Choose interval structure based on experience
        let intervals: [IntervalBlock]
        let title: String

        switch profile.rowingExperience {
        case "beginner":
            title = "6x500m Intervals"
            intervals = [IntervalBlock(reps: 6, distanceMeters: 500, targetSplit: intervalSplit, targetStrokeRate: targetSR, restSeconds: 120)]
        case "intermediate":
            title = "8x500m Intervals"
            intervals = [IntervalBlock(reps: 8, distanceMeters: 500, targetSplit: intervalSplit, targetStrokeRate: targetSR, restSeconds: 90)]
        case "advanced":
            title = "5x1500m Intervals"
            intervals = [IntervalBlock(reps: 5, distanceMeters: 1500, targetSplit: intervalSplit, targetStrokeRate: 28, restSeconds: 180)]
        default:
            title = "4x2000m Intervals"
            intervals = [IntervalBlock(reps: 4, distanceMeters: 2000, targetSplit: intervalSplit, targetStrokeRate: 28, restSeconds: 240)]
        }

        let plan = WorkoutPlan(
            title: title,
            workoutDescription: """
                \(intervals.first?.description ?? "") at target split \(formatSplit(intervalSplit)) /500m. \
                Push hard during work periods, recover fully during rest. \
                Focus on power application through the drive.
                """,
            workoutType: "interval",
            aiReasoning: "Intervals build lactate tolerance and race-pace familiarity. Your current fitness level suggests \(title.lowercased()) is the right volume.",
            difficultyRating: 7,
            focusArea: "threshold"
        )

        plan.intervals = intervals
        plan.targetSplit = intervalSplit
        plan.targetStrokeRate = targetSR
        plan.targetHeartRateZone = 4

        return plan
    }

    private func generateThreshold(profile: AthleteProfile, recentScores: [ErgScore]) -> WorkoutPlan {
        let thresholdSplit = calculateThresholdSplit(profile: profile, recentScores: recentScores)

        let plan = WorkoutPlan(
            title: "20 Min Threshold",
            workoutDescription: """
                20 minutes at threshold pace (\(formatSplit(thresholdSplit)) /500m). \
                This should feel hard but sustainable. Rate 22-24 s/m. \
                Target HR Zone 3-4 (70-85% max HR). \
                This is the pace between steady state and race pace.
                """,
            workoutType: "steady_state",
            aiReasoning: "Threshold work improves your lactate clearance and raises the ceiling for your steady state pace. Critical for 2k improvement.",
            difficultyRating: 7,
            focusArea: "threshold"
        )

        plan.targetTimeSeconds = 1200
        plan.targetSplit = thresholdSplit
        plan.targetStrokeRate = 23
        plan.targetHeartRateZone = 3

        return plan
    }

    private func generateTestPiece(profile: AthleteProfile) -> WorkoutPlan {
        let testType: String
        switch profile.primaryGoal {
        case "2k_pr": testType = "2k"
        case "fitness": testType = "5k"
        case "marathon": testType = "30min"
        default: testType = "2k"
        }

        let plan = WorkoutPlan(
            title: "\(testType.uppercased()) Test Piece",
            workoutDescription: """
                Full effort \(testType) test. Warm up 10 min easy, 4x30s builds. \
                Race plan: start controlled, build through the middle, \
                sprint the last 500m. Negative split if possible.
                """,
            workoutType: "test",
            aiReasoning: "Based on your training load and recovery status, you're ready for a test piece. Your recent steady state improvements suggest you'll see PR potential.",
            difficultyRating: 10,
            focusArea: "power"
        )

        return plan
    }

    private func generateRecovery(profile: AthleteProfile) -> WorkoutPlan {
        let plan = WorkoutPlan(
            title: "Recovery Row",
            workoutDescription: """
                20-30 minutes very easy rowing. Rate 16-18 s/m, pressure at 50%. \
                Focus purely on technique: clean catch, full compression, \
                relaxed recovery. This is active recovery - keep it light. \
                HR should stay in Zone 1 (below 60% max HR).
                """,
            workoutType: "recovery",
            aiReasoning: "Your recent training load indicates you need active recovery. Easy rowing promotes blood flow and helps clear metabolic waste without adding training stress.",
            difficultyRating: 2,
            focusArea: "recovery"
        )

        plan.targetTimeSeconds = 1500
        plan.targetStrokeRate = 17
        plan.targetHeartRateZone = 1

        return plan
    }

    private func generatePowerSession(profile: AthleteProfile, recentScores: [ErgScore]) -> WorkoutPlan {
        let plan = WorkoutPlan(
            title: "Power Intervals",
            workoutDescription: """
                8x150m all-out sprints with 2 min rest between. \
                Focus on maximum power through the drive. Rate 32-36 s/m. \
                Full recovery between reps - you should be ready to go max each time. \
                Warm up 10 minutes before starting.
                """,
            workoutType: "interval",
            aiReasoning: "Short power work develops your peak wattage and improves neuromuscular recruitment. This carries over to stronger starts and sprint finishes in longer pieces.",
            difficultyRating: 8,
            focusArea: "power"
        )

        plan.intervals = [IntervalBlock(reps: 8, distanceMeters: 150, targetStrokeRate: 34, restSeconds: 120)]
        plan.targetHeartRateZone = 5

        return plan
    }

    // MARK: - Split Calculations

    private func calculateSteadyStateSplit(profile: AthleteProfile, recentScores: [ErgScore]) -> Double {
        // SS split is typically 2k split + 20-25 seconds
        if let pr2k = profile.pr2kSplit {
            return pr2k + 22
        }

        // Estimate from recent scores
        let recentSplits = recentScores.prefix(10).map { $0.splitSeconds }
        if !recentSplits.isEmpty {
            let avgSplit = recentSplits.reduce(0, +) / Double(recentSplits.count)
            return avgSplit + 10 // Add buffer for steady state
        }

        // Default splits by experience
        switch profile.rowingExperience {
        case "beginner": return 135.0   // 2:15
        case "intermediate": return 125.0 // 2:05
        case "advanced": return 115.0    // 1:55
        case "elite": return 105.0       // 1:45
        default: return 125.0
        }
    }

    private func calculateIntervalSplit(profile: AthleteProfile, recentScores: [ErgScore]) -> Double {
        // Interval split is typically 2k split + 3-5 seconds
        if let pr2k = profile.pr2kSplit {
            return pr2k + 4
        }

        let ssSplit = calculateSteadyStateSplit(profile: profile, recentScores: recentScores)
        return ssSplit - 18
    }

    private func calculateThresholdSplit(profile: AthleteProfile, recentScores: [ErgScore]) -> Double {
        // Threshold is between SS and interval pace
        let ss = calculateSteadyStateSplit(profile: profile, recentScores: recentScores)
        let interval = calculateIntervalSplit(profile: profile, recentScores: recentScores)
        return (ss + interval) / 2
    }

    // MARK: - Analysis Helpers

    private enum WorkoutType {
        case steadyState, interval, threshold, test, recovery, power
    }

    private struct WorkoutDistribution {
        var steadyStatePercent: Double
        var intervalPercent: Double
        var testPercent: Double
        var recoveryPercent: Double
    }

    private func analyzeWorkoutDistribution(recentScores: [ErgScore]) -> WorkoutDistribution {
        let recent = Array(recentScores.prefix(20))
        guard !recent.isEmpty else {
            return WorkoutDistribution(steadyStatePercent: 0, intervalPercent: 0, testPercent: 0, recoveryPercent: 0)
        }

        let total = Double(recent.count)
        let ss = Double(recent.filter { $0.workoutType == "steady_state" || $0.workoutType == "other" }.count)
        let intervals = Double(recent.filter { $0.workoutType == "interval" }.count)
        let tests = Double(recent.filter { ["2k", "5k", "6k", "500m"].contains($0.workoutType) }.count)
        let recovery = Double(recent.filter { $0.workoutType == "recovery" }.count)

        return WorkoutDistribution(
            steadyStatePercent: ss / total,
            intervalPercent: intervals / total,
            testPercent: tests / total,
            recoveryPercent: recovery / total
        )
    }

    private func determineFitnessPhase(profile: AthleteProfile) -> String {
        // Determine training phase based on goal and current status
        if profile.totalWorkouts < 10 {
            return "base_building"
        }

        switch profile.primaryGoal {
        case "2k_pr":
            if profile.formScore > 20 {
                return "peak"
            } else if profile.fitnessScore > 60 {
                return "build"
            } else {
                return "base_building"
            }
        case "fitness", "weight_loss":
            return "general_fitness"
        case "marathon":
            return "endurance"
        default:
            return "base_building"
        }
    }

    private func selectWorkoutType(distribution: WorkoutDistribution, phase: String, profile: AthleteProfile) -> WorkoutType {
        // Check if we need recovery
        if profile.fatigueScore > 70 {
            return .recovery
        }

        // Ideal distribution: ~80% low intensity, ~20% high intensity (polarized model)
        switch phase {
        case "base_building":
            if distribution.steadyStatePercent < 0.7 {
                return .steadyState
            }
            return Bool.random() ? .steadyState : .threshold

        case "build":
            if distribution.intervalPercent < 0.2 {
                return .interval
            }
            if distribution.steadyStatePercent < 0.6 {
                return .steadyState
            }
            return [.steadyState, .interval, .threshold].randomElement()!

        case "peak":
            // More intensity, include test pieces
            let options: [WorkoutType] = [.interval, .threshold, .power, .steadyState]
            return options.randomElement()!

        case "general_fitness":
            return [.steadyState, .interval, .steadyState, .recovery].randomElement()!

        case "endurance":
            if distribution.steadyStatePercent < 0.8 {
                return .steadyState
            }
            return .threshold

        default:
            return .steadyState
        }
    }

    private func getWeeklyDistribution(sessions: Int, phase: String) -> [WorkoutType] {
        switch (sessions, phase) {
        case (3, _):
            return [.steadyState, .interval, .steadyState]
        case (4, "base_building"):
            return [.steadyState, .steadyState, .threshold, .steadyState]
        case (4, _):
            return [.steadyState, .interval, .steadyState, .threshold]
        case (5, "base_building"):
            return [.steadyState, .steadyState, .threshold, .steadyState, .recovery]
        case (5, "build"):
            return [.steadyState, .interval, .steadyState, .threshold, .steadyState]
        case (5, "peak"):
            return [.steadyState, .interval, .recovery, .threshold, .power]
        case (6, _):
            return [.steadyState, .interval, .steadyState, .recovery, .threshold, .steadyState]
        case (7, _):
            return [.steadyState, .interval, .steadyState, .recovery, .threshold, .steadyState, .recovery]
        default:
            return [.steadyState, .interval, .steadyState]
        }
    }

    // MARK: - Recovery Analysis

    private func checkRecoveryNeeds(profile: AthleteProfile, recentScores: [ErgScore]) -> CoachRecommendation? {
        // Check if last 3 workouts were all hard
        let lastThree = Array(recentScores.prefix(3))
        let hardCount = lastThree.filter { score in
            ["2k", "5k", "6k", "interval"].contains(score.workoutType)
        }.count

        if hardCount >= 3 {
            let recoveryWorkout = generateRecovery(profile: profile)
            return CoachRecommendation(
                title: "Recovery Day",
                message: "You've had \(hardCount) hard sessions in a row. Your body needs recovery to adapt and get stronger. Take it easy today.",
                suggestedWorkout: recoveryWorkout,
                priority: .high,
                category: .recovery
            )
        }

        // Check for overtraining signals
        if profile.fatigueScore > 80 {
            return CoachRecommendation(
                title: "Rest Day Recommended",
                message: "Your training load is very high. Consider taking a complete rest day or very light recovery row. Pushing through fatigue leads to overtraining.",
                suggestedWorkout: nil,
                priority: .critical,
                category: .warning
            )
        }

        return nil
    }

    // MARK: - Score Analysis

    private func checkForPR(score: ErgScore, profile: AthleteProfile) -> CoachInsight? {
        switch score.workoutType {
        case "2k":
            if let pr = profile.pr2kTime, score.timeSeconds < pr {
                let improvement = pr - score.timeSeconds
                return CoachInsight(
                    title: "New 2K PR!",
                    detail: "You beat your previous best by \(String(format: "%.1f", improvement)) seconds! New PR: \(score.formattedTime).",
                    icon: "trophy.fill",
                    trend: .improving,
                    date: Date()
                )
            }
        case "5k":
            if let pr = profile.pr5kTime, score.timeSeconds < pr {
                return CoachInsight(
                    title: "New 5K PR!",
                    detail: "New personal record on the 5K! Time: \(score.formattedTime).",
                    icon: "trophy.fill",
                    trend: .improving,
                    date: Date()
                )
            }
        default:
            break
        }
        return nil
    }

    private func analyzeSplitConsistency(score: ErgScore, history: [ErgScore]) -> CoachInsight {
        let sameType = history.filter { $0.workoutType == score.workoutType }
        if sameType.count >= 3 {
            let avgSplit = sameType.prefix(5).map { $0.splitSeconds }.reduce(0, +) / Double(min(sameType.count, 5))
            let diff = score.splitSeconds - avgSplit

            if abs(diff) < 1.0 {
                return CoachInsight(
                    title: "Consistent Pacing",
                    detail: "Your \(score.workoutType) splits are very consistent. Good sign of control and fitness.",
                    icon: "checkmark.circle.fill",
                    trend: .stable,
                    date: Date()
                )
            } else if diff < -2.0 {
                return CoachInsight(
                    title: "Faster Than Average",
                    detail: "This piece was \(String(format: "%.1f", abs(diff)))s faster per 500m than your recent average. Great improvement!",
                    icon: "arrow.up.circle.fill",
                    trend: .improving,
                    date: Date()
                )
            } else if diff > 2.0 {
                return CoachInsight(
                    title: "Slower Piece",
                    detail: "This was \(String(format: "%.1f", diff))s slower per 500m than recent average. Could indicate fatigue - consider recovery.",
                    icon: "arrow.down.circle.fill",
                    trend: .declining,
                    date: Date()
                )
            }
        }

        return CoachInsight(
            title: "Score Logged",
            detail: "Keep logging scores so I can track your progress and identify trends.",
            icon: "plus.circle.fill",
            trend: .neutral,
            date: Date()
        )
    }

    private func analyzeTrend(score: ErgScore, history: [ErgScore]) -> CoachInsight? {
        let sameType = history.filter { $0.workoutType == score.workoutType }
        guard sameType.count >= 5 else { return nil }

        let recentFive = Array(sameType.prefix(5))
        let olderFive = sameType.count >= 10 ? Array(sameType[5..<min(10, sameType.count)]) : nil

        guard let older = olderFive, !older.isEmpty else { return nil }

        let recentAvg = recentFive.map { $0.splitSeconds }.reduce(0, +) / Double(recentFive.count)
        let olderAvg = older.map { $0.splitSeconds }.reduce(0, +) / Double(older.count)
        let improvement = olderAvg - recentAvg

        if improvement > 1.0 {
            return CoachInsight(
                title: "Upward Trend",
                detail: "Your \(score.workoutType) pace has improved by \(String(format: "%.1f", improvement))s /500m over recent sessions. Training is working!",
                icon: "chart.line.uptrend.xyaxis",
                trend: .improving,
                date: Date()
            )
        } else if improvement < -1.0 {
            return CoachInsight(
                title: "Performance Dip",
                detail: "Splits have slowed by \(String(format: "%.1f", abs(improvement)))s /500m recently. This could mean fatigue or a need to adjust training.",
                icon: "chart.line.downtrend.xyaxis",
                trend: .declining,
                date: Date()
            )
        }

        return nil
    }

    private func analyzeHeartRateCorrelation(score: ErgScore, history: [ErgScore]) -> CoachInsight? {
        guard let hr = score.averageHeartRate else { return nil }

        let sameTypeWithHR = history.filter { $0.workoutType == score.workoutType && $0.averageHeartRate != nil }
        guard sameTypeWithHR.count >= 3 else { return nil }

        let avgHR = sameTypeWithHR.prefix(5).compactMap { $0.averageHeartRate }.reduce(0, +) / min(sameTypeWithHR.count, 5)

        if hr < avgHR - 5 && score.splitSeconds <= sameTypeWithHR.first!.splitSeconds {
            return CoachInsight(
                title: "Aerobic Improvement",
                detail: "Same pace at lower heart rate (\(hr) vs avg \(avgHR) bpm). Your aerobic engine is getting more efficient!",
                icon: "heart.fill",
                trend: .improving,
                date: Date()
            )
        } else if hr > avgHR + 5 && score.splitSeconds >= sameTypeWithHR.first!.splitSeconds {
            return CoachInsight(
                title: "Higher HR Detected",
                detail: "Heart rate was elevated (\(hr) bpm) for the same pace. Could indicate fatigue, dehydration, or stress.",
                icon: "heart.text.square",
                trend: .declining,
                date: Date()
            )
        }

        return nil
    }

    private func analyzeVolume(profile: AthleteProfile) -> CoachInsight {
        let weeklyProgress = Double(profile.currentWeekMeters) / Double(max(profile.weeklyMetersGoal, 1))

        if weeklyProgress >= 1.0 {
            return CoachInsight(
                title: "Weekly Goal Met!",
                detail: "You've hit \(profile.currentWeekMeters.formatted())m this week - goal achieved! Consider an extra recovery session.",
                icon: "star.fill",
                trend: .improving,
                date: Date()
            )
        } else if weeklyProgress >= 0.7 {
            let remaining = profile.weeklyMetersGoal - profile.currentWeekMeters
            return CoachInsight(
                title: "On Track",
                detail: "\(remaining.formatted())m to go for your weekly goal. You're \(Int(weeklyProgress * 100))% there.",
                icon: "gauge.medium",
                trend: .stable,
                date: Date()
            )
        } else {
            return CoachInsight(
                title: "Volume Check",
                detail: "You're at \(Int(weeklyProgress * 100))% of your weekly meter goal. Keep showing up!",
                icon: "gauge.low",
                trend: .neutral,
                date: Date()
            )
        }
    }

    // MARK: - Helpers

    private func formatSplit(_ seconds: Double) -> String {
        let min = Int(seconds) / 60
        let sec = seconds - Double(min * 60)
        return String(format: "%d:%04.1f", min, sec)
    }

    private func generateSSReasoning(profile: AthleteProfile, duration: Int) -> String {
        let reasons: [String]
        switch profile.rowingExperience {
        case "beginner":
            reasons = [
                "Building your aerobic base is the #1 priority right now. \(duration) minutes at easy pace develops the cardiovascular foundation everything else builds on.",
                "Steady state is where 80% of your improvement comes from. Keep it conversational - if you can't talk, slow down."
            ]
        case "intermediate":
            reasons = [
                "Even at an intermediate level, steady state remains your biggest lever for improvement. This \(duration)-min piece builds mitochondrial density and fat oxidation.",
                "Your aerobic base supports everything: faster 2k times, better recovery between intervals. Keep this easy and long."
            ]
        default:
            reasons = [
                "High-volume steady state at this level continues to drive adaptation. Focus on stroke quality - every meter is an opportunity to refine technique.",
                "Sustained aerobic work at \(duration) minutes pushes your endurance ceiling higher. This directly translates to faster race splits."
            ]
        }
        return reasons.randomElement()!
    }

    // MARK: - Fitness Score Updates

    /// Update the athlete's fitness/fatigue scores based on a new workout.
    func updateFitnessScores(profile: AthleteProfile, score: ErgScore) {
        // Simple training stress score approximation
        let intensityFactor = 1.0 / max(score.splitSeconds / 500.0, 0.01)
        let duration = score.timeSeconds / 3600.0 // hours
        let tss = intensityFactor * duration * 100

        // Exponentially weighted moving average
        let fitnessDecay = 0.95
        let fatigueDecay = 0.85

        profile.fitnessScore = profile.fitnessScore * fitnessDecay + tss * (1 - fitnessDecay)
        profile.fatigueScore = profile.fatigueScore * fatigueDecay + tss * (1 - fatigueDecay)
        profile.formScore = profile.fitnessScore - profile.fatigueScore
    }
}
