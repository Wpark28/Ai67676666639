import SwiftUI
import SwiftData

/// Onboarding and profile editing view.
struct ProfileSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [AthleteProfile]

    @State private var name = ""
    @State private var age = "25"
    @State private var weight = "80"
    @State private var height = "180"
    @State private var gender = "male"
    @State private var experience = "intermediate"
    @State private var primaryGoal = "2k_pr"
    @State private var sessionsPerWeek = "5"
    @State private var weeklyMeters = "50000"
    @State private var restingHR = ""
    @State private var maxHR = ""

    @State private var currentStep = 0

    private let genders = ["male", "female", "other"]
    private let experiences = ["beginner", "intermediate", "advanced", "elite"]
    private let goals = [
        ("2k_pr", "2K PR", "Get the fastest 2k time possible"),
        ("fitness", "General Fitness", "Improve overall cardiovascular fitness"),
        ("weight_loss", "Weight Loss", "Use rowing for weight management"),
        ("marathon", "Endurance", "Long distance and marathon rowing"),
        ("competitive", "Competitive Racing", "Train for competitive racing")
    ]

    private var isEditing: Bool { profiles.first != nil }

    var body: some View {
        NavigationStack {
            TabView(selection: $currentStep) {
                // Step 1: Personal Info
                personalInfoStep.tag(0)

                // Step 2: Experience & Goals
                experienceStep.tag(1)

                // Step 3: Training Preferences
                trainingPrefsStep.tag(2)

                // Step 4: Heart Rate (Optional)
                heartRateStep.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .navigationTitle(isEditing ? "Edit Profile" : "Welcome to ErgAI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if currentStep == 3 {
                        Button("Save") { saveProfile() }
                            .bold()
                    }
                }
            }
            .onAppear { loadExistingProfile() }
        }
    }

    // MARK: - Step 1: Personal Info

    private var personalInfoStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                stepHeader(
                    icon: "person.fill",
                    title: "About You",
                    subtitle: "Let's get to know you so the AI coach can personalize your training."
                )

                VStack(spacing: 16) {
                    formField("Name", text: $name, placeholder: "Your name")

                    HStack(spacing: 16) {
                        formField("Age", text: $age, placeholder: "25", keyboard: .numberPad)
                        Picker("Gender", selection: $gender) {
                            ForEach(genders, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack(spacing: 16) {
                        formField("Weight (kg)", text: $weight, placeholder: "80", keyboard: .decimalPad)
                        formField("Height (cm)", text: $height, placeholder: "180", keyboard: .numberPad)
                    }
                }

                nextButton
            }
            .padding()
        }
    }

    // MARK: - Step 2: Experience

    private var experienceStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                stepHeader(
                    icon: "figure.rowing",
                    title: "Rowing Experience",
                    subtitle: "This helps me calibrate workout difficulty and training recommendations."
                )

                VStack(spacing: 12) {
                    ForEach(experiences, id: \.self) { level in
                        experienceOption(level)
                    }
                }

                Divider()

                Text("Primary Goal")
                    .font(.headline)

                VStack(spacing: 12) {
                    ForEach(goals, id: \.0) { goal in
                        goalOption(goal.0, title: goal.1, desc: goal.2)
                    }
                }

                nextButton
            }
            .padding()
        }
    }

    // MARK: - Step 3: Training Prefs

    private var trainingPrefsStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                stepHeader(
                    icon: "calendar",
                    title: "Training Schedule",
                    subtitle: "How much can you train each week?"
                )

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sessions per week")
                            .font(.subheadline.bold())
                        Picker("Sessions", selection: $sessionsPerWeek) {
                            ForEach(["3", "4", "5", "6", "7"], id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly meter goal")
                            .font(.subheadline.bold())
                        formField("Meters", text: $weeklyMeters, placeholder: "50000", keyboard: .numberPad)
                        Text("Typical range: 30,000-100,000m per week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                nextButton
            }
            .padding()
        }
    }

    // MARK: - Step 4: Heart Rate

    private var heartRateStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                stepHeader(
                    icon: "heart.fill",
                    title: "Heart Rate Data",
                    subtitle: "Optional but recommended for accurate training zones. You can update this later."
                )

                VStack(spacing: 16) {
                    formField("Resting Heart Rate (bpm)", text: $restingHR, placeholder: "60", keyboard: .numberPad)
                    formField("Max Heart Rate (bpm)", text: $maxHR, placeholder: "Auto-calculated from age", keyboard: .numberPad)

                    if maxHR.isEmpty {
                        let estimatedMax = 220 - (Int(age) ?? 25)
                        Text("Estimated max HR: \(estimatedMax) bpm (220 - age)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 8) {
                    Text("Pro tip")
                        .font(.caption.bold())
                    Text("Connect your Polar H10 during a max-effort 2k test to get your true max HR. This makes all training zones more accurate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    saveProfile()
                } label: {
                    Text(isEditing ? "Save Changes" : "Start Training")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }
            .padding()
        }
    }

    // MARK: - Components

    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.blue)
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private func formField(_ label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func experienceOption(_ level: String) -> some View {
        let descriptions: [String: String] = [
            "beginner": "New to rowing or less than 6 months experience",
            "intermediate": "1-3 years, familiar with erg training",
            "advanced": "3+ years, structured training background",
            "elite": "Competitive rower, sub-6:30 2k (M) or sub-7:15 (F)"
        ]

        return Button {
            experience = level
        } label: {
            HStack {
                Image(systemName: experience == level ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(experience == level ? .blue : .secondary)
                VStack(alignment: .leading) {
                    Text(level.capitalized)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(descriptions[level] ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(experience == level ? .blue.opacity(0.1) : .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func goalOption(_ id: String, title: String, desc: String) -> some View {
        Button {
            primaryGoal = id
        } label: {
            HStack {
                Image(systemName: primaryGoal == id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(primaryGoal == id ? .blue : .secondary)
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(primaryGoal == id ? .blue.opacity(0.1) : .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var nextButton: some View {
        Button {
            withAnimation { currentStep += 1 }
        } label: {
            Text("Next")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Actions

    private func loadExistingProfile() {
        guard let p = profiles.first else { return }
        name = p.name
        age = String(p.age)
        weight = String(p.weightKg)
        height = String(p.heightCm)
        gender = p.gender
        experience = p.rowingExperience
        primaryGoal = p.primaryGoal
        sessionsPerWeek = String(p.weeklySessionsGoal)
        weeklyMeters = String(p.weeklyMetersGoal)
        if let rhr = p.restingHeartRate { restingHR = String(rhr) }
        if let mhr = p.maxHeartRate { maxHR = String(mhr) }
    }

    private func saveProfile() {
        let profile = profiles.first ?? AthleteProfile()

        profile.name = name
        profile.age = Int(age) ?? 25
        profile.weightKg = Double(weight) ?? 80
        profile.heightCm = Double(height) ?? 180
        profile.gender = gender
        profile.rowingExperience = experience
        profile.primaryGoal = primaryGoal
        profile.weeklySessionsGoal = Int(sessionsPerWeek) ?? 5
        profile.weeklyMetersGoal = Int(weeklyMeters) ?? 50000

        if let rhr = Int(restingHR) { profile.restingHeartRate = rhr }
        if let mhr = Int(maxHR) { profile.maxHeartRate = mhr }

        if profiles.isEmpty {
            modelContext.insert(profile)
        }

        dismiss()
    }
}
