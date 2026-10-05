# Prüfstatus

Stand: 5. Oktober 2026. Entwicklungsumgebung: Windows.

## Lokal überprüft

- Projektdateien, Info.plist und vier erforderliche Datenschutzbeschreibungen.
- XcodeGen-Konfiguration, lokales Swift-Paket, GitHub-Buildfolge und IPA-Paketpfad.
- App-Icon als 1024 × 1024 RGB-PNG und Asset-Verweise.
- Manuelle Durchsicht der Eingabe-, Validierungs-, Sicherungs- und Fehlerpfade.

## Noch nicht verifiziert

- **Swift-Kompilierung, XCTest-Ausführung, Xcode-Build und App-Start.** Swift/Xcode fehlen hier. Der Workflow enthält 13 Tests, sie sind vorbereitet, nicht lokal bestanden.
- Ein zusätzlich versuchter Swift-Grammatikparser ließ sich wegen einer Windows-Anwendungsrichtlinie nicht laden. Es wird deshalb auch keine erfolgreiche automatische Swift-Syntaxprüfung behauptet.
- Kamera, Mikrofon, deutsche Spracherkennung, Schritte, native Darstellung und Sideloading auf dem iPhone.
- Live-Abfrage der Open-Food-Facts-API aus der App.

## Vor dem ersten zuverlässigen Einsatz

1. GitHub-Workflow erfolgreich ausführen: `swift test`, dann iOS-Release-Build.
2. Auf dem iPhone starten; Textbeispiel aus der Installationsanleitung erfassen, Menge ändern, App neu starten und Speicherung prüfen.
3. Mikrofon/Sprache einmal erlauben, einmal verweigern; Text darf weiterhin funktionieren. Aufnahme beenden, erneut starten und App während einer Aufnahme in den Hintergrund schicken.
4. Barcode eines bekannten Produkts testen, einen unbekannten Code eingeben und ohne Internet testen. Fehlende Werte müssen sichtbar bleiben.
5. Bewegung erlauben/verweigern und die Anzeige prüfen. Tageswechsel testen.
6. Rezept mit zwei Portionen anlegen und eine halbe Portion eintragen; Mengen und Makros gegenrechnen.
7. Sicherung exportieren, Eintrag ändern, Sicherung importieren und Wiederherstellung bestätigen. Ungültige JSON-Datei muss ohne Überschreiben abgewiesen werden.
8. Große Schrift, VoiceOver, Datumsauswahl und deutsche Dezimalkommas auf dem echten Gerät prüfen.

Eine grüne Konfigurationsprüfung ist keine Aussage über die Funktionsfähigkeit einer noch nicht kompilierten iPhone-App.
