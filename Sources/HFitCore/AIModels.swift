import Foundation

public struct AIProposalItem: Codable, Identifiable, Sendable {
    public var id: String { query }
    public var query: String
    public var amount: Double?
    public var unit: String
    public var uncertain: Bool
    public var candidates: [Food]
    public var source: String
    public var isValid: Bool {
        !query.isEmpty && query.count <= 120 && (amount.map { $0.isFinite && $0 > 0 && $0 <= 10000 } ?? true)
        && ["g", "ml", "piece"].contains(unit) && candidates.count <= 5 && candidates.allSatisfy(\.isValid) && source.count <= 300
    }
}

public struct AIResponse: Codable, Sendable {
    public var reply: String
    public var model: String
    public var intent: String
    public var items: [AIProposalItem]
    public var dayOffset: Int
    public var hour: Int?
    public var minute: Int?
    public var isValid: Bool {
        !reply.isEmpty && reply.count <= 6000 && model.count <= 100 && ["meal", "chat", "suggestion"].contains(intent)
        && items.count <= 12 && items.allSatisfy(\.isValid) && (-2...0).contains(dayOffset)
        && (hour.map { (0...23).contains($0) } ?? true) && (minute.map { (0...59).contains($0) } ?? true)
    }
    public func proposedDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        var date = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
        if let hour { date = calendar.date(bySettingHour: hour, minute: minute ?? 0, second: 0, of: date) ?? date }
        return min(date, now)
    }
}

public struct AIPairing: Codable, Sendable {
    public var url: String
    public var token: String
    public var fingerprint: String
    public var isValid: Bool {
        guard let u = URLComponents(string: url), u.scheme == "https", let host = u.host,
              u.user == nil, u.password == nil, u.query == nil, u.fragment == nil,
              u.path.isEmpty || u.path == "/", (1...65535).contains(u.port ?? 443) else { return false }
        let segments = host.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 4, segments.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return false }
        let parts = segments.compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return false }
        let privateAddress = parts[0] == 10 || (parts[0] == 192 && parts[1] == 168) || (parts[0] == 172 && (16...31).contains(parts[1]))
        return privateAddress && (32...128).contains(token.count) && token.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
            && fingerprint.count == 64 && fingerprint.allSatisfy { "0123456789abcdef".contains($0) }
    }
    public static func parse(_ text: String) throws -> AIPairing {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 4096, let url = URLComponents(string: trimmed), url.scheme == "hfit", url.host == "pair",
              var base64 = url.queryItems?.first(where: { $0.name == "data" })?.value else { throw DiaryError.invalidBackup }
        base64 = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { throw DiaryError.invalidBackup }
        let pairing = try JSONDecoder().decode(AIPairing.self, from: data)
        guard pairing.isValid else { throw DiaryError.invalidBackup }
        return pairing
    }
}
