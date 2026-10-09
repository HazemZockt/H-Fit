# Prüfstatus

Stand: 9. Oktober 2026. Entwicklungsumgebung: Windows.

## Version 1.4 – aktueller Zusatz

- Wochen-/Monatsumschaltung, Monatsnavigation und Tagesringe in Android und iOS ergänzt. Ringe vergleichen Kalorien (70 %) und Eiweiß (30 %) mit den Zieleinstellungen, keine Gesundheitsbewertung. Unvollständige Tage, fehlende Ziele und Minderjährige erhalten keine Bewertung. Vollständig-Markierungen werden lokal gespeichert und mit exportiert.
- Android-APK Version 1.4-test (Versioncode 5) gebaut und Signaturen v2/v3 geprüft. 30 Logiktests und alle vier Browser-Testprogramme bestanden, einschließlich Monatswechsel, Ringanzeige, Speicherung/Neuladen, Rückkehr zur Woche und schmaler Darstellung. Native Android-Dienste sind in Browserprüfungen nachgebildet; kein Emulator-/Gerätetest.
- iOS: neue Monatsansicht und zusätzlicher Kerntest vorbereitet; weiterhin kein erfolgreicher Xcode-Build und keine fertige IPA.
- Lokale PC-KI mit Ollama, HTTPS, Kopplungsschlüssel und Zertifikatprüfung implementiert. iOS-Verbindung und Bestätigungsansicht für Mahlzeiten im Code ergänzt. Android verwendet weiterhin den lokalen regelbasierten Assistenten.
- PC-KI wurde mit synthetischen Mahlzeiten und Rückfragen geprüft. Nährwerte werden aus Lebensmittel-Daten berechnet; Modellschätzungen werden nicht als Nährwertquelle übernommen. Freie KI-Antworten können weiterhin falsch sein.
- WLAN-Freigabe eingerichtet und geprüft: TCP 8787, lokale PC-Adresse, ausschließlich LocalSubnet, auf den Python-Dienst beschränkt. Einrichtung über vorhandene PowerShell 7 mit Administratorrechten; keine Ausführungsrichtlinie geändert. GitHub CLI ist angemeldet, iOS-Build wird nun ausgeführt. Ein echter iPhone-Test steht noch aus.
- Direkte Tagesbilanz-, Bedarfs-, Wochen- und Eiweißfragen verwenden auch bei verbundener KI die deterministische App-Berechnung. Freie KI-Antworten bleiben fehleranfällig. Zusätzliche Swift-Tests für Kopplung und Rechenrouting vorbereitet.

Die folgenden Angaben dokumentieren den vorherigen Stand 1.3.

## Version 1.3 – tatsächlicher Stand

- Android: `HFit-Android-Test.apk` neu gebaut (Versioncode 4), Signaturen v2/v3 gültig. 29 Logiktests sowie vier Browser-Testprogramme bestanden. Die neue Einrichtung mit Bedarfsvorschau, live geänderte Mengen, Tagesrest und berechnete lokale Chatantworten wurden geprüft. Noch kein Test auf einem Android-Gerät/Emulator.
- iPhone: Einrichtung, Profil-/Bedarfsberechnung, Makroplan, Tagesrest, Wasser aus Mahlzeiten und lokaler Assistent im Swift-Code ergänzt. Altdaten bleiben über optionale neue Felder lesbar. **Noch nicht kompiliert oder ausgeführt.**
- Für GitHub vorbereitet: 23 Swift-Kerntests und ein nativer UI-Test für Einrichtung, Tagesrichtwert, Mahlzeit und Assistent. Erst ein erfolgreicher Workflow erzeugt eine IPA. Xcode-/Swift-Tests auf Windows nicht ausführbar.
- GitHub-Upload/IPA sind derzeit nicht abgeschlossen: In diesem Chat ist kein nutzbarer GitHub-Connector verfügbar; CLI-Geräteanmeldung benötigt noch den Kontoinhaber. Die browserseitige GitHub-Anmeldung wurde durch eine Zugriffssperre blockiert.
- Im Projekt liegt zusätzlich eine ältere, zuvor entpackte Kopie `HFit-Quellcode/`. Sie bleibt erhalten, wird aber nicht in das neue Repository oder die aktuellen Quellcode-Archive aufgenommen.

## Lokal überprüft

- Projektdateien, Info.plist und vier erforderliche Datenschutzbeschreibungen.
- XcodeGen-Konfiguration, lokales Swift-Paket, GitHub-Buildfolge und IPA-Paketpfad.
- App-Icon als 1024 × 1024 RGB-PNG und Asset-Verweise.
- Manuelle Durchsicht der Eingabe-, Validierungs-, Sicherungs- und Fehlerpfade.

## Noch nicht verifiziert

- **Swift-Kompilierung, XCTest-Ausführung, Xcode-Build und App-Start.** Swift/Xcode fehlen hier. Die 23 Kern-Tests und der UI-Test sind vorbereitet, nicht lokal bestanden.
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
