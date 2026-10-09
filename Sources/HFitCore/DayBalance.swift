import Foundation

public enum DayBalance {
    public static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }
    public static func score(_ diary: Diary, on date: Date, calendar: Calendar = .current) -> Double? {
        guard diary.completedDays?.contains(key(date, calendar: calendar)) == true,
              diary.meals.contains(where: { calendar.isDate($0.date, inSameDayAs: date) }),
              diary.profile.adult else { return nil }
        let calories = diary.calorieGoal(on: date), protein = diary.proteinGoal(on: date)
        guard calories > 0, protein > 0 else { return nil }
        let total = diary.total(on: date, calendar: calendar)
        // A transparent target-comparison, never a "health" or food-morality score.
        let energyFit = max(0, 1 - abs(total.kcal / calories - 1) / 0.5)
        let proteinFit = min(1, total.protein / protein)
        return min(1, max(0, 0.7 * energyFit + 0.3 * proteinFit))
    }
}
