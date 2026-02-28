import SwiftUI
import SwiftData

/// The AI Coach tab - shows training insights, weekly plan, and chat-like recommendations.
struct AICoachView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ErgScore.date, order: .reverse) private var scores: [ErgScore]
    @Query(sort: \WorkoutPlan.scheduledDate) private var plans: [WorkoutPlan]
    @Query private var profiles: [AthleteProfile]

    @StateObject private var aiCoach = AICoachService()

    @State private var selectedTab = 0
    @State private var showingWeeklyPlan = false

    private var profile: AthleteProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Tab picker
                    Picker("View", selection: $selectedTab) {
                        Text("Today").tag(0)
                        Text("Weekly Plan").tag(1)
                        Text("Insights").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch selectedTab {
                    case 0: todayView
                    case 1: weeklyPlanView
                    case 2: insightsView
                    default: todayView
                    }
                }
                .padding()
            }
            .navigationTitle("AI Coach")
        }
    }

    // MARK: - Today's Recommendation

    private var todayView: some View {
        VStack(spacing: 20) {
            // Coach avatar / header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.blue.gradient)
                        .frame(width: 50, height: 50)
                    Image(systemName: "brain")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your AI Coach")
                        .font(.headline)
                    Text(coachGreeting)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let rec = aiCoach.todayRecommendation {
                // Today's workout card
                todayWorkoutCard(rec)

                // Quick insights
                if !aiCoach.insights.isEmpty {
                    insightsList(aiCoach.insights.prefix(3).map { $0 })
                }
            } else {
                // Generate recommendation
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)

                    Text("Ready for today's plan?")
                        .font(.title3.bold())

                    Text("I'll analyze your recent training and generate a personalized workout recommendation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        generateTodayPlan()
                    } label: {
                        Label("Generate Plan", systemImage: "wand.and.stars")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.vertical, 24)
            }

            // Training philosophy based on their level
            if let p = profile {
                coachingTip(for: p)
            }
        }
    }

    private func todayWorkoutCard(_ rec: AICoachService.CoachRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(rec.category.rawValue, systemImage: categoryIcon(rec.category))
                    .font(.caption.bold())
                    .foregroundStyle(categoryColor(rec.category))
                Spacer()
                difficultyBadge(rec.suggestedWorkout?.difficultyRating ?? 5)
            }

            Text(rec.title)
                .font(.title3.bold())

            Text(rec.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let workout = rec.suggestedWorkout {
                Divider()

                // Workout details
                VStack(alignment: .leading, spacing: 8) {
                    if let desc = workout.workoutDescription.split(separator: "\n").first {
                        Text(desc)
                            .font(.subheadline)
                    }

                    HStack(spacing: 16) {
                        if let split = workout.formattedTargetSplit {
                            Label(split, systemImage: "speedometer")
                                .font(.caption)
                        }
                        if let sr = workout.targetStrokeRate {
                            Label("\(sr) s/m", systemImage: "metronome")
                                .font(.caption)
                        }
                        if let zone = workout.targetHeartRateZone {
                            Label("Zone \(zone)", systemImage: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if let intervals = workout.intervals {
                        ForEach(intervals, id: \.self) { interval in
                            Text(interval.description)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    generateTodayPlan()
                } label: {
                    Label("Different Workout", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }

                NavigationLink {
                    if let workout = rec.suggestedWorkout {
                        WorkoutDetailView(workout: workout)
                    }
                } label: {
                    Label("Let's Go", systemImage: "play.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Weekly Plan

    private var weeklyPlanView: some View {
        VStack(spacing: 16) {
            if aiCoach.weeklyPlan.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)

                    Text("Generate Weekly Plan")
                        .font(.title3.bold())

                    Text("I'll create a balanced training week based on your goals, fitness level, and recovery needs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        generateWeeklyPlan()
                    } label: {
                        Label("Create Plan", systemImage: "wand.and.stars")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.vertical, 24)
            } else {
                ForEach(Array(aiCoach.weeklyPlan.enumerated()), id: \.offset) { index, plan in
                    weeklyPlanRow(plan, dayNumber: index + 1)
                }

                Button {
                    generateWeeklyPlan()
                } label: {
                    Label("Regenerate Plan", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                }
                .padding(.top, 8)
            }
        }
    }

    private func weeklyPlanRow(_ plan: WorkoutPlan, dayNumber: Int) -> some View {
        NavigationLink {
            WorkoutDetailView(workout: plan)
        } label: {
            HStack(spacing: 12) {
                // Day indicator
                VStack {
                    Text("Day")
                        .font(.caption2)
                    Text("\(dayNumber)")
                        .font(.title3.bold())
                }
                .frame(width: 44)
                .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text(plan.focusArea.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                difficultyBadge(plan.difficultyRating)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Insights

    private var insightsView: some View {
        VStack(spacing: 16) {
            if aiCoach.insights.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)

                    Text("Training Insights")
                        .font(.title3.bold())

                    Text("Log more scores to unlock personalized insights about your training trends, strengths, and areas for improvement.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if scores.count < 5 {
                        Text("\(5 - scores.count) more scores needed for trend analysis")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.blue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.blue)
                    } else {
                        Button {
                            generateInsights()
                        } label: {
                            Label("Analyze Training", systemImage: "wand.and.stars")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.vertical, 24)
            } else {
                insightsList(aiCoach.insights)
            }
        }
    }

    private func insightsList(_ insights: [AICoachService.CoachInsight]) -> some View {
        VStack(spacing: 12) {
            ForEach(insights, id: \.id) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.icon)
                        .font(.title3)
                        .foregroundStyle(trendColor(insight.trend))
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.subheadline.bold())
                        Text(insight.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    trendIndicator(insight.trend)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Coaching Tips

    private func coachingTip(for profile: AthleteProfile) -> some View {
        let tip = getTip(for: profile)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Coach's Tip")
                    .font(.caption.bold())
            }
            Text(tip)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.yellow.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var coachGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning! Ready to train?" }
        if hour < 17 { return "Good afternoon! Let's get some meters in." }
        return "Good evening! Time for a session?"
    }

    private func generateTodayPlan() {
        guard let p = profile else { return }
        _ = aiCoach.generateDailyRecommendation(profile: p, recentScores: Array(scores), recentPlans: Array(plans))
    }

    private func generateWeeklyPlan() {
        guard let p = profile else { return }
        _ = aiCoach.generateWeeklyPlan(profile: p, recentScores: Array(scores))
    }

    private func generateInsights() {
        guard let p = profile, let latest = scores.first else { return }
        _ = aiCoach.analyzeScore(latest, profile: p, history: Array(scores))
    }

    private func categoryIcon(_ cat: AICoachService.CoachRecommendation.Category) -> String {
        switch cat {
        case .workout: return "figure.rowing"
        case .recovery: return "bed.double.fill"
        case .technique: return "hand.raised.fill"
        case .milestone: return "trophy.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private func categoryColor(_ cat: AICoachService.CoachRecommendation.Category) -> Color {
        switch cat {
        case .workout: return .blue
        case .recovery: return .green
        case .technique: return .purple
        case .milestone: return .yellow
        case .warning: return .red
        }
    }

    private func difficultyBadge(_ rating: Int) -> some View {
        let color: Color = rating <= 3 ? .green : (rating <= 6 ? .yellow : (rating <= 8 ? .orange : .red))
        return Text("\(rating)/10")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private func trendColor(_ trend: AICoachService.CoachInsight.Trend) -> Color {
        switch trend {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .blue
        case .neutral: return .secondary
        }
    }

    private func trendIndicator(_ trend: AICoachService.CoachInsight.Trend) -> some View {
        let icon: String
        let color: Color
        switch trend {
        case .improving: icon = "arrow.up.right"; color = .green
        case .declining: icon = "arrow.down.right"; color = .red
        case .stable: icon = "arrow.right"; color = .blue
        case .neutral: icon = "minus"; color = .secondary
        }
        return Image(systemName: icon)
            .font(.caption)
            .foregroundStyle(color)
    }

    private func getTip(for profile: AthleteProfile) -> String {
        let tips: [String: [String]] = [
            "beginner": [
                "Focus on steady state. 80% of your training should be at an easy, conversational pace. This builds the aerobic engine that powers everything.",
                "Don't rate too high early on. Keep stroke rate at 18-22 for most pieces and let the power come from leg drive.",
                "Consistency beats intensity. Five 30-minute sessions at easy pace will improve you faster than two all-out pieces."
            ],
            "intermediate": [
                "The 80/20 rule: 80% of your meters should be steady state (Zone 2), 20% should be harder work. Most people do too much hard work.",
                "If your 2k has plateaued, add more steady state volume before adding more intensity. The base is the bottleneck.",
                "Rate 18 steady state teaches you to generate power through length and connection, not just speeding up the slide."
            ],
            "advanced": [
                "At your level, marginal gains come from technique refinement and consistency. Film yourself and compare to elite rowers.",
                "Consider periodizing your training: 4-6 weeks base, 4 weeks build, 2 weeks peak, 1 week taper before a test.",
                "Heart rate variability (HRV) tracking with your Polar can help identify when you're recovered enough for hard sessions."
            ],
            "elite": [
                "Trust the process. At the elite level, gains are small and require patience. Focus on the controllables: sleep, nutrition, consistency.",
                "Use the Polar H10's R-R interval data to track your HRV trends for optimal training load management."
            ]
        ]

        let level = profile.rowingExperience
        return tips[level]?.randomElement() ?? tips["intermediate"]!.randomElement()!
    }
}
