# H-Fit vom Windows-PC aufs iPhone 15

Du brauchst einen Windows-PC, dein iPhone mit iOS 17 oder neuer, ein USB-Kabel, ein kostenloses GitHub-Konto und deinen Apple-Account. Du brauchst keinen eigenen Mac. Ein GitHub-Mac baut den Code; Sideloadly signiert die fertige App mit deinem Apple-Account.

**Noch liegt keine installierbare IPA vor.** Zuerst muss der vorbereitete Build erfolgreich durchlaufen. Apple begrenzt kostenlos signierte Apps auf sieben Tage; danach erneut signieren. Sideloadly bietet automatische Erneuerung, wenn PC und Gerät erreichbar sind. Quellen: [Apple](https://developer.apple.com/support/compare-memberships/), [Sideloadly-FAQ](https://sideloadly.io/faq.html).

## 1. Quellcode auf GitHub hochladen

1. `HFit-Quellcode.zip` in einen normalen Ordner entpacken.
2. Auf [GitHub](https://github.com/new) anmelden und ein neues Repository namens `H-Fit` anlegen.
3. Für den beschriebenen kostenlosen Weg ein **öffentliches** Repository verwenden. Dadurch ist dein App-Code öffentlich. Lade keine Tagebuchsicherungen, persönlichen Daten oder Zugangsdaten hoch. Der mitgelieferte Quellcode enthält keine solchen Daten.
4. **Upload files** bzw. **Add file → Upload files** wählen. Die Inhalte des aktuellen entpackten Ordners hochladen, sodass `Package.swift`, `project.yml`, `App`, `Sources`, `Tests`, `UITests` und **`.github`** direkt in der Repository-Wurzel liegen. Nicht die ZIP-Datei hochladen und keinen zusätzlichen übergeordneten Ordner einfügen. Eine früher entpackte Kopie enthält noch die alte Version; die ZIP für Version 1.3 erneut in einen neuen Ordner entpacken.
5. Unter **Commit changes** speichern. Falls die Weboberfläche `.github` nicht übernimmt, über **Add file → Create new file** den Pfad `.github/workflows/ios-build.yml` anlegen und den Inhalt der gleichnamigen lokalen Datei hineinkopieren.

GitHubs Standard-Runner sind für öffentliche Repositories kostenlos. Private Repositories haben Freikontingente und können bei Überschreitung Kosten auslösen. Der mitgelieferte Workflow nutzt einen Standard-Mac-Runner, keine kostenpflichtigen größeren Runner. Artefakte werden nach sieben Tagen entfernt. [GitHub-Preise und Freikontingente](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

## 2. Die iPhone-Datei bauen

1. Im Repository den Reiter **Actions** öffnen; Actions gegebenenfalls aktivieren.
2. Links **iPhone-App bauen** wählen. Nach dem ersten Hochladen startet ein Lauf auf `main` oder `master` automatisch. Alternativ **Run workflow** anklicken.
3. Warten, bis Kern-Tests, iPhone-Simulator-Test und Release-Build grün sind. Der Simulator-Test prüft die Einrichtung und eine berechnete Mahlzeit; seine Screenshots liegen im zusätzlichen Testartefakt.
4. Den erfolgreichen Lauf öffnen. Unter **Artifacts** das Paket **HFit-iPhone** herunterladen.
5. Dieses Paket entpacken. Darin liegt **HFit-unsigned.ipa**.

Bei einem roten Lauf entsteht keine verlässlich installierbare Datei. Den fehlgeschlagenen Schritt öffnen und die Fehlermeldung hier in den Chat kopieren. „Unsigned“ ist beabsichtigt: Die Signierung passiert erst auf deinem PC. In GitHub werden keine Apple-Zugangsdaten benötigt.

## 3. Mit Sideloadly installieren

1. [Sideloadly für Windows](https://sideloadly.io/) von der offiziellen Website installieren. Die dort genannten Apple-Treiber bzw. iTunes-/iCloud-Voraussetzungen beachten; je nach vorhandenem Setup sind zusätzliche Apple-Komponenten nötig.
2. iPhone per USB verbinden, entsperren und die Nachfrage **Diesem Computer vertrauen** bestätigen.
3. Sideloadly öffnen, dein iPhone auswählen und `HFit-unsigned.ipa` hineinziehen.
4. Deinen Apple-Account in Sideloadly eingeben und die dort angeforderte Anmeldung durchführen. **Passwort und Bestätigungscodes niemals in diesen Chat oder ins Repository schreiben.** Sideloadly ist ein Drittanbieterprogramm; die Anmeldung erfolgt in dessen Oberfläche.
5. Installation starten. Falls verlangt, auf dem iPhone unter **Einstellungen → Datenschutz & Sicherheit → Entwicklermodus** aktivieren und den angeforderten Neustart durchführen. Der Eintrag kann erst nach dem ersten Installationsversuch erscheinen.
6. Falls „Nicht vertrauenswürdiger Entwickler“ erscheint: **Einstellungen → Allgemein → VPN und Geräteverwaltung**, deinen Entwickleraccount auswählen und vertrauen.
7. **H-Fit** auf dem Home-Bildschirm öffnen.

## 4. Die App zum ersten Mal verwenden

1. Die drei Einrichtungsschritte durchgehen: Name/Alter, Größe/Gewicht/Formel, Ziel und Alltagsbewegung. Die Vorschau zeigt deinen geschätzten Plan. Automatische Richtwerte sind abschaltbar; fehlende Körperdaten verhindern die Berechnung, nicht die Nutzung des Tagebuchs. Spätere Änderungen unter **Mein Plan → Profil und Berechnung bearbeiten**.
2. Auf **Heute → Was hast du gegessen?** tippen. Beispiel: `Heute um 8 Uhr 60 g Haferflocken mit 200 ml Milch und eine Banane`.
3. **Mahlzeit erkennen** wählen. Zeitpunkt, Lebensmittel und Mengen prüfen, dann speichern. Die Beispielmenge ergibt mit den eingebauten Richtwerten etwa **424 kcal**.
4. Für Diktat **Mahlzeit diktieren** antippen; Mikrofon und Sprache nur bei Bedarf freigeben. Text funktioniert auch ohne diese Freigaben.
5. Barcode: **Lebensmittel selbst eingeben → Lebensmittel auswählen / ändern → Barcode scannen / eingeben**. Nach Übernahme Menge und Einheit prüfen.
6. Unter **Bewegung** die Bewegungsdaten freigeben, um deine iPhone-Schritte zu sehen.
7. Unter **Mein Plan → Eigene Rezepte & Mahlzeiten** häufige Gerichte speichern und später portionsweise erfassen.

## 5. KI mit deinem Windows-PC verbinden

1. Am PC `Start-HFit-KI.cmd` öffnen. Es startet den H-Fit-Dienst und das bereits installierte Ollama. Bei „KI bereit“ kannst du das Startfenster schließen; der Dienst bleibt im Hintergrund. Nach einem PC-Neustart erneut starten.
2. PC und iPhone im selben WLAN lassen. Der PC muss für KI-Antworten eingeschaltet bleiben.
3. Auf dem PC `companion/.local/pairing.html` öffnen. Die Seite enthält deinen privaten QR-Code; nicht teilen und nicht auf GitHub hochladen.
4. In H-Fit unter **Assistent → PC verbinden → QR-Code scannen** koppeln. Kamera und lokales Netzwerk auf dem iPhone erlauben. Alternativ den Kopplungscode einfügen.
5. Im Chat beispielsweise „Ich habe 60 g Haferflocken und 200 ml Milch gegessen“ schreiben. Unter **Mengen und Produkte prüfen** kontrollieren und ausdrücklich bestätigen. Fehlende Angaben werden nicht automatisch ergänzt.

Die lokale Firewall-Regel wurde auf diesem PC für TCP 8787 und das lokale Subnetz eingerichtet. Keine Routerfreigabe erforderlich. Bei geänderter PC-IP ist eine neue Kopplung nötig. Verbindung und Regel können später entfernt werden; vorhandenes Ollama und Tagebuch müssen dafür nicht gelöscht werden.
8. Ab und zu **Sicherung exportieren** nutzen, besonders vor einer Neuinstallation oder einem Gerätewechsel.
9. Unter **Assistent** z. B. „Wie ist meine Bilanz heute?“ fragen. Die Antwort wird aus deinen Daten berechnet. Für beliebige KI-Beratung ist kein Modell verbunden.

## 5. Nach sieben Tagen erneuern

Die App vor Ablauf erneut mit derselben Apple-ID und Bundle-ID signieren. **Nicht vorher löschen**, sonst können lokale Einträge verloren gehen. Sideloadlys automatische Erneuerung lässt sich aktivieren; dazu müssen dessen Hintergrunddienst und die Geräteverbindung funktionieren. Für WLAN-Erneuerung die offizielle [Sideloadly-Anleitung](https://sideloadly.io/faq.html) beachten. Kostenlose Apple-Accounts haben außerdem Grenzen für gleichzeitig installierte Apps.

Der Quellcode allein reicht nicht zur Installation: **Erst grüner GitHub-Build, dann IPA herunterladen, dann signieren.** Ein dauerhaft gültiges, kostenloses Apple-Zertifikat wird hier nicht versprochen.
