import Foundation
import Combine
import CryptoKit
import Security
import HFitCore

private final class PinnedSession: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    let pairing: AIPairing
    init(_ pairing: AIPairing) { self.pairing = pairing }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == URL(string: pairing.url)?.host,
              let trust = challenge.protectionSpace.serverTrust,
              let cert = SecTrustGetCertificateAtIndex(trust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }
        let hash = SHA256.hash(data: SecCertificateCopyData(cert) as Data).map { String(format: "%02x", $0) }.joined()
        guard hash == pairing.fingerprint else { completionHandler(.cancelAuthenticationChallenge, nil); return }
        // Trust only the exact certificate that the user paired by QR code.
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor final class AICompanion: ObservableObject {
    @Published private(set) var pairing: AIPairing?
    @Published private(set) var status = "Noch kein PC verbunden"
    @Published private(set) var busy = false
    private let key: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: "de.hfit.ai-companion", kSecAttrAccount as String: "paired-pc"]
    init() {
        var query = key; query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data, let loaded = try? JSONDecoder().decode(AIPairing.self, from: data), loaded.isValid {
            pairing = loaded; status = "PC gekoppelt · Verbindung noch nicht geprüft"
        }
    }
    func pair(_ code: String) async throws {
        let candidate: AIPairing
        do { candidate = try AIPairing.parse(code) } catch { throw failure("Der Kopplungscode ist ungültig. Bitte den QR-Code auf deinem PC verwenden.") }
        let data = try await request("health", pairing: candidate)
        let info = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard info?["ready"] as? Bool == true else { throw failure("Die KI am PC ist noch nicht bereit.") }
        let encoded = try JSONEncoder().encode(candidate)
        let update = [kSecValueData as String: encoded]
        var result = SecItemUpdate(key as CFDictionary, update as CFDictionary)
        if result == errSecItemNotFound {
            var entry = key; entry[kSecValueData as String] = encoded
            entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            result = SecItemAdd(entry as CFDictionary, nil)
        }
        guard result == errSecSuccess else { throw failure("Die Kopplung konnte nicht sicher gespeichert werden.") }
        pairing = candidate; status = "Verbunden · \(info?["model"] as? String ?? "lokale KI")"
    }
    func disconnect() {
        let result = SecItemDelete(key as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else { status = "Kopplung konnte nicht gelöscht werden."; return }
        pairing = nil; status = "Verbindung getrennt"
    }
    func ask(_ question: String, diary: Diary) async throws -> AIResponse {
        guard let pairing else { throw failure("Bitte zuerst deinen PC koppeln.") }
        guard !busy else { throw failure("Bitte warte auf die laufende Antwort.") }
        busy = true; status = "KI denkt auf deinem PC …"; defer { busy = false }
        let now = Date(), total = diary.total(on: now)
        let dayFacts = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: now) }
            .map { "\($0.formatted(date: .numeric, time: .omitted)): \(LocalCoach.summary(diary, on: $0))" }.joined(separator: "\n")
        let facts = "Heute: \(now.formatted(date: .complete, time: .shortened)). Fokus: \(diary.profile.goal.rawValue). "
            + "Alter: \(diary.profile.setup?.age ?? 0). \(LocalCoach.summary(diary, on: now)) "
            + "Eiweißrichtwert: \(diary.proteinGoal()) g. Wasser: \(diary.waterTotal()) ml. "
            + "Makros erfasst: \(total.protein) g Eiweiß, \(total.carbs) g Kohlenhydrate, \(total.fat) g Fett. "
            + LocalCoach.reply("Meine Woche", diary: diary) + " " + LocalCoach.reply("Wie berechnest du meinen Bedarf?", diary: diary) + "\n" + dayFacts
        let history = (diary.chat ?? []).suffix(4).flatMap { [ ["role": "user", "content": $0.question], ["role": "assistant", "content": $0.answer] ] }
        let foods = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Array(diary.customFoods.prefix(100))))
        let payload: [String: Any] = ["question": question, "facts": facts, "history": history, "foods": foods, "adult": diary.profile.adult]
        do {
            let data = try await request("chat", pairing: pairing, body: JSONSerialization.data(withJSONObject: payload))
            let response = try JSONDecoder().decode(AIResponse.self, from: data)
            guard response.isValid else { throw failure("Die KI-Antwort war ungültig. Es wurde nichts eingetragen.") }
            status = "Verbunden · \(response.model)"; return response
        } catch {
            status = "Verbindung prüfen · Frage wurde nicht eingetragen"
            if error is URLError { throw failure("PC nicht erreichbar oder Zeitlimit überschritten. Sind PC und iPhone im selben WLAN und läuft H-Fit KI am PC?") }
            throw error
        }
    }
    private func request(_ path: String, pairing: AIPairing, body: Data? = nil) async throws -> Data {
        let url = URL(string: pairing.url)!.appendingPathComponent(path)
        let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 200; config.timeoutIntervalForResource = 210
        let session = URLSession(configuration: config, delegate: PinnedSession(pairing), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url); request.httpMethod = body == nil ? "GET" : "POST"; request.httpBody = body
        request.setValue("Bearer \(pairing.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        guard data.count <= 500000, let http = response as? HTTPURLResponse else { throw failure("Ungültige Serverantwort.") }
        guard http.statusCode == 200 else {
            let error = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw failure(error?["error"] as? String ?? "Der PC konnte die Anfrage nicht bearbeiten.")
        }
        return data
    }
    private func failure(_ text: String) -> NSError { NSError(domain: "HFitAI", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
}
