import SwiftUI
import SwiftData

/// Main dashboard showing today's recommendation, recent scores, and quick actions.
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ErgScore.date, order: .reverse) private var scores: [ErgScore]
    @Query private var profiles: [AthleteProfile]
    @Query(sort: \DailyStatus.date, order: .reverse) private var statuses: [DailyStatus]
    @Query(sort: \GymSession.date, order: .reverse) private var gymSessions: [GymSession]

    @StateObject private var aiCoach = AICoachService()
    @State private var showingProfileSetup = false

    private var profile: AthleteProfile? { profiles.first }
    private var todayStatus: DailyStatus? { statuses.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome / Profile Header
                    headerSection

                    // Recovery / Strain / Energy at a glance
                    if let status = todayStatus {
                        bodyStatusStrip(status)
                    }

                    // Today's AI Recommendation
                    if let rec = aiCoach.todayRecommendation {
                        recommendationCard(rec)
                    } else {
                        generateRecommendationCard
                    }

                    // Quick Stats
                    quickStatsGrid

                    // Recent Scores
                    recentScoresSection

                    // Fitness Trends
                    if let p = profile {
                        fitnessTrendCard(p)
                    }
                }
                .padding()
            }
            .navigationTitle("ErgAI")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingProfileSetup = true
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingProfileSetup) {
                ProfileSetupView()
            }
            .onAppear {
                if profiles.isEmpty {
                    showingProfileSetup = true
                } else {
                    generateRecommendation()
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let p = profile {
                    Text("Hey, \(p.name.isEmpty ? "Rower" : p.name)")
                        .font(.title2.bold())
                    Text("\(p.currentWeekSessions) sessions this week · \(p.currentWeekMeters.formatted())m")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Welcome to ErgAI")
                        .font(.title2.bold())
                    Text("Set up your profile to get started")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            if let p = profile, p.streakDays > 0 {
                VStack {
                    Text("\(p.streakDays)")
                        .font(.title.bold())
                        .foregroundStyle(.orange)
                    Text("day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recommendation

    private func recommendationCard(_ rec: AICoachService.CoachRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForCategory(rec.category))
                    .foregroundStyle(colorForCategory(rec.category))
                    .font(.title3)
                Text(rec.title)
                    .font(.headline)
                Spacer()
                Text(rec.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colorForCategory(rec.category).opacity(0.15), in: Capsule())
                    .foregroundStyle(colorForCategory(rec.category))
            }

            Text(rec.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if let workout = rec.suggestedWorkout {
                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let split = workout.formattedTargetSplit {
                            Label(split + " /500m", systemImage: "speedometer")
                                .font(.caption)
                        }
                        if let sr = workout.targetStrokeRate {
                            Label("\(sr) s/m", systemImage: "metronome")
                                .font(.caption)
                        }
                    }
                    Spacer()
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        Text("View Workout")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.blue, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var generateRecommendationCard: some View {
        Button {
            generateRecommendation()
        } label: {
            HStack {
                Image(systemName: "brain")
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("Get Today's Recommendation")
                        .font(.headline)
                    Text("AI Coach will analyze your training and suggest a workout")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Stats

    private var quickStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            statCard(
                title: "Total Meters",
                value: profile?.totalLifetimeMeters.formatted() ?? "0",
                icon: "figure.rowing",
                color: .blue
            )
            statCard(
                title: "Workouts",
                value: "\(profile?.totalWorkouts ?? 0)",
                icon: "flame.fill",
                color: .orange
            )
            statCard(
                title: "2K PR",
                value: profile?.pr2kSplit.map { formatSplit($0) } ?? "--",
                icon: "trophy.fill",
                color: .yellow
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Scores

    private var recentScoresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Scores")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    HistoryView()
                }
                .font(.subheadline)
            }

            if scores.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No scores yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Take a photo of your erg screen to get started")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ForEach(Array(scores.prefix(3)), id: \.id) { score in
                    scoreRow(score)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func scoreRow(_ score: ErgScore) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(score.workoutType.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                Text(score.formattedSplit + " /500m")
                    .font(.headline)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(score.formattedDistance)
                    .font(.subheadline)
                Text(score.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if score.capturedFromPhoto {
                Image(systemName: "camera.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Fitness Trend

    private func fitnessTrendCard(_ profile: AthleteProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fitness & Form")
                .font(.headline)

            HStack(spacing: 16) {
                trendBar(label: "Fitness", value: profile.fitnessScore, color: .blue)
                trendBar(label: "Fatigue", value: profile.fatigueScore, color: .red)
                trendBar(label: "Form", value: max(profile.formScore + 50, 0), color: .green)
            }

            Text("Form = Fitness - Fatigue. Higher form means you're ready to race or test.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func trendBar(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(value))")
                .font(.title3.bold())
                .foregroundStyle(color)

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: geo.size.height * min(value / 100.0, 1.0))
                }
            }
            .frame(height: 60)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Body Status Strip

    private func bodyStatusStrip(_ status: DailyStatus) -> some View {
        HStack(spacing: 12) {
            bodyStatusItem(
                "Recovery",
                value: "\(Int(status.recoveryScore))%",
                color: status.recoveryCategory == .green ? .green : (status.recoveryCategory == .yellow ? .yellow : .red),
                icon: "heart.text.square.fill"
            )
            bodyStatusItem(
                "Strain",
                value: String(format: "%.1f", status.strainScore),
                color: status.strainScore < 40 ? .blue : (status.strainScore < 70 ? .orange : .red),
                icon: "flame.fill"
            )
            bodyStatusItem(
                "Energy",
                value: "\(Int(status.energyLevel))%",
                color: status.energyLevel >= 60 ? .green : (status.energyLevel >= 30 ? .yellow : .red),
                icon: "bolt.fill"
            )
            bodyStatusItem(
                "Sleep",
                value: status.formattedSleepDuration,
                color: .indigo,
                icon: "moon.fill"
            )
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func bodyStatusItem(_ label: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func generateRecommendation() {
        guard let p = profile else { return }
        let recentPlans: [WorkoutPlan] = [] // would query from SwiftData
        _ = aiCoach.generateDailyRecommendation(profile: p, recentScores: Array(scores), recentPlans: recentPlans)
    }

    private func formatSplit(_ seconds: Double) -> String {
        let min = Int(seconds) / 60
        let sec = seconds - Double(min * 60)
        return String(format: "%d:%04.1f", min, sec)
    }

    private func iconForCategory(_ cat: AICoachService.CoachRecommendation.Category) -> String {
        switch cat {
        case .workout: return "figure.rowing"
        case .recovery: return "bed.double.fill"
        case .technique: return "hand.raised.fill"
        case .milestone: return "trophy.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private func colorForCategory(_ cat: AICoachService.CoachRecommendation.Category) -> Color {
        switch cat {
        case .workout: return .blue
        case .recovery: return .green
        case .technique: return .purple
        case .milestone: return .yellow
        case .warning: return .red
        }
    }
}
