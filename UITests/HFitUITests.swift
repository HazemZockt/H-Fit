import XCTest

final class HFitUITests: XCTestCase {
    @MainActor
    func testSetupAndMealCalculation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--hfit-ui-test", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        XCTAssertTrue(app.textFields["setup-name"].waitForExistence(timeout: 15))
        app.textFields["setup-name"].tap(); app.textFields["setup-name"].typeText("Alex")
        app.textFields["setup-age"].tap(); app.textFields["setup-age"].typeText("30")
        reveal(app.buttons["setup-next"], in: app); app.buttons["setup-next"].tap()
        app.textFields["setup-height"].tap(); app.textFields["setup-height"].typeText("180")
        app.textFields["setup-weight"].tap(); app.textFields["setup-weight"].typeText("80")
        reveal(app.buttons["setup-sex"], in: app); app.buttons["setup-sex"].tap()
        app.buttons["Männlich"].tap()
        reveal(app.buttons["setup-next"], in: app); app.buttons["setup-next"].tap()
        app.buttons["setup-activity"].tap(); app.buttons["Regelmäßig in Bewegung"].tap()
        reveal(app.buttons["setup-next"], in: app)
        attach(app, name: "Einrichtung mit berechnetem Plan")
        app.buttons["setup-next"].tap()
        XCTAssertTrue(app.staticTexts["Hey, Alex."].waitForExistence(timeout: 5))
        let target = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Dein Richtwert:")).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label.filter(\.isNumber), "2670")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Was hast du gegessen?")).firstMatch.tap()
        let editor = app.textViews["Deine Mahlzeit"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5)); editor.tap(); editor.typeText("100 g Haferflocken")
        reveal(app.buttons["Mahlzeit erkennen"], in: app); app.buttons["Mahlzeit erkennen"].tap()
        XCTAssertTrue(app.navigationBars["Passt das so?"].waitForExistence(timeout: 5))
        let save = app.buttons["1 Einträge speichern"]
        reveal(save, in: app); save.tap()
        XCTAssertTrue(app.staticTexts["372"].waitForExistence(timeout: 5))
        let remaining = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Noch ")).firstMatch
        XCTAssertTrue(remaining.waitForExistence(timeout: 5))
        XCTAssertEqual(remaining.label.filter(\.isNumber), "2298")
        XCTAssertTrue(remaining.label.hasSuffix("kcal offen"))
        attach(app, name: "Tagesbilanz")
        app.tabBars.buttons["Assistent"].tap()
        app.buttons["Wie ist meine Bilanz heute?"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Erfasst: 372 kcal")).firstMatch.waitForExistence(timeout: 5))
        attach(app, name: "Lokaler Assistent")
        app.tabBars.buttons["Verlauf"].tap()
        app.buttons["Monat"].tap()
        XCTAssertTrue(app.buttons["Vorheriger Monat"].waitForExistence(timeout: 5))
        let complete = app.switches["Tag vollständig erfasst"]
        reveal(complete, in: app)
        XCTAssertTrue(complete.isEnabled)
        // SwiftUI exposes the full label row as a switch. Tap the actual control at its trailing edge.
        complete.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: complete)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        app.swipeDown(); app.swipeDown()
        attach(app, name: "Monatsübersicht")
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
