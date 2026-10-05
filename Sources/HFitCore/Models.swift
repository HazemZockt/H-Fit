import Foundation

private func validDiaryDate(_ date: Date) -> Bool {
    // Bound imported dates as well as numeric amounts before UI formatting/arithmetic.
    let seconds = date.timeIntervalSince1970
    return seconds.isFinite && (-2208988800...4102444800).contains(seconds)
}

public struct Nutrients: Codable, Equatable, Sendable {
    public var kcal: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    public init(_ kcal: Double = 0, _ protein: Double = 0, _ carbs: Double = 0, _ fat: Double = 0) {
        self.kcal = kcal; self.protein = protein; self.carbs = carbs; self.fat = fat
    }
    public func scaled(_ factor: Double) -> Nutrients {
        Nutrients(kcal * factor, protein * factor, carbs * factor, fat * factor)
    }
    public static func + (lhs: Nutrients, rhs: Nutrients) -> Nutrients {
        Nutrients(lhs.kcal + rhs.kcal, lhs.protein + rhs.protein, lhs.carbs + rhs.carbs, lhs.fat + rhs.fat)
    }
    public var isValid: Bool { [kcal, protein, carbs, fat].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1000 } }
}

public struct Food: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var aliases: [String]
    public var per100: Nutrients
    public var portion: Double
    public var unit: String
    public init(id: String = UUID().uuidString, name: String, aliases: [String] = [], per100: Nutrients, portion: Double = 100, unit: String = "g") {
        self.id = id; self.name = name; self.aliases = aliases; self.per100 = per100; self.portion = portion; self.unit = unit
    }
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 120 && aliases.count <= 30 && aliases.allSatisfy { $0.count <= 120 } && per100.isValid && portion.isFinite && portion > 0 && portion <= 5000 && ["g", "ml"].contains(unit)
    }
}

public struct Meal: Codable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var food: Food
    public var amount: Double
    public var estimated: Bool
    public var nutrients: Nutrients { food.per100.scaled(amount / 100) }
    public init(id: UUID = UUID(), date: Date, food: Food, amount: Double, estimated: Bool = true) {
        self.id = id; self.date = date; self.food = food; self.amount = amount; self.estimated = estimated
    }
    public var isValid: Bool { food.isValid && amount.isFinite && amount > 0 && amount <= 10000 && validDiaryDate(date) }
}

public struct Workout: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var date: Date
    public var name: String
    public var minutes: Double
    public init(date: Date, name: String, minutes: Double) { self.date = date; self.name = name; self.minutes = minutes }
    public var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 120 && minutes.isFinite && minutes > 0 && minutes <= 1440 && validDiaryDate(date) }
}

public enum Goal: String, Codable, CaseIterable, Sendable {
    case balance = "Fit bleiben", lose = "Abnehmen", build = "Muskeln aufbauen"
}

public struct Profile: Codable, Sendable {
    public var name = ""
    public var goal: Goal = .balance
    public var calorieTarget: Double = 0
    public var proteinTarget: Double = 0
    public var adult = false
    public init() {}
    public var isValid: Bool {
        name.count <= 80 && calorieTarget.isFinite && calorieTarget >= 0 && calorieTarget <= 10000 && proteinTarget.isFinite && proteinTarget >= 0 && proteinTarget <= 500
    }
}

public struct Diary: Codable, Sendable {
    public var version = 1
    public var profile = Profile()
    public var meals: [Meal] = []
    public var workouts: [Workout] = []
    public var customFoods: [Food] = []
    public var water: [WaterEntry] = []
    public var weights: [WeightEntry] = []
    public var recipes: [Recipe] = []
    public var fastingStart: Date?
    public init() {}
    public func validate() throws {
        guard version == 1, profile.isValid, meals.count <= 100000, workouts.count <= 100000, customFoods.count <= 10000,
              meals.allSatisfy(\.isValid), workouts.allSatisfy(\.isValid), customFoods.allSatisfy(\.isValid),
              Set(meals.map(\.id)).count == meals.count, Set(workouts.map(\.id)).count == workouts.count,
              Set(customFoods.map(\.id)).count == customFoods.count,
              water.count <= 100000, water.allSatisfy(\.isValid), Set(water.map(\.id)).count == water.count,
              weights.count <= 100000, weights.allSatisfy(\.isValid), Set(weights.map(\.id)).count == weights.count,
              recipes.count <= 10000, recipes.allSatisfy(\.isValid), Set(recipes.map(\.id)).count == recipes.count,
              fastingStart.map(validDiaryDate) ?? true else { throw DiaryError.invalidBackup }
    }
    public func total(on date: Date, calendar: Calendar = .current) -> Nutrients {
        meals.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(Nutrients()) { $0 + $1.nutrients }
    }
}

public struct WaterEntry: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var date: Date
    public var milliliters: Double
    public init(date: Date = Date(), milliliters: Double) { self.date = date; self.milliliters = milliliters }
    public var isValid: Bool { milliliters.isFinite && milliliters > 0 && milliliters <= 5000 && validDiaryDate(date) }
}
public struct WeightEntry: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var date: Date
    public var kilograms: Double
    public init(date: Date = Date(), kilograms: Double) { self.date = date; self.kilograms = kilograms }
    public var isValid: Bool { kilograms.isFinite && kilograms >= 20 && kilograms <= 500 && validDiaryDate(date) }
}
public struct Recipe: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var ingredients: [Meal]
    public var servings: Double
    public var instructions: String
    public init(name: String, ingredients: [Meal], servings: Double, instructions: String = "") { self.name = name; self.ingredients = ingredients; self.servings = servings; self.instructions = instructions }
    public var total: Nutrients { ingredients.reduce(Nutrients()) { $0 + $1.nutrients } }
    public var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 120 && !ingredients.isEmpty && ingredients.count <= 200 && ingredients.allSatisfy(\.isValid) && servings.isFinite && servings > 0 && servings <= 100 && instructions.count <= 10000 }
    public func meals(for portions: Double = 1, at date: Date = Date()) -> [Meal] {
        ingredients.map { Meal(date: date, food: $0.food, amount: $0.amount * portions / servings) }
    }
}
public enum DiaryError: LocalizedError {
    case invalidBackup
    public var errorDescription: String? { "Die Datei enthält ungültige oder nicht unterstützte H-Fit-Daten." }
}
