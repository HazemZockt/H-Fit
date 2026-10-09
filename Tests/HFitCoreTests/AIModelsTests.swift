import XCTest
@testable import HFitCore

final class AIModelsTests: XCTestCase {
    func testPairingOnlyAcceptsPrivateHTTPSAndValidSecrets() throws {
        var pairing = AIPairing(url: "https://192.168.178.20:8787", token: String(repeating: "a", count: 43), fingerprint: String(repeating: "b", count: 64))
        XCTAssertTrue(pairing.isValid)
        let encoded = try JSONEncoder().encode(pairing).base64EncodedString()
        XCTAssertEqual(try AIPairing.parse("hfit://pair?data=\(encoded)").url, pairing.url)
        for url in ["http://192.168.1.1", "https://8.8.8.8", "https://localhost", "https://192.168.1.1/other", "https://user@192.168.1.1", "https://192.168.1.1?token=x"] {
            pairing.url = url
            XCTAssertFalse(pairing.isValid, url)
        }
    }
    func testDiaryArithmeticDoesNotGoToModelOrInterceptMeals() throws {
        var diary = Diary()
        diary.profile.adult = true
        diary.profile.calorieTarget = 2670
        let now = Date()
        diary.meals = [Meal(date: now, food: Food(name: "Test", per100: Nutrients(424)), amount: 100)]
        let answer = try XCTUnwrap(LocalCoach.calculatedReply("Wie viele Kalorien sind bis zu meinem Richtwert noch offen?", diary: diary, now: now))
        XCTAssertTrue(answer.contains("2246") || answer.contains("2.246"))
        XCTAssertNil(LocalCoach.calculatedReply("Ich habe 60 g Haferflocken gegessen", diary: diary))
        XCTAssertNil(LocalCoach.calculatedReply("Wie viele Kalorien hat meine Pizza?", diary: diary))
        XCTAssertNil(LocalCoach.calculatedReply("Was kann ich morgen essen?", diary: diary))
    }
}
