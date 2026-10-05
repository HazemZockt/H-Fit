import SwiftUI
import HFitCore
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject private var store: DiaryStore
    @State private var profile = Profile()
    @State private var saved = false
    @State private var exporting = false
    @State private var importing = false
    @State private var document: BackupDocument?
    @State private var pending: Diary?
    @State private var showRestore = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Dein Plan") {
                    TextField("Dein Vorname (optional)", text: $profile.name)
                    Toggle("Ich bin mindestens 18 Jahre alt", isOn: $profile.adult)
                    if profile.adult {
                        Picker("Mein Fokus", selection: $profile.goal) { ForEach(Goal.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        HStack { Text("Kalorienrichtwert"); TextField("Optional", value: $profile.calorieTarget, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text("kcal").foregroundStyle(.secondary) }
                        HStack { Text("Eiweißrichtwert"); TextField("Optional", value: $profile.proteinTarget, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing); Text("g").foregroundStyle(.secondary) }
                        Text("0 = kein Ziel. Trage einen passenden, selbst gewählten Richtwert ein. Die App berechnet keine individuelle Diätvorgabe. Bei Schwangerschaft, Erkrankungen oder Problemen mit dem Essen bitte fachlichen Rat einholen.").font(.footnote).foregroundStyle(.secondary)
                    }
                    Button(saved ? "Gespeichert ✓" : "Plan speichern") {
                        if !profile.adult { profile.calorieTarget = 0; profile.proteinTarget = 0; profile.goal = .balance }
                        saved = store.update { $0.profile = profile }
                    }.disabled(!profile.isValid)
                }
                Section("Mehr für deinen Alltag") {
                    NavigationLink("Eigene Rezepte & Mahlzeiten") { RecipesView() }
                    if store.diary.profile.adult { NavigationLink("Essenspause messen") { FastingView() } }
                    NavigationLink("Eigene Lebensmittel") { CustomFoodsList() }
                }
                Section("Deine Daten") {
                    Text("Das Tagebuch wird in dieser App auf deinem iPhone gespeichert. Kein Konto, keine Werbung, kein Abo. Eine iPhone-Sicherung kann App-Daten enthalten. Sichere dein Tagebuch vor dem Löschen der App.").font(.subheadline)
                    Button("Sicherung exportieren") {
                        do { document = try BackupDocument(diary: store.diary); exporting = true } catch { store.error = error.localizedDescription }
                    }.disabled(store.recoveryRequired)
                    Button("Sicherung wiederherstellen") { importing = true }
                    Text("Exportierte JSON-Dateien enthalten deine Einträge unverschlüsselt. Speichere sie an einem privaten Ort.").font(.caption).foregroundStyle(.secondary)
                }
                Section("So arbeitet H-Fit") {
                    Text("Text: lokale Erkennung mit Grundnahrungsmitteln und eigenen Produkten. Keine allgemeine KI. Portions- und Nährwertschätzungen können abweichen.")
                    Text("Sprache: Apples Spracherkennung; wenn verfügbar auf dem Gerät. Sonst ist eine Verarbeitung durch Apple möglich.")
                    Text("Barcode: Eine Anfrage mit dem Produktcode geht an Open Food Facts. Dein Tagebuch wird nicht übertragen. Produktdaten können unvollständig oder fehlerhaft sein.")
                    Text("Aktivität: iPhone-Schritte über Core Motion. Keine Apple-Health-Verbindung, kein automatisch gemessener Kalorienverbrauch.")
                    Link("Open Food Facts · Daten unter ODbL", destination: URL(string: "https://world.openfoodfacts.org/terms-of-use")!)
                    Link("Orientierung zu ausgewogener Ernährung (NHS)", destination: URL(string: "https://www.nhs.uk/better-health/lose-weight/calorie-counting/")!)
                    Link("Eiweiß & Muskeltraining (ACSM)", destination: URL(string: "https://www.acsm.org/docs/default-source/files-for-resource-library/protein-intake-for-optimal-muscle-maintenance.pdf")!)
                }.font(.footnote)
                Section { Text("H-Fit 1.0 · Mit deinem Alltag wachsen.").foregroundStyle(.secondary) }
            }.navigationTitle("Mein Plan")
                .onAppear { profile = store.diary.profile }
                .onChange(of: profile.name) { _, _ in saved = false }
                .onChange(of: profile.calorieTarget) { _, _ in saved = false }
                .onChange(of: profile.proteinTarget) { _, _ in saved = false }
                .onChange(of: profile.goal) { _, _ in saved = false }
                .onChange(of: profile.adult) { _, _ in saved = false }
                .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "H-Fit-Sicherung") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                    do {
                        let url = try result.get()
                        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        guard size <= 25_000_000 else { throw DiaryError.invalidBackup }
                        let data = try Data(contentsOf: url)
                        guard data.count <= 25_000_000 else { throw DiaryError.invalidBackup }
                        let next = try JSONDecoder().decode(Diary.self, from: data); try next.validate()
                        pending = next; showRestore = true
                    } catch { store.error = "Import fehlgeschlagen: \(error.localizedDescription)" }
                }
                .confirmationDialog("Aktuelles Tagebuch durch die Sicherung ersetzen?", isPresented: $showRestore, titleVisibility: .visible) {
                    Button("Sicherung wiederherstellen", role: .destructive) { if let pending, store.restore(pending) { profile = store.diary.profile }; pending = nil }
                    Button("Abbrechen", role: .cancel) { pending = nil }
                } message: { Text("Die Sicherung enthält \(pending?.meals.count ?? 0) Essenseinträge. Eine interne Kopie deiner bisherigen Datei bleibt erhalten.") }
        }
    }
}

struct CustomFoodsList: View {
    @EnvironmentObject private var store: DiaryStore
    @State private var add = false
    var body: some View {
        List {
            Button("Lebensmittel hinzufügen", systemImage: "plus") { add = true }
            ForEach(store.diary.customFoods) { food in
                VStack(alignment: .leading) { Text(food.name); Text("\(Int(food.per100.kcal)) kcal / 100 \(food.unit)").foregroundStyle(.secondary) }
                    .swipeActions { Button("Löschen", role: .destructive) { _ = store.update { $0.customFoods.removeAll { $0.id == food.id } } } }
            }
            Text("Gespeicherte Tagebucheinträge behalten ihre ursprünglichen Nährwerte.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Meine Lebensmittel")
            .sheet(isPresented: $add) { CustomFoodView(initialName: "") { food in if store.update({ $0.customFoods.append(food) }) { add = false } } }
    }
}
