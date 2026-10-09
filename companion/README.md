# Lokale H-Fit-KI

Der Dienst verwendet ein bereits lokal installiertes Ollama-Modell (hier qwen3.5:4b). Die iPhone-App schickt Fragen und ausgewählte Tagebuchdaten über HTTPS an den eigenen PC. Bei einer Produktsuche erhält Open Food Facts den Suchbegriff. Keine öffentliche Internetfreigabe erforderlich.

Die Einrichtung erzeugt unter `.local` ein Zertifikat, den privaten Schlüssel und einen zufälligen Kopplungsschlüssel. Diese Dateien dürfen nicht auf GitHub hochgeladen oder öffentlich geteilt werden. `setup.py` benötigt Python, cryptography und qrcode; der eigentliche Dienst nutzt die Python-Standardbibliothek. Der Lebensmittelkatalog liegt unter `android/assets/catalog.js` und ist im Quellcodearchiv enthalten.

Nach der Einrichtung startet `Start-HFit-KI.cmd` den Dienst ohne dauerhaftes Konsolenfenster. Der PC muss eingeschaltet sein und mit dem iPhone im selben lokalen Netz bleiben. Es wurde kein automatischer Windows-Start eingerichtet.

In der iPhone-App unter Assistent → PC verbinden den QR-Code aus `.local/pairing.html` scannen oder den Kopplungscode einfügen. Kein systemweites Vertrauen für ein selbstsigniertes Zertifikat nötig: Die App prüft den Fingerabdruck direkt. Nach einem Wechsel der PC-IP muss die Kopplung neu erstellt werden.

`Enable-WLAN.ps1` richtet mit Administratorrechten ausschließlich die H-Fit-Regel für TCP 8787 und das lokale Subnetz ein. Auf dem aktuellen PC wurde diese Regel über PowerShell 7 eingerichtet und geprüft. Sicherheitsrichtlinien wurden nicht geändert.

Die KI schlägt Mahlzeiten vor; erst die Bestätigung in der App speichert sie. Fehlende Mengen oder unbekannte Produkte müssen ergänzt werden. Die KI kennt nicht jedes Lebensmittel und ihre freien Antworten können Fehler enthalten.

Zum späteren Entfernen ist `Remove-HFit-KI.ps1` vorbereitet: beendet ausschließlich den H-Fit-Dienst, entfernt seine Firewall-Regel und lokale Kopplungsdateien. Das bereits vorhandene Ollama und das Tagebuch bleiben erhalten. Noch nicht ausgeführt. In der App kann die Verbindung ebenfalls getrennt werden.
