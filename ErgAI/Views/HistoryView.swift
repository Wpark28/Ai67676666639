import SwiftUI
import SwiftData

/// View showing all past erg scores with filtering and sorting.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ErgScore.date, order: .reverse) private var scores: [ErgScore]

    @State private var filterType: String = "all"
    @State private var searchText = ""
    @State private var selectedScore: ErgScore?
    @State private var showingDeleteConfirm = false
    @State private var scoreToDelete: ErgScore?

    private let workoutTypes = ["all", "2k", "5k", "6k", "10k", "500m", "30min", "60min", "interval", "steady_state"]

    private var filteredScores: [ErgScore] {
        scores.filter { score in
            if filterType != "all" && score.workoutType != filterType {
                return false
            }
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                return score.workoutType.lowercased().contains(searchLower) ||
                       score.formattedSplit.contains(searchText) ||
                       (score.notes?.lowercased().contains(searchLower) ?? false)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(workoutTypes, id: \.self) { type in
                        filterChip(type)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if filteredScores.isEmpty {
                emptyState
            } else {
                List {
                    // Group by month
                    ForEach(groupedByMonth, id: \.0) { month, monthScores in
                        Section(month) {
                            ForEach(monthScores, id: \.id) { score in
                                scoreCard(score)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            scoreToDelete = score
                                            showingDeleteConfirm = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("History")
        .searchable(text: $searchText, prompt: "Search scores")
        .confirmationDialog("Delete this score?", isPresented: $showingDeleteConfirm, presenting: scoreToDelete) { score in
            Button("Delete", role: .destructive) {
                modelContext.delete(score)
            }
        } message: { score in
            Text("Delete \(score.workoutType.uppercased()) score from \(score.date.formatted(date: .abbreviated, time: .omitted))?")
        }
        .sheet(item: $selectedScore) { score in
            ScoreDetailView(score: score)
        }
    }

    // MARK: - Components

    private func filterChip(_ type: String) -> some View {
        Button {
            withAnimation { filterType = type }
        } label: {
            Text(type == "all" ? "All" : type.uppercased())
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(filterType == type ? .blue : .blue.opacity(0.1), in: Capsule())
                .foregroundStyle(filterType == type ? .white : .blue)
        }
    }

    private func scoreCard(_ score: ErgScore) -> some View {
        Button {
            selectedScore = score
        } label: {
            HStack(spacing: 12) {
                // Workout type badge
                VStack {
                    Text(score.workoutType.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
                .frame(width: 50, height: 36)
                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 8))

                // Score details
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(score.formattedSplit)
                            .font(.headline)
                        Text("/500m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Text(score.formattedDistance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(score.formattedTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if score.strokeRate > 0 {
                            Text("\(score.strokeRate) s/m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(score.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        if score.capturedFromPhoto {
                            Image(systemName: "camera.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if score.averageHeartRate != nil {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No scores yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Capture your first erg score to start tracking")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: - Grouping

    private var groupedByMonth: [(String, [ErgScore])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var groups: [(String, [ErgScore])] = []
        var currentMonth = ""
        var currentGroup: [ErgScore] = []

        for score in filteredScores {
            let month = formatter.string(from: score.date)
            if month != currentMonth {
                if !currentGroup.isEmpty {
                    groups.append((currentMonth, currentGroup))
                }
                currentMonth = month
                currentGroup = [score]
            } else {
                currentGroup.append(score)
            }
        }

        if !currentGroup.isEmpty {
            groups.append((currentMonth, currentGroup))
        }

        return groups
    }
}

// MARK: - Score Detail

struct ScoreDetailView: View {
    let score: ErgScore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Main metrics
                    VStack(spacing: 4) {
                        Text(score.workoutType.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                        Text(score.formattedSplit)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                        Text("/500m")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        metricCard("Distance", value: score.formattedDistance, icon: "arrow.left.and.right")
                        metricCard("Time", value: score.formattedTime, icon: "clock")
                        metricCard("Stroke Rate", value: "\(score.strokeRate) s/m", icon: "metronome")
                        metricCard("Watts", value: String(format: "%.0f W", score.averageWatts), icon: "bolt.fill")

                        if let hr = score.averageHeartRate {
                            metricCard("Avg HR", value: "\(hr) bpm", icon: "heart.fill")
                        }
                        if let maxHR = score.maxHeartRate {
                            metricCard("Max HR", value: "\(maxHR) bpm", icon: "heart.fill")
                        }
                        if score.calories > 0 {
                            metricCard("Calories", value: "\(score.calories) Cal", icon: "flame.fill")
                        }
                        if let df = score.averageDragFactor {
                            metricCard("Drag Factor", value: "\(df)", icon: "wind")
                        }
                    }

                    // Photo
                    if let photoData = score.photoData, let image = UIImage(data: photoData) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Captured Image")
                                .font(.subheadline.bold())
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // OCR data
                    if let rawText = score.rawOCRText {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("OCR Data")
                                    .font(.subheadline.bold())
                                Spacer()
                                if let conf = score.ocrConfidence {
                                    Text("\(Int(conf * 100))% confidence")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(rawText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Notes
                    if let notes = score.notes {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.subheadline.bold())
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Date
                    VStack(spacing: 4) {
                        Text(score.date.formatted(date: .complete, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if score.capturedFromPhoto {
                            Label("Captured via photo", systemImage: "camera.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Score Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func metricCard(_ label: String, value: String, icon: String) -> some View {
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
}
