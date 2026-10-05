import Foundation

public struct ParsedItem: Identifiable {
    public var id = UUID()
    public var text: String
    public var food: Food?
    public var amount: Double
    public var estimatedPortion: Bool
}
public struct ParseResult {
    public var date: Date
    public var items: [ParsedItem]
    public var notes: [String]
    public init(date: Date, items: [ParsedItem], notes: [String]) { self.date = date; self.items = items; self.notes = notes }
}

public enum MealParser {
    public static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current, customFoods: [Food] = []) -> ParseResult {
        var input = normalize(text)
        var date = now
        var notes = ["Nährwerte sind Richtwerte. Mengen, Zubereitung und Verpackungsangaben bitte prüfen."]
        if input.contains("vorgestern") { date = calendar.date(byAdding: .day, value: -2, to: now) ?? now }
        else if input.contains("gestern") { date = calendar.date(byAdding: .day, value: -1, to: now) ?? now }
        let timePattern = #"\b(?:um\s+)?(\d{1,2})(?::(\d{2}))?\s*uhr\b|\bum\s+(\d{1,2}):(\d{2})\b"#
        if let match = first(timePattern, in: input) {
            let h = Int(group(match, 1, input).isEmpty ? group(match, 3, input) : group(match, 1, input)) ?? 0
            let m = Int(group(match, 2, input).isEmpty ? group(match, 4, input) : group(match, 2, input)) ?? 0
            if (0...23).contains(h), (0...59).contains(m) { date = calendar.date(bySettingHour: h, minute: m, second: 0, of: date) ?? date }
            else { notes.append("Die Uhrzeit war ungültig. Bitte selbst einstellen.") }
        } else {
            let hour: Int? = input.contains("frühstück") || input.contains("morgens") ? 8 : input.contains("mittags") || input.contains("mittagessen") ? 12 : input.contains("abends") || input.contains("abendessen") ? 19 : nil
            if let hour { date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date }
        }
        input = replace(timePattern, in: input, with: " ")
        input = replace(#"\b(heute|gestern|vorgestern|morgens|mittags|abends|zum frühstück|frühstück|zum mittagessen|mittagessen|zum abendessen|abendessen|ich habe|ich hab|ich|habe|hab|gegessen|getrunken|hatte|noch|dazu)\b"#, in: input, with: " ")
        input = replace(#"\b(eine?|einen)\s+halbe?[nr]?\b"#, in: input, with: "0.5")
        let words = ["ein": "1", "eine": "1", "einen": "1", "einem": "1", "zwei": "2", "drei": "3", "vier": "4", "fünf": "5", "sechs": "6", "halb": "0.5", "halbe": "0.5", "halben": "0.5"]
        for (word, value) in words { input = replace("\\b" + word + "\\b", in: input, with: value) }
        input = replace(#"(?<=\d),(?=\d)"#, in: input, with: ".")
        input = replace(#"\s+(und|mit|plus|sowie)\s+|[,;\n+]"#, in: input, with: "|")
        let catalog = customFoods + FoodCatalog.foods
        let aliases = catalog.flatMap { food in (food.aliases + [food.name]).map { (normalize($0), food) } }.sorted { $0.0.count > $1.0.count }
        let items = input.components(separatedBy: "|").compactMap { raw -> ParsedItem? in
            let segment = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard !segment.isEmpty else { return nil }
            let matches = aliases.filter { alias, _ in first("(?<![\\p{L}])" + NSRegularExpression.escapedPattern(for: alias) + "(?![\\p{L}])", in: segment) != nil }
            let food = matches.first?.1
            let qty = first(#"\b(\d+(?:\.\d+)?)\s*(kilogramm|kg|gramm|g|milliliter|ml|liter|l|el|tl|scheiben?|stücke?|portionen?|becher|glas|gläser)?\b"#, in: segment)
            var amount = food?.portion ?? 100
            var estimated = true
            if let qty {
                let value = Double(group(qty, 1, segment)) ?? 1
                let unit = group(qty, 2, segment)
                switch unit {
                case "g", "gramm", "ml", "milliliter": amount = value; estimated = false
                case "kg", "kilogramm", "l", "liter": amount = value * 1000; estimated = false
                case "el": amount = value * 15
                case "tl": amount = value * 5
                case "glas", "gläser": amount = value * 250
                default: amount = value * (food?.portion ?? 100)
                }
            }
            // Ambiguous combinations must not silently drop a second food.
            let distinct = Set(matches.filter { match in
                guard let longest = matches.first else { return true }
                return !longest.0.contains(match.0) || match.1.id == longest.1.id
            }.map { $0.1.id })
            let safeFood = distinct.count > 1 ? nil : food
            return ParsedItem(text: segment, food: safeFood, amount: amount, estimatedPortion: estimated)
        }
        return ParseResult(date: date, items: items, notes: notes)
    }
    private static func normalize(_ s: String) -> String { s.lowercased() }
    private static func first(_ pattern: String, in text: String) -> NSTextCheckingResult? { (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) }
    private static func group(_ match: NSTextCheckingResult, _ index: Int, _ text: String) -> String { guard index < match.numberOfRanges, let range = Range(match.range(at: index), in: text) else { return "" }; return String(text[range]) }
    private static func replace(_ pattern: String, in text: String, with replacement: String) -> String { (try? NSRegularExpression(pattern: pattern))?.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: replacement) ?? text }
}
