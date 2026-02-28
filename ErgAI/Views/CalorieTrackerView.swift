import SwiftUI
import SwiftData

/// Calorie and macro tracking view.
struct CalorieTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CalorieEntry.date, order: .reverse) private var entries: [CalorieEntry]
    @Query private var dailyNutrition: [DailyNutrition]

    @State private var showingAddFood = false
    @State private var showingQuickAdd = false

    private var todayEntries: [CalorieEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return entries.filter { Calendar.current.startOfDay(for: $0.date) == today }
    }

    private var todayNutrition: DailyNutrition? {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyNutrition.first { Calendar.current.startOfDay(for: $0.date) == today }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Calorie ring
                    calorieRing

                    // Macro bars
                    macroBars

                    // Quick actions
                    HStack(spacing: 12) {
                        Button { showingAddFood = true } label: {
                            Label("Add Food", systemImage: "plus.circle.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }
                        Button { showingQuickAdd = true } label: {
                            Label("Quick Add", systemImage: "bolt.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.orange)
                        }
                    }

                    // Water tracking
                    waterTracker

                    // Today's meals
                    todayMeals

                    // Meal breakdown
                    mealBreakdown
                }
                .padding()
            }
            .navigationTitle("Nutrition")
            .sheet(isPresented: $showingAddFood) {
                AddFoodView()
            }
            .sheet(isPresented: $showingQuickAdd) {
                QuickCalorieAddView()
            }
            .onAppear { ensureDailyNutrition() }
        }
    }

    // MARK: - Calorie Ring

    private var calorieRing: some View {
        let consumed = todayEntries.reduce(0) { $0 + $1.calories }
        let target = todayNutrition?.targetCalories ?? 2500
        let remaining = max(target - consumed, 0)
        let progress = min(Double(consumed) / Double(target), 1.5)

        return ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.15), lineWidth: 16)
                .frame(width: 180, height: 180)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(progress > 1.0 ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            VStack(spacing: 4) {
                Text("\(remaining)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(progress > 1.0 ? .red : .primary)
                Text("remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(consumed) / \(target)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Macro Bars

    private var macroBars: some View {
        let protein = todayEntries.reduce(0.0) { $0 + $1.proteinGrams }
        let carbs = todayEntries.reduce(0.0) { $0 + $1.carbsGrams }
        let fat = todayEntries.reduce(0.0) { $0 + $1.fatGrams }
        let targetP = todayNutrition?.targetProtein ?? 150
        let targetC = todayNutrition?.targetCarbs ?? 280
        let targetF = todayNutrition?.targetFat ?? 70

        return HStack(spacing: 12) {
            macroBar("Protein", current: protein, target: targetP, color: .blue, unit: "g")
            macroBar("Carbs", current: carbs, target: targetC, color: .green, unit: "g")
            macroBar("Fat", current: fat, target: targetF, color: .orange, unit: "g")
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func macroBar(_ label: String, current: Double, target: Double, color: Color, unit: String) -> some View {
        let progress = min(current / max(target, 1), 1.5)

        return VStack(spacing: 6) {
            Text("\(Int(current))\(unit)")
                .font(.subheadline.bold())
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: geo.size.height * min(progress, 1.0))
                }
            }
            .frame(height: 50)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(target))\(unit)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Water Tracker

    private var waterTracker: some View {
        let glasses = todayNutrition?.waterGlasses ?? 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
                Text("Water")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(glasses) glasses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { i in
                    Button {
                        addWater(glasses: i + 1)
                    } label: {
                        Image(systemName: i < glasses ? "drop.fill" : "drop")
                            .font(.title3)
                            .foregroundStyle(i < glasses ? .cyan : .cyan.opacity(0.3))
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Today's Meals

    private var todayMeals: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Log")
                .font(.headline)

            if todayEntries.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No food logged yet today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ForEach(todayEntries, id: \.id) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(.subheadline)
                            Text(entry.mealType.capitalized.replacingOccurrences(of: "_", with: " "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(entry.calories) cal")
                                .font(.subheadline.bold())
                            if entry.proteinGrams > 0 {
                                Text("\(Int(entry.proteinGrams))P · \(Int(entry.carbsGrams))C · \(Int(entry.fatGrams))F")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    Divider()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Meal Breakdown

    private var mealBreakdown: some View {
        let mealTypes = ["breakfast", "lunch", "dinner", "snack", "pre_workout", "post_workout"]
        let grouped = Dictionary(grouping: todayEntries, by: \.mealType)

        return VStack(alignment: .leading, spacing: 8) {
            Text("By Meal")
                .font(.subheadline.bold())
            ForEach(mealTypes.filter { grouped[$0] != nil }, id: \.self) { meal in
                let mealEntries = grouped[meal] ?? []
                let cals = mealEntries.reduce(0) { $0 + $1.calories }
                HStack {
                    Text(meal.capitalized.replacingOccurrences(of: "_", with: " "))
                        .font(.caption)
                    Spacer()
                    Text("\(cals) cal")
                        .font(.caption.bold())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func ensureDailyNutrition() {
        let today = Calendar.current.startOfDay(for: Date())
        if !dailyNutrition.contains(where: { Calendar.current.startOfDay(for: $0.date) == today }) {
            let daily = DailyNutrition(date: today)
            modelContext.insert(daily)
        }
    }

    private func addWater(glasses: Int) {
        if let daily = todayNutrition {
            daily.waterMl = glasses * 250
        }
    }
}

// MARK: - Add Food View

struct AddFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var dailyNutrition: [DailyNutrition]

    @State private var searchText = ""
    @State private var selectedMeal = "lunch"
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack", "pre_workout", "post_workout"]

    var body: some View {
        NavigationStack {
            List {
                // Meal type
                Section("Meal") {
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(mealTypes, id: \.self) { Text($0.capitalized.replacingOccurrences(of: "_", with: " ")).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                // Custom entry
                Section("Custom Food") {
                    TextField("Food name", text: $name)
                    HStack {
                        TextField("Calories", text: $calories).keyboardType(.numberPad)
                        TextField("Protein (g)", text: $protein).keyboardType(.decimalPad)
                    }
                    HStack {
                        TextField("Carbs (g)", text: $carbs).keyboardType(.decimalPad)
                        TextField("Fat (g)", text: $fat).keyboardType(.decimalPad)
                    }
                    Button("Add") { addCustomEntry() }
                        .disabled(name.isEmpty || calories.isEmpty)
                }

                // Quick picks from library
                Section("Common Foods") {
                    ForEach(FoodLibrary.search(searchText), id: \.name) { food in
                        Button {
                            addFromLibrary(food)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(food.name).font(.subheadline).foregroundStyle(.primary)
                                    Text(food.servingSize).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(food.calories) cal").font(.subheadline.bold())
                                    Text("\(Int(food.protein))P · \(Int(food.carbs))C · \(Int(food.fat))F")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search foods")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func addCustomEntry() {
        let entry = CalorieEntry(name: name, calories: Int(calories) ?? 0, mealType: selectedMeal)
        entry.proteinGrams = Double(protein) ?? 0
        entry.carbsGrams = Double(carbs) ?? 0
        entry.fatGrams = Double(fat) ?? 0
        modelContext.insert(entry)
        updateDaily(entry)
        dismiss()
    }

    private func addFromLibrary(_ food: FoodLibrary.Food) {
        let entry = CalorieEntry(name: food.name, calories: food.calories, mealType: selectedMeal)
        entry.proteinGrams = food.protein
        entry.carbsGrams = food.carbs
        entry.fatGrams = food.fat
        modelContext.insert(entry)
        updateDaily(entry)
        dismiss()
    }

    private func updateDaily(_ entry: CalorieEntry) {
        let today = Calendar.current.startOfDay(for: Date())
        if let daily = dailyNutrition.first(where: { Calendar.current.startOfDay(for: $0.date) == today }) {
            daily.addEntry(entry)
        }
    }
}

// MARK: - Quick Calorie Add

struct QuickCalorieAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var calories = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Quick Add Calories")
                    .font(.title2.bold())

                TextField("Calories", text: $calories)
                    .keyboardType(.numberPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()

                TextField("Note (optional)", text: $note)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                Button {
                    let entry = CalorieEntry(name: note.isEmpty ? "Quick add" : note, calories: Int(calories) ?? 0)
                    entry.isQuickAdd = true
                    modelContext.insert(entry)
                    dismiss()
                } label: {
                    Text("Add")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .disabled(calories.isEmpty)

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
