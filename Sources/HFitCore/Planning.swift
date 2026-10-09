import Foundation

public enum FormulaSex: String, Codable, CaseIterable, Sendable {
    case unspecified = "Keine Angabe", female = "Weiblich", male = "Männlich"
}

public enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case low = "Überwiegend sitzend", moderate = "Regelmäßig in Bewegung", high = "Viel in Bewegung"
    public var factor: Double { switch self { case .low: return 1.2; case .moderate: return 1.5; case .high: return 1.75 } }
}

public struct SetupProfile: Codable, Sendable {
    public var age: Int
    public var height: Double?
    public var weight: Double?
    public var sex: FormulaSex
    public var activity: ActivityLevel
    public var automatic: Bool
    public init(age: Int, height: Double?, weight: Double?, sex: FormulaSex = .unspecified, activity: ActivityLevel = .low, automatic: Bool = false) {
        self.age = age; self.height = height; self.weight = weight; self.sex = sex; self.activity = activity; self.automatic = automatic
    }
    public var isValid: Bool {
        (1...120).contains(age) && (height.map { $0.isFinite && (80...250).contains($0) } ?? true) && (weight.map { $0.isFinite && (20...500).contains($0) } ?? true)
    }
}

public struct DailyPlan: Equatable, Sendable {
    public var resting: Double
    public var maintenance: Double
    public var calories: Double
    public var protein: Double
    public var fat: Double
    public var carbs: Double
}

public enum Planning {
    // Mifflin–St Jeor (1990). Activity factors and small goal adjustments are
    // product estimates, not a measurement or a promise of a weight-loss rate.
    public static func estimate(_ profile: Profile, weight override: Double? = nil) -> DailyPlan? {
        guard profile.isValid, profile.adult, let s = profile.setup, s.automatic,
              s.age >= 18, s.sex != .unspecified, let height = s.height, let weight = override ?? s.weight,
              weight.isFinite, (20...500).contains(weight) else { return nil }
        let bmi = weight / pow(height / 100, 2)
        guard bmi >= 18.5 else { return nil }
        let resting = 10 * weight + 6.25 * height - 5 * Double(s.age) + (s.sex == .male ? 5 : -161)
        guard resting > 0 else { return nil }
        let maintenance = resting * s.activity.factor
        let adjustment: Double
        switch profile.goal {
        case .balance: adjustment = 0
        case .lose: adjustment = -min(maintenance * 0.1, 300)
        case .build: adjustment = min(maintenance * 0.05, 200)
        }
        let calories = max(((maintenance + adjustment) / 10).rounded() * 10, ceil(max(resting, 1500) / 10) * 10)
        let protein = min(weight * (profile.goal == .build ? 1.6 : 1.2), calories * 0.3 / 4).rounded()
        let fat = (calories * 0.3 / 9).rounded()
        let carbs = max(0, (calories - protein * 4 - fat * 9) / 4).rounded()
        return DailyPlan(resting: resting, maintenance: maintenance, calories: calories, protein: protein, fat: fat, carbs: carbs)
    }

    public static func unavailableReason(_ profile: Profile) -> String {
        guard let s = profile.setup else { return "Ergänze kurz dein Profil, damit H-Fit deinen Bedarf schätzen kann." }
        if s.age < 18 { return "Für unter 18-Jährige gibt es hier keine Kalorien- oder Abnehmziele. Dein Fokus ist ausgewogen essen und gern bewegen." }
        if !s.automatic { return "Automatische Richtwerte sind ausgeschaltet. Dein Tagebuch funktioniert trotzdem." }
        if s.height == nil || s.weight == nil || s.sex == .unspecified { return "Für die Berechnung fehlen Größe, Gewicht oder die Formel-Auswahl unter Mein Plan." }
        return "Für diese Körperangaben wird kein automatisches Kalorienziel berechnet. Lass einen passenden Richtwert fachlich bestimmen." }

    public static func complete(_ diary: Diary, name: String, setup: SetupProfile, goal: Goal, now: Date = Date()) throws -> Diary {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, setup.isValid else { throw DiaryError.invalidBackup }
        var next = diary
        next.profile.name = name; next.profile.setup = setup; next.profile.adult = setup.age >= 18
        next.profile.goal = setup.age >= 18 ? goal : .balance
        // Switching to automatic must not retain a stale manual override.
        if setup.automatic || setup.age < 18 { next.profile.calorieTarget = 0; next.profile.proteinTarget = 0 }
        if setup.age < 18 { next.profile.setup?.automatic = false; next.fastingStart = nil }
        if let weight = setup.weight, (diary.weights.isEmpty || (diary.profile.setup != nil && diary.currentWeight(on: now) != weight)) {
            next.weights.append(WeightEntry(date: now, kilograms: weight))
        }
        try next.validate(); return next
    }
}

