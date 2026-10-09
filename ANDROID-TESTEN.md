# H-Fit als APK testen

Die fertige Datei heißt **HFit-Android-Test.apk**. Sie ist kompiliert und mit einem lokalen Testschlüssel signiert. Dafür brauchst du keinen GitHub-Build, Apple-Account oder Mac.

**Version 1.3-test:** Einrichtung mit optionaler Formel-Auswahl, automatischer Kalorien-/Makroschätzung und Planvorschau. Bei bereits eingerichteter App unter **Mein Plan → Profil bearbeiten** Größe, Gewicht und Formel ergänzen. Der Tagesrest und das Eiweißziel werden berechnet; neue Gewichtseinträge aktualisieren die Schätzung. Geänderte Mengen rechnen jetzt bereits in der Mahlzeitenvorschau live nach. Wasser aus dem Tagebuch zählt in der Wasserkarte mit.

Im **Chat** wertet **Lokal auswerten** Fragen zu Kalorien, Eiweiß, Wasser, Bewegung und Wochendurchschnitt aus dem Tagebuch aus. **Frage vormerken** bleibt für spätere KI-Fragen erhalten. Kein KI-Modell ist verbunden und nichts wird an einen KI-Anbieter gesendet. Antworten sind lokale, regelbasierte Auswertungen zum Fragezeitpunkt. Entwürfe, Fragen und Antworten bleiben lokal und werden exportiert.

**Version 1.1-test:** Neue Einrichtung ohne Login in drei kurzen Schritten: Name und Alter, optionale Größe und Gewicht, Ziel und Alltagsbewegung. Die Einrichtung erscheint beim ersten Start sowie einmalig nach dem Update einer älteren Version. Bereits gespeicherte Einträge bleiben erhalten. Unter **Mein Plan → Profil bearbeiten** lassen sich die Angaben später ändern. Der Abschluss bleibt nach einem Neustart gespeichert.

Die APK verwendet dieselbe Paketkennung und denselben Testschlüssel wie Version 1.0. Installiere sie als **Update über die vorhandene App**, ohne diese vorher zu deinstallieren. Größe und Gewicht sind optional. Ein erstmals eingetragenes Gewicht wird bei leerem Gewichtsverlauf übernommen. Für unter 18-Jährige bleiben Abnehmziele, Kalorienrichtwerte und Essenspausen deaktiviert.

Die APK läuft **nicht auf dem iPhone**. Dafür braucht es den separaten SwiftUI-Code und eine IPA, siehe `INSTALLIEREN.md`. Einrichtung, Berechnung und lokaler Assistent sind jetzt auch im iPhone-Quellcode enthalten; dieser muss noch auf GitHub kompiliert und getestet werden.

## Installation im Emulator

1. Deinen Android-Emulator starten.
2. `HFit-Android-Test.apk` in das Emulatorfenster ziehen. Falls dein Emulator Drag-and-drop nicht unterstützt, dessen **APK installieren / Install APK**-Schaltfläche verwenden und die Datei auswählen.
3. Nach der Installation **H-Fit** öffnen.

Voraussetzung: **Android 8 oder neuer und ein aktuelles Android System WebView**. Das Paket enthält keine architekturabhängigen nativen Bibliotheken und kann daher auf ARM-, ARM64- und x86-/x86_64-Systemen laufen.

Alternativ mit Android Debug Bridge:

```powershell
adb install -r "HFit-Android-Test.apk"
adb shell am start -n de.hfit.android/.MainActivity
```

Bei mehreren verbundenen Geräten `adb -s DEINE_EMULATOR_ID install -r ...` verwenden. `adb devices` zeigt die IDs.

## Schnell ausprobieren

Zuerst die drei Einrichtungsschritte durchgehen. Kein Konto und keine E-Mail-Adresse. Zum Gegenprüfen: 30 Jahre, 180 cm, 80 kg, männliche Formel, regelmäßige Alltagsbewegung und „Fit bleiben“ ergeben einen geschätzten Richtwert von **2.670 kcal und 96 g Eiweiß**. Das ist eine Berechnungsprobe, keine Empfehlung für dich. Die Formel und ihre Grenzen sind unter **Mein Plan → Wie wird mein Bedarf berechnet?** erklärt.

1. **Was hast du gegessen? → Beispiel einsetzen → Erkennen**.
2. Drei Lebensmittel sollten erscheinen: 60 g Haferflocken, 200 ml Milch, eine Banane mit geschätzten 120 g.
3. Mengen und Zeitpunkt prüfen, dann speichern. Ergebnis: ungefähr **424 kcal**.
4. Einen Eintrag antippen und die Menge ändern. Danach die App schließen und erneut öffnen: Die Daten sollen erhalten bleiben.
5. Wasser mit den Schnellbuttons hinzufügen. Unter **Verlauf** Gewicht eintragen; unter **Mein Plan** eigene Rezepte erstellen.

## Was diese Android-Version enthält

