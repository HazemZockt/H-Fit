# H-Fit für dein iPhone

Eine native, deutschsprachige SwiftUI-App für iPhone 15 und andere iPhones ab iOS 17. Die Bedienung und Funktionen orientieren sich an einem klassischen Ernährungstagebuch wie YAZIO. Oberfläche, Code und enthaltene Grunddaten sind eigenständig; YAZIO-Code, dessen Produktdatenbank, Bilder und Rezepttexte werden nicht verwendet.

**Status:** Quellcode und Build-Workflow sind vorbereitet. Noch keine kompilierte oder auf einem iPhone geprüfte Version. Auf diesem Windows-Rechner stehen Xcode und ein iOS-Simulator nicht zur Verfügung. Eine installierbare IPA entsteht erst nach einem erfolgreichen GitHub-Actions-Build. Die Gerätefunktionen brauchen anschließend einen Test auf deinem iPhone.

## Was im Code enthalten ist

- Mahlzeiten auf Deutsch schreiben oder diktieren; vor dem Speichern Mengen und Zeitpunkt prüfen.
- Lokale Erkennung von über 60 Grundnahrungsmitteln sowie eigenen Produkten, mit Gramm, Millilitern, Stückzahlen, Dezimalkomma, „gestern“ und Uhrzeiten.
- Kalorien, Eiweiß, Kohlenhydrate und Fett automatisch aus den bestätigten Mengen berechnen.
- Unbekannte oder mehrdeutige Lebensmittel markieren und manuell auflösen, statt Nährwerte zu erfinden.
- Barcode mit der Kamera scannen oder Ziffern eingeben; Produktdaten von Open Food Facts übernehmen.
- Eigene Lebensmittel mit Verpackungsangaben speichern und später per Text wiedererkennen.
- Eigene Rezepte mit Zutaten, Zubereitung und Portionsberechnung erstellen und ins Tagebuch eintragen; Zutatenliste teilen.
- Wasser zählen, Gewicht protokollieren, 7-Tage-Kaloriengrafik und Gewichtsverlauf ansehen.
- iPhone-Schritte und Distanz nach Freigabe aus Core Motion lesen; Training mit Dauer eintragen.
- Ziele „Fit bleiben“, „Abnehmen“ und „Muskeln aufbauen“, optionale eigene Richtwerte und allgemeine Hinweise.
- Optionaler Essenspausen-Timer für Erwachsene. Keine vorgeschriebene Fastendauer, keine Fasten-Benachrichtigungen.
- Tagebuch bearbeiten und löschen, lokal speichern, JSON-Sicherung exportieren und mit Bestätigung wiederherstellen.

## Bewusste Grenzen dieser Version

Dies ist ein erster eigenständiger Funktionsumfang, keine vollständige Kopie aller YAZIO- und YAZIO-Pro-Funktionen.

Die Texteingabe nutzt einen begrenzten Offline-Erkenner, kein Sprachmodell. Unbekannte Gerichte, beliebige Formulierungen oder Fotos lassen sich nicht zuverlässig automatisch analysieren. Grundnährwerte und Standardportionen sind grobe Richtwerte. Öl, Soßen und Zubereitung müssen berücksichtigt werden. Reis und Nudeln sind standardmäßig gekocht; für Rohgewicht explizit „Reis trocken“ bzw. „Nudeln trocken“ angeben. Essenszeiten werden auf einen gemeinsamen Zeitpunkt pro Eingabe gesetzt; mehrere Zeiten bitte getrennt erfassen.

Es gibt **keine KI-Fotoanalyse, allgemeine KI-Beratung, fertige Rezeptbibliothek, Apple-Health-/Watch-Synchronisierung, Cloud-Synchronisierung, automatisch gemessenen Kalorienverbrauch oder Berechnung eines persönlichen Kalorienbedarfs**. Schritte werden nicht in Essenskalorien umgerechnet. Wasserbuttons zählen separat und übernehmen Getränke aus dem Tagebuch nicht automatisch. Eigene Kalorien-/Eiweißrichtwerte sind optional und nur nach Bestätigung der Volljährigkeit sichtbar.

Sprache verwendet Apples Speech-Framework. Wenn lokale Erkennung verfügbar ist, wird sie verwendet; sonst kann Apple Sprache online verarbeiten. Barcodeabfragen brauchen Internet; sonst funktioniert das Tagebuch lokal. Die App hat weder Abonnement noch eingebauten Bezahldienst.

## Auf Windows starten