extension Diary {
    public func currentWeight(on date: Date = Date()) -> Double? {
        weights.filter { $0.date <= date }.max { $0.date < $1.date }?.kilograms ?? profile.setup?.weight
    }
    public func plan(on date: Date = Date()) -> DailyPlan? { Planning.estimate(profile, weight: currentWeight(on: date)) }
    public func calorieGoal(on date: Date = Date()) -> Double {
        guard profile.adult else { return 0 }
        if profile.setup?.automatic == true { return plan(on: date)?.calories ?? 0 }
        return profile.calorieTarget
    }
    public func proteinGoal(on date: Date = Date()) -> Double {
        guard profile.adult else { return 0 }
        if profile.setup?.automatic == true { return plan(on: date)?.protein ?? 0 }
        return profile.proteinTarget
    }
    public func waterTotal(on date: Date = Date(), calendar: Calendar = .current) -> Double {
        let logged = water.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.milliliters }
        let plainWater = meals.filter { calendar.isDate($0.date, inSameDayAs: date) && $0.food.id == "wasser" && $0.food.unit == "ml" && $0.food.per100.kcal == 0 }.reduce(0) { $0 + $1.amount }
        return logged + plainWater
    }
}

public struct ChatEntry: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var date: Date
    public var question: String
    public var answer: String
    public var provider: String?
    public init(question: String, answer: String, date: Date = Date()) { self.question = question; self.answer = answer; self.date = date }
    public var isValid: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && question.count <= 2000 && !answer.isEmpty && answer.count <= 6000 && (provider?.count ?? 0) <= 120 && date.timeIntervalSince1970.isFinite && (-2208988800...4102444800).contains(date.timeIntervalSince1970)
    }
}

