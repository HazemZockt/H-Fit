import XCTest
@testable import HFitCore

final class HFitCoreTests: XCTestCase {
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Berlin")!; return c }
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 15))! }

    func testGermanMealWithTimeAndAmounts() {
        let parsed = MealParser.parse("Heute um 8 Uhr 60 g Haferflocken mit 200 ml Milch und eine Banane", now: now, calendar: calendar)
        XCTAssertEqual(parsed.items.count, 3)
        XCTAssertEqual(parsed.items.map(\.amount), [60, 200, 120])
        XCTAssertTrue(parsed.items.allSatisfy { $0.food != nil })
        XCTAssertEqual(calendar.component(.hour, from: parsed.date), 8)
        let kcal = parsed.items.reduce(0) { $0 + ($1.food?.per100.kcal ?? 0) * $1.amount / 100 }
        XCTAssertEqual(kcal, 424, accuracy: 0.01)
    }
    func testDecimalsUnitsAndWordNumbers() {
        let parsed = MealParser.parse("1,5 l Wasser, zwei Eier und eine halbe Banane")
        XCTAssertEqual(parsed.items.count, 3)
        XCTAssertEqual(parsed.items.map(\.amount), [1500, 120, 60])
        XCTAssertFalse(parsed.items[0].estimatedPortion)
        XCTAssertTrue(parsed.items[1].estimatedPortion)
    }
    func testYesterdayAndRawRice() {
        let parsed = MealParser.parse("Gestern um 19:30 Uhr 80g Reis trocken und 150g Hähnchen", now: now, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: parsed.date), 4)
        XCTAssertEqual(calendar.component(.hour, from: parsed.date), 19)
        XCTAssertEqual(calendar.component(.minute, from: parsed.date), 30)
        XCTAssertEqual(parsed.items[0].food?.per100.kcal, 350)
        XCTAssertEqual(parsed.items[0].amount, 80)
    }
    func testUnknownFoodDoesNotInventNutrition() {
        let parsed = MealParser.parse("250 g Zauberkuchen")
        XCTAssertNil(parsed.items.first?.food)
        XCTAssertEqual(parsed.items.first?.amount, 250)
    }
    func testAmbiguousCombinationRequiresReview() {
        XCTAssertNil(MealParser.parse("200g Reis 150g Hähnchen").items.first?.food)
    }
    func testLongerAliasWins() {
        XCTAssertEqual(MealParser.parse("330 ml Cola Zero").items.first?.food?.per100.kcal, 0)
        XCTAssertEqual(MealParser.parse("200 ml Hafermilch").items.first?.food?.name, "Haferdrink")
    }
    func testCustomProductRecognition() {
        let food = Food(name: "Mein Proteinriegel", per100: Nutrients(350, 30, 25, 12), portion: 50)
        XCTAssertEqual(MealParser.parse("2 Mein Proteinriegel", customFoods: [food]).items.first?.amount, 100)
    }
    func testDayTotalsRespectCalendarBoundary() {
        var diary = Diary()
        let food = Food(name: "Test", per100: Nutrients(100, 10, 20, 2))
        diary.meals = [Meal(date: now, food: food, amount: 150), Meal(date: calendar.date(byAdding: .day, value: -1, to: now)!, food: food, amount: 100)]
        XCTAssertEqual(diary.total(on: now, calendar: calendar).kcal, 150)
    }
    func testBackupRoundTripAndRejection() throws {
        var diary = Diary()
        diary.water.append(WaterEntry(milliliters: 250))
        diary.weights.append(WeightEntry(kilograms: 75))
        let data = try JSONEncoder().encode(diary)
        let restored = try JSONDecoder().decode(Diary.self, from: data)
        try restored.validate()
        XCTAssertEqual(restored.water.first?.milliliters, 250)
        diary.profile.calorieTarget = -.infinity
        XCTAssertThrowsError(try diary.validate())
        diary.profile.calorieTarget = 0; diary.version = 99
        XCTAssertThrowsError(try diary.validate())
        diary.version = 1; diary.fastingStart = Date(timeIntervalSince1970: 1e100)
        XCTAssertThrowsError(try diary.validate())
    }
    func testDuplicateIDsAndInvalidAmountsRejected() {
        var diary = Diary()
        let meal = Meal(date: now, food: FoodCatalog.foods[0], amount: 60)
        diary.meals = [meal, meal]
        XCTAssertThrowsError(try diary.validate())
        diary.meals = [Meal(date: now, food: FoodCatalog.foods[0], amount: -10)]
        XCTAssertThrowsError(try diary.validate())
    }
    func testRecipeScalingDoesNotChangeOriginal() {
        let recipe = Recipe(name: "Frühstück", ingredients: [Meal(date: now, food: FoodCatalog.foods[0], amount: 100)], servings: 2)
        XCTAssertTrue(recipe.isValid)
        XCTAssertEqual(recipe.meals(for: 1, at: now)[0].amount, 50)
        XCTAssertEqual(recipe.ingredients[0].amount, 100)
        XCTAssertNotEqual(recipe.meals()[0].id, recipe.ingredients[0].id)
    }
    func testBreakfastAndInvalidTime() {
        XCTAssertEqual(calendar.component(.hour, from: MealParser.parse("zum Frühstück zwei Eier", now: now, calendar: calendar).date), 8)
        XCTAssertEqual(MealParser.parse("um 99 Uhr eine Banane", now: now, calendar: calendar).notes.count, 2)
    }
    func testCatalogIsValid() {
        XCTAssertTrue(FoodCatalog.foods.allSatisfy(\.isValid))
        XCTAssertEqual(Set(FoodCatalog.foods.map(\.id)).count, FoodCatalog.foods.count)
    }
}
