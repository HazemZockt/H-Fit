import SwiftUI
import HFitCore

struct SetupView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    let editing: Bool
    @State private var step = 0
    @State private var name: String
    @State private var age: String
    @State private var height: String
    @State private var weight: String
    @State private var sex: FormulaSex
    @State private var activity: ActivityLevel
    @State private var goal: Goal
    @State private var automatic: Bool
    @State private var loaded = false
    @State private var restore = false
    init(profile: Profile = Profile(), editing: Bool = false) {
        self.editing = editing
        _name = State(initialValue: profile.name)
        _age = State(initialValue: profile.setup.map { String($0.age) } ?? "")
        _height = State(initialValue: profile.setup?.height.map { String($0) } ?? "")
        _weight = State(initialValue: profile.setup?.weight.map { String($0) } ?? "")
        _sex = State(initialValue: profile.setup?.sex ?? .unspecified)
        _activity = State(initialValue: profile.setup?.activity ?? .low)
        _goal = State(initialValue: profile.goal)
        _automatic = State(initialValue: profile.setup?.automatic ?? true)
    }
    private func number(_ text: String) -> Double? { Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) }
    private var adult: Bool { (Int(age) ?? 0) >= 18 }
    private var setup: SetupProfile {
        SetupProfile(age: Int(age) ?? 0, height: number(height), weight: number(weight), sex: sex, activity: activity, automatic: adult && automatic)
    }
    private var preview: Profile {
        var p = Profile(); p.name = name; p.adult = adult; p.goal = adult ? goal : .balance; p.setup = setup; return p
    }
    private var valid: Bool {
        if step == 0 { return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80 && (Int(age).map { (1...120).contains($0) } ?? false) }
        if step == 1 { return setup.isValid && (height.isEmpty || number(height) != nil) && (weight.isEmpty || number(weight) != nil) }
        return setup.isValid
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Text("H·FIT").font(.title.bold()).foregroundStyle(Palette.lime); Spacer(); Text("OHNE KONTO").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                    ProgressView(value: Double(step + 1), total: 3)
                    Text("SCHRITT \(step + 1) VON 3").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(Palette.lime)
                    Text(["Schön, dass du da bist.", "Dein Ausgangspunkt.", "Dein Plan für den Alltag."][step]).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    if step == 0 { basics }
                    else if step == 1 { bodyDetails }
                    else { planDetails }
                    HStack {
                        if step > 0 { Button("Zurück") { step -= 1 }.buttonStyle(.bordered) }
                        Spacer()
                        Button(step == 2 ? (editing ? "Plan speichern" : "Los geht’s") : "Weiter") {
                            if step < 2 { step += 1 }
                            else { save() }
                        }.buttonStyle(.borderedProminent).foregroundStyle(Palette.background).controlSize(.large).disabled(!valid).accessibilityIdentifier("setup-next")
                    }
                    Text("Deine Angaben bleiben auf deinem Gerät. Du kannst sie unter Mein Plan jederzeit ändern.").font(.footnote).foregroundStyle(.secondary)
                    if !editing && step == 0 { Button("Vorhandene Sicherung wiederherstellen") { restore = true } }
                }.padding(24)
            }.background(Palette.background)
                .toolbar { if editing { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } } }
                .sheet(isPresented: $restore) { ProfileView() }
                .onAppear {
                    guard !loaded else { return }; loaded = true
                    if let current = store.diary.currentWeight() { weight = String(current) }
                }
        }
    }
    private var basics: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                Text("Wie dürfen wir dich nennen?").font(.headline)
                TextField("Name oder Spitzname", text: $name).textContentType(.givenName).textFieldStyle(.roundedBorder).accessibilityIdentifier("setup-name")
                Text("Wie alt bist du?").font(.headline)
                TextField("Alter in Jahren", text: $age).keyboardType(.numberPad).textFieldStyle(.roundedBorder).accessibilityIdentifier("setup-age")
                Text("Kein Login, keine E-Mail. Für unter 18-Jährige richten wir keine Kalorien- oder Abnehmziele ein.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
    private var bodyDetails: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                labeledField("Größe in cm · optional", text: $height, id: "setup-height")
                labeledField("Gewicht in kg · optional", text: $weight, id: "setup-weight")
                if adult {
                    Picker("Formel für den Energiebedarf", selection: $sex) { ForEach(FormulaSex.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("setup-sex")
                    Text("Die veröffentlichte Formel unterscheidet weiblich und männlich. Ohne Auswahl bleibt die automatische Berechnung aus.").font(.footnote).foregroundStyle(.secondary)
                }
                if !valid { Text("Bitte Größe (80–250 cm) und Gewicht (20–500 kg) prüfen oder die Felder leer lassen.").font(.footnote).foregroundStyle(.orange) }
            }
        }
    }
    private var planDetails: some View {
        VStack(spacing: 18) {
            Card {
                VStack(alignment: .leading, spacing: 18) {
                    if adult { Picker("Dein Ziel", selection: $goal) { ForEach(Goal.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
                    else { Text("Fit bleiben und Spaß an Bewegung finden.").font(.headline) }
                    Picker("Alltagsbewegung", selection: $activity) { ForEach(ActivityLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("setup-activity")
                    Text("Wähle deinen üblichen Alltag einschließlich Sport. So wird Bewegung nicht doppelt gezählt.").font(.footnote).foregroundStyle(.secondary)
                    if adult {
                        Toggle("Kalorien und Makros berechnen", isOn: $automatic)
                        Text("Für gesunde Erwachsene; nicht bei Schwangerschaft, Stillzeit oder Erkrankungen mit besonderen Ernährungsanforderungen. Dann bitte ausschalten und fachlich abgestimmte Richtwerte verwenden.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            Card {
                if let plan = Planning.estimate(preview) {
                    Text("DEIN STARTPUNKT").font(.caption.weight(.semibold)).foregroundStyle(Palette.lime)
                    Text("≈ \(Int(plan.calories)) kcal / Tag").font(.title.bold()).padding(.vertical, 8)
                    Text("\(Int(plan.protein)) g Eiweiß · \(Int(plan.carbs)) g Kohlenhydrate · \(Int(plan.fat)) g Fett")
                    Text("Eine Schätzung, kein exakt gemessener Bedarf. Neue Gewichtseinträge aktualisieren den Richtwert. Details findest du unter Mein Plan.").font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                } else { Text(Planning.unavailableReason(preview)).foregroundStyle(.secondary) }
            }
        }
    }
    private func labeledField(_ label: String, text: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(label).font(.headline); TextField(label, text: text).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).accessibilityIdentifier(id) }
    }
    private func save() {
        do {
            let next = try Planning.complete(store.diary, name: name, setup: setup, goal: goal)
            if store.update({ $0 = next }), editing { dismiss() }
        } catch { store.error = "Bitte prüfe deine Profilangaben." }
    }
}