Text-Erkennung, Android-Spracheingabe, Kalorien und Makros, eigene Lebensmittel, Produktabfrage über eingegebene Barcode-Ziffern, eigene Rezepte mit Portionsberechnung, Wasser, Gewicht, Trainingsprotokoll, Schrittanzeige oder manuelle Schritte, Verlauf, Ziele, Essenspausen-Timer und JSON-Sicherungen.

Es handelt sich um eine eigenständige **Android-Testversion mit lokaler WebView-Oberfläche und nativen Android-Anbindungen**, nicht um eine automatische Umwandlung des SwiftUI-Projekts. Die iPhone-Quellen bleiben erhalten. Android- und iPhone-Sicherungen haben unterschiedliche Formate und sind noch nicht austauschbar.

- **Sprache:** Benötigt einen installierten Android-Sprachdienst. Manche Emulatoren ohne Google-Dienste bieten keinen an. Dann erscheint ein Hinweis und Texteingabe funktioniert weiter. Sprachverarbeitung kann online erfolgen.
- **Schritte:** Viele Emulatoren haben keinen Schrittsensor. Zum Testen unter **Bewegung → Manuell** einen Tageswert eingeben. Auf Geräten mit Sensor werden Schritte seit der Sensorverbindung erfasst, keine rückwirkenden Tagesdaten. Manuelle Tageswerte haben Vorrang.
- **Barcode:** Ziffern eintippen; die kostenlose Produktsuche verwendet Open Food Facts. Diese APK hat noch keinen Kamerascanner. Internet ist nur für die Produktsuche und gegebenenfalls den Sprachdienst nötig.
- **Erkennung:** Begrenzter Offline-Erkenner mit 67 Grundnahrungsmitteln und eigenen Produkten, keine allgemeine KI oder Fotoerkennung. Unbekannte Lebensmittel müssen ergänzt werden.
- **Speicherung:** Lokal im App-Speicher. Deinstallation kann Daten löschen; vorher unter **Mein Plan** exportieren. Sicherungsdateien enthalten deine Einträge unverschlüsselt.

## Was geprüft wurde

- Java-Kompilierung, Android-Ressourcen, DEX-Erzeugung und APK-Verpackung erfolgreich.
- APK-Signatur mit Android `apksigner` überprüft: v2 und v3 gültig.
- **29 Logiktests bestanden**, unter anderem deutsche Mengen und Uhrzeiten, Summen, unbekannte Lebensmittel, Rezeptberechnung, Sicherungsvalidierung, Einrichtung, Bedarfsschätzungen und lokale Chatantworten.
- Chat im Browser geprüft: Entwurf und Verlauf nach Neustart, Migration alter Daten, fehlgeschlagenes Speichern, Bearbeiten, Löschen und Abbrechen, Eingabevalidierung, HTML-Escaping und keine externen Anfragen. Es wurden keine echten KI-Antworten simuliert oder angezeigt.
- Einrichtung im Browser geprüft: Pflichtfelder, optionale Körperangaben, Zurücknavigation, fehlgeschlagenes Speichern, Neustart, Profiländerung und Abbrechen, Minderjährigen-Regeln, Übernahme alter Tagebücher sowie Darstellung bei 320, 390 und 800 Pixel Breite.
- Neuer durchgehender Browsertest: Einrichtung mit 2.670-/2.400-kcal-Vorschau, Mengenänderung 100 → 50 g Haferflocken mit 372 → 186 kcal, aktualisierte Tagesbilanz, lokale Antwort mit 186 kcal und Neustart.
- Browserprüfung der Oberfläche auf schmalem und breitem Bildschirm: Erfassung, Speicherung und Wiederladen, Bearbeiten, Wasser, Schritte, Gewicht, Profil, Rezepte und Barcode-Ergebnisübernahme; keine JavaScript-Laufzeitfehler. Android-Dienste waren in diesen Browserprüfungen simuliert.
- **Noch nicht im Android-Emulator gestartet**, weil während des Builds keiner verbunden war. Echte Sprachdienste, Sensoren, Dateidialoge und Live-Produktabfragen benötigen den Gerätetest.

## Quellcode und erneutes Bauen

Der Android-Code liegt im Ordner `android`. `assets` enthält die lokale Oberfläche und Berechnungslogik, `src/de/hfit/android/MainActivity.java` die Android-Anbindungen. `tools/setup.py` lädt JDK und SDK in den lokalen, ignorierten Ordner `.toolchain`. `tools/build.py` kompiliert und signiert die APK. Für Updates den lokalen Testschlüssel behalten, damit eine Installation mit `-r` möglich bleibt.

Der Schlüssel ist ausschließlich für diese lokale Test-App gedacht. Er wird nicht in das Quellcode-ZIP aufgenommen. Keine Emulator- oder Systemeinstellungen wurden verändert; es wurde lediglich ADB zum Prüfen verbundener Geräte gestartet.