public enum LocalCoach {
    /// Direct diary queries use deterministic arithmetic even when a PC model is connected.
    public static func calculatedReply(_ question: String, diary: Diary, now: Date = Date()) -> String? {
        let q = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"^wie (ist|war) meine bilanz( heute| gestern| vorgestern)?[?.!]*$"#,
            #"^wie (war|ist) meine woche[?.!]*$"#,
            #"^wie berechnest du meinen bedarf[?.!]*$"#,
            #"^wie viel (eiweiß|protein) fehlt( mir| noch| heute)*[?.!]*$"#,
            #"^wie (viel|viele) kalorien (sind|habe ich)( heute| noch| bis zu meinem richtwert)* (offen|übrig|frei)[?.!]*$"#,
            #"^wie viel (wasser habe ich|habe ich)( heute)? getrunken[?.!]*$"#
        ]
        guard patterns.contains(where: { q.range(of: $0, options: .regularExpression) != nil }) else { return nil }
        return reply(question, diary: diary, now: now)
    }
    public static func summary(_ diary: Diary, on date: Date = Date(), calendar: Calendar = .current) -> String {
        let meals = diary.meals.filter { calendar.isDate($0.date, inSameDayAs: date) }
        guard !meals.isEmpty else { return "Für diesen Tag ist noch keine Mahlzeit erfasst. Trage etwas ein, dann berechne ich deine Tagesbilanz. Fehlende Einträge bedeuten nicht, dass du nichts gegessen hast." }
        let total = diary.total(on: date, calendar: calendar), target = diary.calorieGoal(on: date)
        var text = "Erfasst: \(Int(total.kcal.rounded())) kcal und \(Int(total.protein.rounded())) g Eiweiß in \(meals.count) Lebensmitteleinträgen."
        if target > 0 {
            let difference = Int((target - total.kcal).rounded())
            text += difference >= 0 ? " Bis zum Richtwert von \(Int(target)) kcal sind rechnerisch \(difference) kcal offen." : " Deine Einträge liegen \(-difference) kcal über dem Richtwert von \(Int(target)) kcal. Ein einzelner Tag ist kein Grund, Mahlzeiten auszulassen."
        }
        text += " Die Bilanz enthält nur deine Einträge; Portions- und Produktangaben beeinflussen die Genauigkeit."
        return text
    }
    public static func insight(_ diary: Diary, on date: Date = Date(), calendar: Calendar = .current) -> String {
        let total = diary.total(on: date, calendar: calendar)
        guard diary.meals.contains(where: { calendar.isDate($0.date, inSameDayAs: date) }) else { return summary(diary, on: date, calendar: calendar) }
        if !diary.profile.adult { return "Deine Einträge sind gespeichert. Achte auf regelmäßige, abwechslungsreiche Mahlzeiten und Bewegung, die dir Spaß macht." }
        let protein = diary.proteinGoal(on: date)
        if protein == 0 { return "Du hast heute \(Int(total.protein.rounded())) g Eiweiß erfasst. Kombiniere regelmäßige Mahlzeiten mit Gemüse, sättigenden Beilagen und einer Eiweißquelle. Ein persönlicher Eiweißrichtwert ist noch nicht eingestellt." }
        if protein > total.protein { return "Zum Eiweißrichtwert sind rechnerisch noch \(Int((protein - total.protein).rounded())) g offen. Eine Eiweißquelle wie Linsen, Tofu oder Quark kann deine nächste Mahlzeit ergänzen. Hunger und Sättigung bleiben wichtig." }
        return "Dein Eiweißrichtwert ist bereits erfasst. Denke auch an Gemüse, sättigende Beilagen und Erholung. Einträge sind keine vollständige Bewertung deiner Ernährung."
    }
    public static func reply(_ question: String, diary: Diary, now: Date = Date(), calendar: Calendar = .current) -> String {
        let q = question.lowercased()
        let day = q.contains("vorgestern") ? -2 : q.contains("gestern") ? -1 : 0
        let date = calendar.date(byAdding: .day, value: day, to: now) ?? now
        if q.contains("wasser") || q.contains("getrunken") {
            return "Für diesen Tag sind \(Int(diary.waterTotal(on: date, calendar: calendar))) ml Wasser erfasst. Wasser aus dem Tagebuch und den Wasserbuttons wird zusammengezählt. Erfasse dieselbe Portion nur einmal. Andere Getränke siehst du im Ernährungstagebuch."
        }
        if q.contains("berechn") || q.contains("bedarf") || q.contains("grundumsatz") {
            guard let plan = diary.plan(on: now) else { return Planning.unavailableReason(diary.profile) }
            return "Geschätzter Ruhebedarf: \(Int(plan.resting.rounded())) kcal. Mit deiner Alltagsbewegung: etwa \(Int(plan.maintenance.rounded())) kcal. Dein Ziel ergibt daraus \(Int(plan.calories)) kcal und \(Int(plan.protein)) g Eiweiß pro Tag. Grundlage ist Mifflin–St Jeor. Die Aktivität ist bereits enthalten; Schritte und Training werden deshalb nicht noch einmal als Essensbudget addiert."
        }
        if q.contains("woche") || q.contains("durchschnitt") {
            let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
            let recorded = days.filter { day in diary.meals.contains { calendar.isDate($0.date, inSameDayAs: day) } }
            guard !recorded.isEmpty else { return "Für die letzten sieben Tage fehlen noch Essenseinträge." }
            let average = recorded.reduce(0) { $0 + diary.total(on: $1, calendar: calendar).kcal } / Double(recorded.count)
            return "An \(recorded.count) der letzten 7 Tage hast du Essen erfasst: durchschnittlich \(Int(average.rounded())) kcal pro erfasstem Tag. Auch diese Tage können unvollständig sein; daraus lässt sich noch kein tatsächliches Kaloriendefizit ableiten."
        }
        if q.contains("eiweiß") || q.contains("protein") || q.contains("muskel") { return insight(diary, on: date, calendar: calendar) }
        if q.contains("training") || q.contains("aktiv") || q.contains("sport") || q.contains("schritte") {
            let minutes = diary.workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.minutes }
            return "Für diesen Tag sind \(Int(minutes.rounded())) Trainingsminuten eingetragen. Live-Schritte findest du unter Bewegung. Dein täglicher Bedarf berücksichtigt die gewählte Alltagsaktivität bereits; ich rechne Training nicht doppelt dazu."
        }
        if q.contains("kalori") || q.contains("bilanz") || q.contains("gegessen") || q.contains("übrig") || q.contains("heute") || q.contains("gestern") { return summary(diary, on: date, calendar: calendar) }
        return "Ich kann deine erfassten Kalorien, Eiweiß, Wasser, Trainingsminuten und den Wochendurchschnitt auswerten. Frage z. B. „Wie ist meine Bilanz heute?“ oder „Wie berechnest du meinen Bedarf?“. Ich arbeite lokal mit festen Auswertungen, ohne verbundenes KI-Modell. Mahlzeiten bitte über „Eintragen“ erfassen und bestätigen."
    }
}