Öffne **[INSTALLIEREN.md](INSTALLIEREN.md)**. Dort steht der Weg vom Quellcode zum kostenlosen GitHub-Build und zur Installation mit Sideloadly. **HFit-Quellcode.zip ist Quellcode, keine installierbare IPA.** Es sind keine Zugangsdaten und kein Apple-Entwicklerzertifikat enthalten.

## Entwickeln und prüfen

Auf einem Mac mit Xcode und XcodeGen:

```sh
swift test
xcodegen generate
xcodebuild -project HFit.xcodeproj -scheme HFit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

Die Projektdatei wird aus `project.yml` erzeugt. `Package.swift` enthält den plattformunabhängigen Kern und 13 XCTest-Fälle für Mengen, Zeiten, mehrdeutige Lebensmittel, Nährwertsummen, Rezeptportionen und Sicherungsvalidierung. `App/` enthält SwiftUI, Spracherkennung, Schrittzählung und Barcodeerfassung. Der GitHub-Workflow führt die Tests vor dem iOS-Build aus und erzeugt dann `HFit-unsigned.ipa`.

Für die lokale Konfigurationsprüfung auf Windows optional Python mit Pillow und PyYAML verwenden:

```sh
python scripts/check_project.py
```

Diese Prüfung kontrolliert Dateiinventar, XML, YAML, Ressourcen und Berechtigungsbeschreibungen. Sie ersetzt weder Swift-Kompilierung noch Gerätetests. Den tatsächlichen Prüfstand dokumentiert [PRUEFSTATUS.md](PRUEFSTATUS.md).

## Datenschutz und Datenhaltung

Einträge liegen unter Application Support im App-Sandbox-Verzeichnis. Änderungen werden validiert und atomar gespeichert, mit iOS-Dateischutz bis zur ersten Entsperrung nach Neustart. iOS-Gerätesicherungen können diese Daten einschließen. Die App hat keinen eigenen Server, keine Werbung und keine Analytik. Beim Löschen der App können lokale Einträge verloren gehen; vorher exportieren. Für eine Erneuerung dieselbe Apple-ID und Bundle-ID verwenden und die App nicht vorher löschen.

Exportdateien enthalten persönliche Einträge unverschlüsselt. Beim Import werden Inhalt und Größenlimits geprüft; vor dem Ersetzen wird eine interne Kopie der vorhandenen Datei angelegt. Bei beschädigten Daten werden neue Schreibvorgänge gesperrt, damit nichts unbemerkt überschrieben wird. Eine gültige Sicherung kann dann importiert werden.

Kameraaufnahmen für Barcodes werden nicht hochgeladen. Open Food Facts erhält den abgefragten Barcode, die IP-Adresse und einen App-User-Agent, nicht dein Tagebuch. Produktdaten können falsch oder unvollständig sein. Übernommene Produkte bleiben lokal verfügbar.

## Quellen und Daten

- [YAZIO-Funktionsübersicht](https://help.yazio.com/hc/de/articles/11804776635281-Anleitung-zur-Yazio-App): Funktionsvorbild, keine Übernahme von Code oder Inhalten.
- [Open Food Facts](https://world.openfoodfacts.org/terms-of-use): Produktdaten unter ODbL, einzelne Dateninhalte unter Database Contents License. In der App sichtbar zugeordnet. Die unterstützte API v2 wird isoliert in `FoodLookup` verwendet; Migration auf v3 ist bei Änderungen der API möglich. Vor einer öffentlichen Verbreitung des Projekts die [API-Nutzungsregistrierung](https://openfoodfacts.github.io/openfoodfacts-server/api/) mit eigenen Kontaktangaben durchführen.
- [Apple Core Motion](https://developer.apple.com/documentation/coremotion/cmpedometer): Schritte und Strecke.
- [Apple Speech](https://developer.apple.com/documentation/speech): Spracheingabe.
- [NHS: Kalorien und ausgewogene Ernährung](https://www.nhs.uk/better-health/lose-weight/calorie-counting/), [ACSM: Eiweiß und Muskeltraining](https://www.acsm.org/docs/default-source/files-for-resource-library/protein-intake-for-optimal-muscle-maintenance.pdf): Hintergrund allgemeiner Hinweise, keine individuellen Therapieempfehlungen.

Die kleine eingebaute Lebensmittelliste besteht aus gerundeten generischen Schätzwerten und ist keine geprüfte Produktdatenbank. Nährwerte auf der jeweiligen Verpackung haben Vorrang.
