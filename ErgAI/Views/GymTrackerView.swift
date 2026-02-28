import SwiftUI
import SwiftData

/// Gym lift tracking view - log exercises, sets, reps, and weight.
struct GymTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GymSession.date, order: .reverse) private var sessions: [GymSession]
    @Query private var profiles: [AthleteProfile]

    @State private var showingNewSession = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    Text("Log").tag(0)
                    Text("History").tag(1)
                    Text("PRs").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case 0: activeSessionTab
                case 1: historyTab
                case 2: prsTab
                default: activeSessionTab
                }
            }
            .navigationTitle("Gym")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewSession = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingNewSession) {
                NewGymSessionView()
            }
        }
    }

    // MARK: - Active Session

    private var activeSessionTab: some View {
        ScrollView {
            if sessions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 16) {
                    // Today's session if exists
                    let today = Calendar.current.startOfDay(for: Date())
                    if let todaySession = sessions.first(where: { Calendar.current.startOfDay(for: $0.date) == today }) {
                        todaySessionCard(todaySession)
                    } else {
                        startSessionCard
                    }

                    // Quick stats
                    weeklyGymStats
                }
                .padding()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("Start Tracking Lifts")
                .font(.title2.bold())
            Text("Log your gym sessions to track progress, PRs, and volume over time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingNewSession = true
            } label: {
                Label("New Session", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 40)
            Spacer()
        }
        .padding()
    }

    private var startSessionCard: some View {
        Button { showingNewSession = true } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text("Start Gym Session")
                        .font(.headline)
                    Text("No session logged today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func todaySessionCard(_ session: GymSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.sessionName)
                    .font(.headline)
                Spacer()
                Text(session.sessionType.uppercased())
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.15), in: Capsule())
                    .foregroundStyle(.blue)
            }

            // Stats
            HStack(spacing: 20) {
                sessionStat("Volume", value: session.formattedVolume, icon: "scalemass.fill")
                sessionStat("Sets", value: "\(session.totalSets)", icon: "number")
                sessionStat("Exercises", value: "\(session.exercises.count)", icon: "figure.strengthtraining.traditional")
                sessionStat("Duration", value: "\(session.durationMinutes)m", icon: "clock")
            }

            Divider()

            // Exercise list
            ForEach(session.exercises, id: \.id) { exercise in
                HStack {
                    Text(exercise.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(exercise.workingSets.count) sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if exercise.topSetWeight > 0 {
                        Text("\(String(format: "%.1f", exercise.topSetWeight))kg x\(exercise.topSetReps)")
                            .font(.caption.bold())
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func sessionStat(_ label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var weeklyGymStats: some View {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let weekSessions = sessions.filter { $0.date >= weekAgo }
        let totalVolume = weekSessions.reduce(0.0) { $0 + $1.totalVolume }
        let totalSets = weekSessions.reduce(0) { $0 + $1.totalSets }

        return VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(.subheadline.bold())
            HStack(spacing: 16) {
                weekStat("Sessions", value: "\(weekSessions.count)")
                weekStat("Total Volume", value: totalVolume >= 1000 ? String(format: "%.1fk", totalVolume/1000) : String(format: "%.0f", totalVolume))
                weekStat("Total Sets", value: "\(totalSets)")
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func weekStat(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - History

    private var historyTab: some View {
        List {
            ForEach(sessions, id: \.id) { session in
                NavigationLink {
                    GymSessionDetailView(session: session)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.sessionName)
                                .font(.subheadline.bold())
                            Text("\(session.exercises.count) exercises · \(session.totalSets) sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(session.formattedVolume)
                                .font(.subheadline)
                            Text(session.date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - PRs

    private var prsTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                let allExercises = sessions.flatMap(\.exercises)
                let exerciseNames = Array(Set(allExercises.map(\.name))).sorted()

                if exerciseNames.isEmpty {
                    Text("Log gym sessions to track PRs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                } else {
                    ForEach(exerciseNames, id: \.self) { name in
                        let exercises = allExercises.filter { $0.name == name }
                        let bestE1RM = exercises.map(\.estimated1RM).max() ?? 0
                        let bestWeight = exercises.map(\.topSetWeight).max() ?? 0

                        if bestWeight > 0 {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name)
                                        .font(.subheadline.bold())
                                    Text(exercises.first?.muscleGroup.capitalized ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.1f kg", bestWeight))
                                        .font(.subheadline.bold())
                                    if bestE1RM > 0 {
                                        Text("e1RM: \(String(format: "%.0f", bestE1RM))")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - New Gym Session View

struct NewGymSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var sessionName = ""
    @State private var sessionType = "push"
    @State private var exercises: [GymExercise] = []
    @State private var showingAddExercise = false
    @State private var startTime = Date()

    private let sessionTypes = ["push", "pull", "legs", "upper", "lower", "full_body", "custom"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Session info
                    VStack(spacing: 12) {
                        TextField("Session Name", text: $sessionName)
                            .font(.title3.bold())
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                        Picker("Type", selection: $sessionType) {
                            ForEach(sessionTypes, id: \.self) { Text($0.capitalized.replacingOccurrences(of: "_", with: " ")).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        // Auto-fill name based on type
                        .onChange(of: sessionType) { _, newType in
                            if sessionName.isEmpty {
                                sessionName = newType.capitalized.replacingOccurrences(of: "_", with: " ") + " Day"
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Exercises
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        ExerciseCard(exercise: exercise, onDelete: {
                            exercises.remove(at: index)
                        })
                    }

                    // Add exercise button
                    Button { showingAddExercise = true } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveSession() }
                        .bold()
                        .disabled(exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                ExercisePickerView { name, muscle, category in
                    let exercise = GymExercise(name: name, muscleGroup: muscle, category: category)
                    exercise.orderIndex = exercises.count
                    exercises.append(exercise)
                }
            }
        }
    }

    private func saveSession() {
        let session = GymSession(sessionName: sessionName.isEmpty ? "Gym Session" : sessionName, sessionType: sessionType)
        session.startTime = startTime
        session.endTime = Date()
        session.exercises = exercises
        session.recalculate()

        for exercise in exercises {
            modelContext.insert(exercise)
        }
        modelContext.insert(session)
        dismiss()
    }
}

// MARK: - Exercise Card

struct ExerciseCard: View {
    @Bindable var exercise: GymExercise
    var onDelete: () -> Void

    @State private var newReps = ""
    @State private var newWeight = ""
    @State private var isWarmup = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(exercise.name)
                        .font(.subheadline.bold())
                    Text(exercise.muscleGroup.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
            }

            // Sets list
            if !exercise.sets.isEmpty {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                    HStack {
                        Text(set.isWarmup ? "W" : "\(index + 1 - exercise.sets.prefix(index).filter(\.isWarmup).count)")
                            .font(.caption.bold())
                            .frame(width: 24)
                            .foregroundStyle(set.isWarmup ? .orange : .blue)
                        Text("\(String(format: "%.1f", set.weightKg)) kg")
                            .font(.caption)
                        Text("x \(set.reps)")
                            .font(.caption.bold())
                        Spacer()
                        if set.isFailure {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        Button {
                            exercise.sets.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Add set
            HStack(spacing: 8) {
                TextField("kg", text: $newWeight)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .padding(6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))

                Text("x")
                    .font(.caption)

                TextField("reps", text: $newReps)
                    .keyboardType(.numberPad)
                    .frame(width: 50)
                    .padding(6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))

                Toggle("W", isOn: $isWarmup)
                    .font(.caption2)
                    .toggleStyle(.button)
                    .tint(.orange)

                Spacer()

                Button {
                    addSet()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .disabled(newReps.isEmpty || newWeight.isEmpty)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func addSet() {
        guard let reps = Int(newReps), let weight = Double(newWeight) else { return }
        let set = LiftSet(reps: reps, weightKg: weight, isWarmup: isWarmup)
        exercise.sets.append(set)

        // Keep weight, clear reps for next set
        newReps = ""
        isWarmup = false
    }
}

// MARK: - Exercise Picker

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String, String, String) -> Void

    @State private var searchText = ""
    @State private var selectedMuscle = "all"
    @State private var customName = ""

    private let muscleGroups = ["all", "chest", "back", "legs", "shoulders", "arms", "core"]

    var filteredExercises: [(name: String, muscle: String, category: String)] {
        var results = ExerciseLibrary.exercises
        if selectedMuscle != "all" {
            results = results.filter { $0.muscle == selectedMuscle }
        }
        if !searchText.isEmpty {
            results = results.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        return results
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Muscle group filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(muscleGroups, id: \.self) { muscle in
                            Button {
                                selectedMuscle = muscle
                            } label: {
                                Text(muscle.capitalized)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedMuscle == muscle ? .blue : .blue.opacity(0.1), in: Capsule())
                                    .foregroundStyle(selectedMuscle == muscle ? .white : .blue)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                List {
                    // Custom exercise
                    Section("Custom Exercise") {
                        HStack {
                            TextField("Exercise name", text: $customName)
                            Button("Add") {
                                if !customName.isEmpty {
                                    onSelect(customName, selectedMuscle == "all" ? "full_body" : selectedMuscle, "barbell")
                                    dismiss()
                                }
                            }
                            .disabled(customName.isEmpty)
                        }
                    }

                    // Library exercises
                    Section("Exercise Library") {
                        ForEach(filteredExercises, id: \.name) { ex in
                            Button {
                                onSelect(ex.name, ex.muscle, ex.category)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(ex.name).font(.subheadline)
                                        Text(ex.category.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(ex.muscle.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Session Detail

struct GymSessionDetailView: View {
    let session: GymSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.sessionName)
                        .font(.title2.bold())
                    Text(session.date.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statBox("Volume", value: session.formattedVolume, color: .blue)
                    statBox("Sets", value: "\(session.totalSets)", color: .green)
                    statBox("Duration", value: "\(session.durationMinutes)m", color: .orange)
                }

                // Exercises
                ForEach(session.exercises, id: \.id) { exercise in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(exercise.name)
                                .font(.subheadline.bold())
                            Spacer()
                            if exercise.estimated1RM > 0 {
                                Text("e1RM: \(String(format: "%.0f", exercise.estimated1RM))")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }

                        ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                            HStack {
                                Text(set.isWarmup ? "Warmup" : "Set \(index + 1)")
                                    .font(.caption)
                                    .frame(width: 60, alignment: .leading)
                                    .foregroundStyle(set.isWarmup ? .orange : .primary)
                                Text("\(String(format: "%.1f", set.weightKg)) kg x \(set.reps)")
                                    .font(.caption.bold())
                                Spacer()
                                Text("\(String(format: "%.0f", set.volume)) vol")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statBox(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
