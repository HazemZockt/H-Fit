import XCTest
@testable import HFitCore

final class DayBalanceTests: XCTestCase {
    func testCompleteDayAndCalorieExtremes() throws {
        let date = Date()
        var diary = Diary()
        diary.profile.adult = true
        diary.profile.calorieTarget = 2000
        diary.profile.proteinTarget = 100
        diary.meals = [Meal(date: date, food: Food(name: "Test", per100: Nutrients(200, 10, 20, 5)), amount: 1000)]
        XCTAssertNil(DayBalance.score(diary, on: date))
        diary.completedDays = [DayBalance.key(date)]
        XCTAssertEqual(try XCTUnwrap(DayBalance.score(diary, on: date)), 1, accuracy: 0.001)
        diary.meals[0].amount = 2000
        XCTAssertEqual(try XCTUnwrap(DayBalance.score(diary, on: date)), 0.3, accuracy: 0.001)
        diary.meals[0].amount = 100
        XCTAssertLessThan(try XCTUnwrap(DayBalance.score(diary, on: date)), 0.1)
        diary.profile.adult = false
        XCTAssertNil(DayBalance.score(diary, on: date))
        diary.profile.adult = true
        diary.profile.proteinTarget = 0
        XCTAssertNil(DayBalance.score(diary, on: date))
    }
}
