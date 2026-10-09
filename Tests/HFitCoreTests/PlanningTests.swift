import XCTest
@testable import HFitCore

final class PlanningTests: XCTestCase {
    func profile(age: Int = 30, weight: Double = 80, sex: FormulaSex = .male, goal: Goal = .balance) -> Profile {
        var p = Profile(); p.adult = age >= 18; p.goal = goal
        p.setup = SetupProfile(age: age, height: 180, weight: weight, sex: sex, activity: .moderate, automatic: true)
        return p
    }
    func testReferenceFormulaAndGoalAdjustment() throws {
        let p = profile()
        let plan = try XCTUnwrap(Planning.estimate(p))
        XCTAssertEqual(plan.resting, 1780, accuracy: 0.01)
        XCTAssertEqual(plan.maintenance, 2670, accuracy: 0.01)
        XCTAssertEqual(plan.calories, 2670)
        XCTAssertEqual(plan.protein, 96)
        XCTAssertEqual(try XCTUnwrap(Planning.estimate(profile(goal: .lose))).calories, 2400)
        let build = try XCTUnwrap(Planning.estimate(profile(goal: .build)))
        XCTAssertEqual(build.calories, 2800)
        XCTAssertEqual(build.protein, 128)
        XCTAssertEqual(build.protein * 4 + build.carbs * 4 + build.fat * 9, build.calories, accuracy: 5)
        XCTAssertEqual(try XCTUnwrap(Planning.estimate(profile(sex: .female))).resting, 1614)
    }
    func testIncompleteOrUnsuitableProfilesHaveNoInventedTarget() {
        XCTAssertNil(Planning.estimate(Profile()))
        XCTAssertNil(Planning.estimate(profile(age: 16)))
        XCTAssertNil(Planning.estimate(profile(weight: 50, goal: .lose)))
        XCTAssertNil(Planning.estimate(profile(sex: .unspecified)))
        var p = profile(); p.setup?.height = nil; XCTAssertNil(Planning.estimate(p))
        p = profile(); p.setup?.automatic = false; XCTAssertNil(Planning.estimate(p))
        XCTAssertNil(Planning.estimate(profile(), weight: .infinity))
    }
    func testSetupMigrationPreservesDiaryAndDoesNotDuplicateWeight() throws {
        var diary = Diary(); diary.profile.calorieTarget = 2200
        diary.water = [WaterEntry(milliliters: 250)]
        let data = try JSONEncoder().encode(diary)
        let migrated = try JSONDecoder().decode(Diary.self, from: data)
        XCTAssertNil(migrated.profile.setup)
        let setup = try XCTUnwrap(profile().setup)
        let next = try Planning.complete(migrated, name: " Alex ", setup: setup, goal: .build)
        XCTAssertEqual(next.profile.name, "Alex"); XCTAssertEqual(next.water.count, 1)
        XCTAssertEqual(next.profile.calorieTarget, 0); XCTAssertEqual(next.weights.count, 1)
        XCTAssertEqual(try Planning.complete(next, name: "Alex", setup: setup, goal: .build).weights.count, 1)
        var minor = setup; minor.age = 16
        let young = try Planning.complete(next, name: "Alex", setup: minor, goal: .lose)
        XCTAssertEqual(young.profile.goal, .balance); XCTAssertFalse(young.profile.adult)
        XCTAssertEqual(young.calorieGoal(), 0); XCTAssertNil(young.fastingStart)
        XCTAssertThrowsError(try Planning.complete(diary, name: " ", setup: setup, goal: .balance))
    }
    func testNewWeightChangesPlanAndDeletingItRestoresPreviousPlan() throws {
        var diary = Diary(); diary.profile = profile()
        let now = Date(), original = diary.calorieGoal(on: now)
        diary.weights = [WeightEntry(date: now, kilograms: 85), WeightEntry(date: now.addingTimeInterval(86400), kilograms: 90)]
        XCTAssertEqual(diary.currentWeight(on: now), 85)
        XCTAssertGreaterThan(diary.calorieGoal(on: now), original)
        diary.weights = []; XCTAssertEqual(diary.calorieGoal(on: now), original)
    }
    func testActivityIsNotDoubleCountedAndManualTargetStillWorks() {
        var diary = Diary(); diary.profile = profile(); let target = diary.calorieGoal()
        diary.workouts.append(Workout(date: Date(), name: "Krafttraining", minutes: 60))
        XCTAssertEqual(diary.calorieGoal(), target)
        diary.profile.setup?.automatic = false; diary.profile.calorieTarget = 2100
        XCTAssertEqual(diary.calorieGoal(), 2100)
    }
    func testMealEditingAndDeletionRecalculateTotals() {
        var d = Diary(); let today = Date()
        d.meals = [Meal(date: today, food: Food(name: "Test", per100: Nutrients(200, 10, 20, 5)), amount: 150)]
        XCTAssertEqual(d.total(on: today).kcal, 300)
        d.meals[0].amount = 50; XCTAssertEqual(d.total(on: today).kcal, 100)
        d.meals = []; XCTAssertEqual(d.total(on: today).kcal, 0)
    }
    func testWaterFromMealsAndButtonsAndDayBoundary() throws {
        var d = Diary(); let today = Date(), yesterday = today.addingTimeInterval(-86400)
        let water = try XCTUnwrap(FoodCatalog.foods.first { $0.id == "wasser" })
        d.meals = [Meal(date: today, food: water, amount: 500), Meal(date: yesterday, food: water, amount: 1000)]
        d.water = [WaterEntry(date: today, milliliters: 250)]
        XCTAssertEqual(d.waterTotal(on: today), 750)
        d.meals[0].amount = 300; XCTAssertEqual(d.waterTotal(on: today), 550)
    }
    func testCoachUsesEntriesAndDoesNotTreatMissingDaysAsZeroConsumption() {
        var d = Diary(); d.profile = profile()
        XCTAssertTrue(LocalCoach.summary(d).contains("noch keine Mahlzeit"))
        d.meals = [Meal(date: Date(), food: Food(name: "Test", per100: Nutrients(200, 10)), amount: 150)]
        XCTAssertTrue(LocalCoach.reply("Bilanz heute", diary: d).contains("300 kcal"))
        XCTAssertTrue(LocalCoach.reply("Meine Woche", diary: d).contains("1 der letzten 7"))
        XCTAssertTrue(LocalCoach.reply("Meine Woche", diary: d).contains("300 kcal"))
        XCTAssertTrue(LocalCoach.reply("unbekannte Frage", diary: d).contains("ohne verbundenes KI-Modell"))
    }
    func testChatPersistsAndRejectsInvalidImports() throws {
        var d = Diary(); d.chat = [ChatEntry(question: "Hallo", answer: "Hallo")]
        let restored = try JSONDecoder().decode(Diary.self, from: JSONEncoder().encode(d))
        try restored.validate(); XCTAssertEqual(restored.chat?.first?.question, "Hallo")
        let duplicate = try XCTUnwrap(d.chat?.first)
        d.chat?.append(duplicate); XCTAssertThrowsError(try d.validate())
    }
    func testFutureMealTimeIsFlaggedAndUsesNow() {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = c.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 10))!
        let result = MealParser.parse("Heute um 19 Uhr eine Banane", now: now, calendar: c)
        XCTAssertEqual(result.date, now); XCTAssertTrue(result.notes.contains { $0.contains("Zukunft") })
    }
}
