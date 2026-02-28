import SwiftUI

/// Detailed view of a planned workout from the AI coach.
struct WorkoutDetailView: View {
    let workout: WorkoutPlan
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(workout.workoutType.replacingOccurrences(of: "_", with: " ").uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                        Spacer()
                        difficultyBadge
                    }

                    Text(workout.title)
                        .font(.title.bold())

                    Text(workout.focusArea.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Target metrics
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let split = workout.formattedTargetSplit {
                        targetMetric("Target Split", value: split + " /500m", icon: "speedometer")
                    }
                    if let sr = workout.targetStrokeRate {
                        targetMetric("Stroke Rate", value: "\(sr) s/m", icon: "metronome")
                    }
                    if let zone = workout.targetHeartRateZone {
                        targetMetric("HR Zone", value: "Zone \(zone)", icon: "heart.fill")
                    }
                    if let time = workout.targetTimeSeconds {
                        let min = Int(time) / 60
                        targetMetric("Duration", value: "\(min) min", icon: "clock")
                    }
                    if let dist = workout.targetDistanceMeters {
                        targetMetric("Distance", value: "\(dist)m", icon: "arrow.left.and.right")
                    }
                }

                // Interval breakdown
                if let intervals = workout.intervals, !intervals.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Intervals")
                            .font(.headline)

                        ForEach(intervals, id: \.self) { interval in
                            HStack {
                                Image(systemName: "repeat")
                                    .foregroundStyle(.blue)
                                Text(interval.description)
                                    .font(.subheadline.bold())
                                Spacer()
                                if let split = interval.targetSplit {
                                    let min = Int(split) / 60
                                    let sec = split - Double(min * 60)
                                    Text(String(format: "%d:%04.1f", min, sec))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                // Full description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workout Details")
                        .font(.headline)
                    Text(workout.workoutDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }

                // AI reasoning
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundStyle(.blue)
                        Text("Why This Workout")
                            .font(.headline)
                    }
                    Text(workout.aiReasoning)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .padding()
                .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))

                // Warm-up suggestion
                warmUpSection
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Components

    private func targetMetric(_ label: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var difficultyBadge: some View {
        let rating = workout.difficultyRating
        let color: Color = rating <= 3 ? .green : (rating <= 6 ? .yellow : (rating <= 8 ? .orange : .red))
        let label: String = rating <= 3 ? "Easy" : (rating <= 6 ? "Moderate" : (rating <= 8 ? "Hard" : "Max"))

        return HStack(spacing: 4) {
            ForEach(0..<5) { i in
                Circle()
                    .fill(i < (rating + 1) / 2 ? color : color.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(color)
        }
    }

    private var warmUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested Warm-Up")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                warmUpStep("1", "5 min easy rowing at 16-18 s/m")
                warmUpStep("2", "2 min light stretching (hamstrings, hip flexors)")
                warmUpStep("3", "4 x 30s builds (25%, 50%, 75%, 90% effort)")
                warmUpStep("4", "1 min easy rowing, then begin workout")
            }
        }
        .padding()
        .background(.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private func warmUpStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(.green.opacity(0.2), in: Circle())
                .foregroundStyle(.green)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
