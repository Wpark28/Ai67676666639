import Foundation
import SwiftData

/// A single food/calorie entry.
@Model
final class CalorieEntry {
    var id: UUID
    var date: Date
    var mealType: String            // "breakfast", "lunch", "dinner", "snack", "pre_workout", "post_workout"
    var name: String
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double?
    var notes: String?
    var isQuickAdd: Bool            // Quick calorie add without details

    init(name: String, calories: Int, mealType: String = "snack") {
        self.id = UUID()
        self.date = Date()
        self.mealType = mealType
        self.name = name
        self.calories = calories
        self.proteinGrams = 0
        self.carbsGrams = 0
        self.fatGrams = 0
        self.isQuickAdd = false
    }

    var macroTotal: Double { proteinGrams + carbsGrams + fatGrams }

    var proteinPercent: Double {
        guard macroTotal > 0 else { return 0 }
        return (proteinGrams * 4) / Double(calories) * 100
    }

    var carbsPercent: Double {
        guard macroTotal > 0 else { return 0 }
        return (carbsGrams * 4) / Double(calories) * 100
    }

    var fatPercent: Double {
        guard macroTotal > 0 else { return 0 }
        return (fatGrams * 9) / Double(calories) * 100
    }
}

/// Daily calorie/nutrition summary.
@Model
final class DailyNutrition {
    var id: UUID
    var date: Date
    var targetCalories: Int
    var targetProtein: Double       // grams
    var targetCarbs: Double
    var targetFat: Double
    var waterMl: Int                // Water intake in ml

    // Totals (updated as entries are added)
    var totalCalories: Int
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double

    init(date: Date = Date(), targetCalories: Int = 2500) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.targetCalories = targetCalories
        self.targetProtein = Double(targetCalories) * 0.3 / 4    // 30% protein
        self.targetCarbs = Double(targetCalories) * 0.45 / 4     // 45% carbs
        self.targetFat = Double(targetCalories) * 0.25 / 9       // 25% fat
        self.waterMl = 0
        self.totalCalories = 0
        self.totalProtein = 0
        self.totalCarbs = 0
        self.totalFat = 0
    }

    var caloriesRemaining: Int { targetCalories - totalCalories }
    var proteinRemaining: Double { max(targetProtein - totalProtein, 0) }

    var calorieProgress: Double {
        guard targetCalories > 0 else { return 0 }
        return min(Double(totalCalories) / Double(targetCalories), 1.5)
    }

    func addEntry(_ entry: CalorieEntry) {
        totalCalories += entry.calories
        totalProtein += entry.proteinGrams
        totalCarbs += entry.carbsGrams
        totalFat += entry.fatGrams
    }

    var waterGlasses: Int { waterMl / 250 }
}

/// Common foods library for quick entry.
struct FoodLibrary {
    struct Food {
        let name: String
        let calories: Int
        let protein: Double
        let carbs: Double
        let fat: Double
        let servingSize: String
    }

    static let commonFoods: [Food] = [
        // Proteins
        Food(name: "Chicken Breast (6oz)", calories: 280, protein: 53, carbs: 0, fat: 6, servingSize: "170g"),
        Food(name: "Salmon Fillet (6oz)", calories: 350, protein: 38, carbs: 0, fat: 22, servingSize: "170g"),
        Food(name: "Eggs (2 large)", calories: 140, protein: 12, carbs: 1, fat: 10, servingSize: "2 eggs"),
        Food(name: "Greek Yogurt (1 cup)", calories: 130, protein: 22, carbs: 8, fat: 0, servingSize: "227g"),
        Food(name: "Whey Protein Shake", calories: 120, protein: 25, carbs: 3, fat: 1, servingSize: "1 scoop"),
        Food(name: "Tuna Can", calories: 120, protein: 28, carbs: 0, fat: 1, servingSize: "142g"),
        Food(name: "Ground Turkey (4oz)", calories: 170, protein: 22, carbs: 0, fat: 9, servingSize: "113g"),

        // Carbs
        Food(name: "Rice (1 cup cooked)", calories: 200, protein: 4, carbs: 45, fat: 0, servingSize: "186g"),
        Food(name: "Oatmeal (1 cup)", calories: 300, protein: 10, carbs: 54, fat: 5, servingSize: "80g dry"),
        Food(name: "Sweet Potato (medium)", calories: 100, protein: 2, carbs: 24, fat: 0, servingSize: "130g"),
        Food(name: "Banana", calories: 105, protein: 1, carbs: 27, fat: 0, servingSize: "1 medium"),
        Food(name: "Whole Wheat Bread (2 slices)", calories: 180, protein: 8, carbs: 34, fat: 2, servingSize: "2 slices"),
        Food(name: "Pasta (1 cup cooked)", calories: 220, protein: 8, carbs: 43, fat: 1, servingSize: "140g"),

        // Fats
        Food(name: "Avocado (half)", calories: 160, protein: 2, carbs: 9, fat: 15, servingSize: "100g"),
        Food(name: "Almonds (1oz)", calories: 160, protein: 6, carbs: 6, fat: 14, servingSize: "28g"),
        Food(name: "Peanut Butter (2 tbsp)", calories: 190, protein: 7, carbs: 7, fat: 16, servingSize: "32g"),
        Food(name: "Olive Oil (1 tbsp)", calories: 120, protein: 0, carbs: 0, fat: 14, servingSize: "15ml"),

        // Meals
        Food(name: "Protein Bowl", calories: 550, protein: 45, carbs: 50, fat: 15, servingSize: "1 bowl"),
        Food(name: "Pre-Workout Snack", calories: 200, protein: 10, carbs: 30, fat: 5, servingSize: "1 serving"),
    ]

    static func search(_ query: String) -> [Food] {
        if query.isEmpty { return commonFoods }
        return commonFoods.filter { $0.name.lowercased().contains(query.lowercased()) }
    }
}
