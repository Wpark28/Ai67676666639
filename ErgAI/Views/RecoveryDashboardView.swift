import SwiftUI
import SwiftData

/// Dashboard showing recovery score, sleep, strain, and daily energy — powered by Apple Watch Ultra data.
struct RecoveryDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyStatus.date, order: .reverse) private var statuses: [DailyStatus]
    @Query private var profiles: [AthleteProfile]

    @StateObject private var recoveryEngine = RecoveryEngine()
    @State private var selectedTab = 0

    private var todayStatus: DailyStatus? { statuses.first }
    private var profile: AthleteProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Tab selector
                    Picker("View", selection: $selectedTab) {
                        Text("Recovery").tag(0)
                        Text("Sleep").tag(1)
                        Text("Strain").tag(2)
                        Text("Energy").tag(3)
                    }
                    .pickerStyle(.segmented)

                    switch selectedTab {
                    case 0: recoveryTab
                    case 1: sleepTab
                    case 2: strainTab
                    case 3: energyTab
                    default: recoveryTab
                    }
                }
                .padding()
            }
            .navigationTitle("Body Status")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                if todayStatus == nil {
                    Task { await refreshData() }
                }
            }
        }
    }

    // MARK: - Recovery Tab

    private var recoveryTab: some View {
        VStack(spacing: 20) {
            // Big recovery ring
            recoveryRing

            // Recovery recommendation
            if let status = todayStatus {
                recoveryRecommendation(status)
            }

            // Apple Watch biometrics
            biometricsGrid

            // Recovery history
            recoveryHistory
        }
    }

    private var recoveryRing: some View {
        let score = todayStatus?.recoveryScore ?? 0
        let category = todayStatus?.recoveryCategory ?? .yellow

        return ZStack {
            Circle()
                .stroke(recoveryColor(category).opacity(0.15), lineWidth: 20)
                .frame(width: 200, height: 200)
            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(recoveryColor(category), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: score)

            VStack(spacing: 4) {
                Text("\(Int(score))")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(recoveryColor(category))
                Text("Recovery")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(category.label)
                    .font(.caption.bold())
                    .foregroundStyle(recoveryColor(category))
            }
        }
        .padding(.vertical, 8)
    }

    private func recoveryRecommendation(_ status: DailyStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: recoveryIcon(status.recoveryCategory))
                .font(.title2)
                .foregroundStyle(recoveryColor(status.recoveryCategory))
            Text(status.recoveryCategory.recommendation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(recoveryColor(status.recoveryCategory).opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Biometrics (Apple Watch Ultra Data)

    private var biometricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "applewatch")
                    .foregroundStyle(.blue)
                Text("Apple Watch Ultra Data")
                    .font(.subheadline.bold())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                biometricCard(
                    "HRV",
                    value: todayStatus?.heartRateVariability.map { String(format: "%.0f ms", $0) } ?? "--",
                    icon: "waveform.path.ecg",
                    detail: "Heart Rate Variability",
                    color: .purple
                )
                biometricCard(
                    "Resting HR",
                    value: todayStatus?.restingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "--",
                    icon: "heart.fill",
                    detail: "Lower is better",
                    color: .red
                )
                biometricCard(
                    "Blood Oxygen",
                    value: todayStatus?.bloodOxygen.map { String(format: "%.1f%%", $0) } ?? "--",
                    icon: "lungs.fill",
                    detail: "SpO2",
                    color: .cyan
                )
                biometricCard(
                    "Respiratory",
                    value: todayStatus?.respiratoryRate.map { String(format: "%.1f br/m", $0) } ?? "--",
                    icon: "wind",
                    detail: "Breaths per minute",
                    color: .green
                )
                biometricCard(
                    "Wrist Temp",
                    value: todayStatus?.wristTemperature.map { String(format: "%+.1f°C", $0) } ?? "--",
                    icon: "thermometer.medium",
                    detail: "Deviation from baseline",
                    color: .orange
                )
                biometricCard(
                    "Steps",
                    value: "\(todayStatus?.stepsCount ?? 0)",
                    icon: "figure.walk",
                    detail: "Today",
                    color: .blue
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func biometricCard(_ title: String, value: String, icon: String, detail: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2.bold())
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Sleep Tab

    private var sleepTab: some View {
        VStack(spacing: 20) {
            // Sleep score ring
            let sleepScore = todayStatus?.sleepScore ?? 0

            ZStack {
                Circle()
                    .stroke(Color.indigo.opacity(0.15), lineWidth: 16)
                    .frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: sleepScore / 100)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(Int(sleepScore))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.indigo)
                    Text("Sleep Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Sleep duration
            VStack(spacing: 8) {
                Text(todayStatus?.formattedSleepDuration ?? "0h 0m")
                    .font(.title.bold())
                Text("Total Sleep")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let start = todayStatus?.sleepStartTime, let end = todayStatus?.sleepEndTime {
                    Text("\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Sleep stages
            VStack(alignment: .leading, spacing: 12) {
                Text("Sleep Stages")
                    .font(.subheadline.bold())

                sleepStageBar("Deep", minutes: todayStatus?.deepSleepMinutes ?? 0, color: .indigo, ideal: "1-2h")
                sleepStageBar("REM", minutes: todayStatus?.remSleepMinutes ?? 0, color: .purple, ideal: "1.5-2h")
                sleepStageBar("Light", minutes: todayStatus?.lightSleepMinutes ?? 0, color: .blue.opacity(0.5), ideal: "3-4h")
                sleepStageBar("Awake", minutes: todayStatus?.awakeMinutes ?? 0, color: .orange, ideal: "<30m")
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Sleep tips
            sleepTip
        }
    }

    private func sleepStageBar(_ label: String, minutes: Int, color: Color, ideal: String) -> some View {
        let totalSleep = max(todayStatus?.totalSleepMinutes ?? 1, 1)
        let fraction = Double(minutes) / Double(totalSleep)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption.bold())
                Spacer()
                Text("\(minutes / 60)h \(minutes % 60)m")
                    .font(.caption)
                Text("(ideal: \(ideal))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 12)
        }
    }

    private var sleepTip: some View {
        let hours = Double(todayStatus?.totalSleepMinutes ?? 0) / 60.0
        let tip: String
        if hours < 6 {
            tip = "You got less than 6 hours of sleep. This significantly impacts recovery, HRV, and performance. Aim for 7-9 hours."
        } else if hours < 7 {
            tip = "Close to the minimum, but athletes perform best with 7-9 hours. Consider earlier bedtime."
        } else if hours <= 9 {
            tip = "Great sleep duration! Check your deep and REM percentages for quality metrics."
        } else {
            tip = "Over 9 hours can indicate high fatigue or recovery needs. Monitor how you feel."
        }

        return HStack(spacing: 8) {
            Image(systemName: "moon.fill")
                .foregroundStyle(.indigo)
            Text(tip)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.indigo.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Strain Tab

    private var strainTab: some View {
        VStack(spacing: 20) {
            // Strain gauge
            let strain = todayStatus?.strainScore ?? 0

            ZStack {
                // Semicircle gauge
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(Color.orange.opacity(0.15), lineWidth: 20)
                    .frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0.25, to: 0.25 + (strain / 21.0) * 0.5)
                    .stroke(strainColor(strain), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .animation(.easeInOut(duration: 0.8), value: strain)

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", strain))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(strainColor(strain))
                    Text("/ 21.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(todayStatus?.strainCategory ?? "Light")
                        .font(.caption.bold())
                        .foregroundStyle(strainColor(strain))
                }
            }

            // Strain breakdown
            if let breakdown = todayStatus?.strainBreakdown, !breakdown.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Strain Sources")
                        .font(.subheadline.bold())

                    ForEach(breakdown.sorted(by: { $0.value > $1.value }), id: \.key) { source, value in
                        HStack {
                            Text(source.capitalized)
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1f", value))
                                .font(.subheadline.bold())
                                .foregroundStyle(strainColor(value))
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            // Activity stats
            HStack(spacing: 12) {
                activityStat("Active Cal", value: "\(todayStatus?.activeCaloriesBurned ?? 0)", icon: "flame.fill", color: .red)
                activityStat("Active Min", value: "\(todayStatus?.activeMinutes ?? 0)", icon: "figure.run", color: .green)
                activityStat("Steps", value: "\(todayStatus?.stepsCount ?? 0)", icon: "shoeprints.fill", color: .blue)
            }

            // Strain vs Recovery
            strainRecoveryBalance
        }
    }

    private func activityStat(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var strainRecoveryBalance: some View {
        let recovery = todayStatus?.recoveryScore ?? 50
        let strain = todayStatus?.strainScore ?? 0
        let optimalStrain: ClosedRange<Double>

        if recovery >= 67 { optimalStrain = 10...18 }
        else if recovery >= 34 { optimalStrain = 5...12 }
        else { optimalStrain = 0...6 }

        let isOptimal = optimalStrain.contains(strain)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Strain vs Recovery Balance")
                .font(.subheadline.bold())
            HStack {
                Image(systemName: isOptimal ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isOptimal ? .green : .orange)
                Text(isOptimal
                     ? "Your strain is well-matched to your recovery level."
                     : strain > optimalStrain.upperBound
                     ? "Strain is high relative to recovery. Consider easing off."
                     : "You have more capacity today. Room for a harder session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Optimal strain range for today: \(String(format: "%.0f", optimalStrain.lowerBound))-\(String(format: "%.0f", optimalStrain.upperBound))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Energy Tab

    private var energyTab: some View {
        VStack(spacing: 20) {
            // Energy battery
            let energy = todayStatus?.energyLevel ?? 100
            let baseline = todayStatus?.energyBaseline ?? 100

            VStack(spacing: 12) {
                // Battery visualization
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(energyColor(energy).opacity(0.3), lineWidth: 3)
                        .frame(width: 120, height: 200)

                    VStack(spacing: 0) {
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(energyColor(energy).gradient)
                            .frame(width: 110, height: max(190 * energy / 100, 5))
                            .animation(.easeInOut(duration: 0.8), value: energy)
                    }
                    .frame(width: 120, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(spacing: 4) {
                        Text("\(Int(energy))%")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                        Text(todayStatus?.energyCategory ?? "High")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                }

                Text("Started at \(Int(baseline))% based on recovery")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Energy drains timeline
            if let drains = todayStatus?.energyDrains, !drains.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Energy Drains")
                        .font(.subheadline.bold())

                    ForEach(drains) { drain in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(drain.source)
                                    .font(.subheadline)
                                Text("\(drain.durationMinutes) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("-\(Int(drain.amount))%")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red)
                            Text(drain.time.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            // Energy tips
            energyTip(energy: energy)
        }
    }

    private func energyTip(energy: Double) -> some View {
        let tip: String
        let icon: String
        if energy >= 70 {
            tip = "Energy is high. Great time for a hard workout or test piece. You have the battery for it."
            icon = "bolt.fill"
        } else if energy >= 40 {
            tip = "Moderate energy. Steady state or moderate gym session would be appropriate. Save high intensity for higher energy days."
            icon = "gauge.medium"
        } else if energy >= 20 {
            tip = "Energy is getting low. Light activity only — easy row, walk, or mobility work."
            icon = "gauge.low"
        } else {
            tip = "Energy depleted. Rest is the priority. Your body needs to recharge for tomorrow."
            icon = "battery.0"
        }

        return HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(energyColor(energy))
            Text(tip)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(energyColor(energy).opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recovery History

    private var recoveryHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Recovery")
                .font(.subheadline.bold())

            let last7 = Array(statuses.prefix(7)).reversed()
            if last7.count > 1 {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(last7.enumerated()), id: \.offset) { _, status in
                        VStack(spacing: 4) {
                            Text("\(Int(status.recoveryScore))")
                                .font(.caption2)
                                .foregroundStyle(recoveryColor(status.recoveryCategory))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(recoveryColor(status.recoveryCategory))
                                .frame(height: max(status.recoveryScore * 0.6, 5))
                            Text(status.date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 90)
            } else {
                Text("More data needed for trends")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func refreshData() async {
        let yesterdayStrain = statuses.count > 1 ? statuses[1].strainScore : 0
        let status = await recoveryEngine.buildDailyStatus(previousDayStrain: yesterdayStrain)
        modelContext.insert(status)
    }

    private func recoveryColor(_ category: RecoveryCategory) -> Color {
        switch category {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }

    private func recoveryIcon(_ category: RecoveryCategory) -> String {
        switch category {
        case .green: return "checkmark.circle.fill"
        case .yellow: return "exclamationmark.circle.fill"
        case .red: return "xmark.circle.fill"
        }
    }

    private func strainColor(_ strain: Double) -> Color {
        if strain < 5 { return .blue }
        if strain < 10 { return .green }
        if strain < 15 { return .orange }
        return .red
    }

    private func energyColor(_ energy: Double) -> Color {
        if energy >= 70 { return .green }
        if energy >= 40 { return .yellow }
        if energy >= 20 { return .orange }
        return .red
    }
}
