import SwiftUI
import HFitCore

struct CaptureView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @StateObject private var speech = SpeechService()
    @State private var text = ""
    @State private var speechPrefix = ""
    @State private var result: ParseResult?
    @State private var notice: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Erzähl von deiner Mahlzeit.").font(.largeTitle.bold())
                    Text("Zum Beispiel: „Gestern um 19 Uhr 200 g Reis und 150 g Hähnchen.“").foregroundStyle(.secondary)
                    TextEditor(text: $text).frame(minHeight: 150).padding(12).scrollContentBackground(.hidden).background(Palette.card, in: RoundedRectangle(cornerRadius: 20)).accessibilityLabel("Deine Mahlzeit")
                    Button {
                        if speech.recording { speech.stop() }
                        else { speechPrefix = text.isEmpty ? "" : text + " "; Task { await speech.start() } }
                    } label: {
                        Label(speech.recording ? "Aufnahme beenden" : "Mahlzeit diktieren", systemImage: speech.recording ? "stop.circle.fill" : "mic.fill").frame(maxWidth: .infinity).padding(8)
                    }.buttonStyle(.bordered).disabled(speech.requesting)
                    if speech.recording { Text("Ich höre zu … maximal 50 Sekunden.").foregroundStyle(Palette.lime) }
                    if let message = speech.message { Text(message).foregroundStyle(.orange) }
                    Text("Wenn verfügbar, erkennt das iPhone Sprache lokal. Andernfalls kann Apples Spracherkennung eine Internetverbindung nutzen.").font(.caption).foregroundStyle(.secondary)
                    Button("Mahlzeit erkennen") {
                        speech.stop()
                        let parsed = MealParser.parse(text, customFoods: store.diary.customFoods)
                        if parsed.items.isEmpty { notice = "Bitte beschreibe mindestens ein Lebensmittel." }
                        else { result = parsed }
                    }.buttonStyle(.borderedProminent).foregroundStyle(Palette.background).controlSize(.large).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || speech.requesting)
                    if let notice { Text(notice).foregroundStyle(.orange) }
                    Text("Der Offline-Erkenner kennt \(FoodCatalog.foods.count) Grundnahrungsmittel und deine eigenen Produkte. Trenne Lebensmittel mit „und“ oder einem Komma. Öl, Soßen und Getränke bitte mit angeben.").font(.subheadline).foregroundStyle(.secondary)
                    Button("Lebensmittel selbst eingeben") { result = ParseResult(date: Date(), items: [ParsedItem.manual()], notes: []) }
                }.padding(24)
            }.background(Palette.background).navigationTitle("Eintragen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
                .onChange(of: speech.transcript) { _, value in if !value.isEmpty { text = speechPrefix + value } }
                .onChange(of: phase) { _, value in if value == .background { speech.stop() } }
                .onDisappear { speech.stop() }
                .sheet(isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
                    if let result { ReviewView(result: result) { dismiss() } }
                }
        }
    }
}

extension ParsedItem {
    static func manual() -> ParsedItem { MealParser.parse("Eigenes Lebensmittel").items[0] }
}

struct DraftItem: Identifiable {
    let id: UUID
    var label: String
    var food: Food?
    var amount: Double
    var estimated: Bool
}

struct ReviewView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var items: [DraftItem]
    @State private var resolveID: UUID?
    let notes: [String]
    let completion: () -> Void
    init(result: ParseResult, completion: @escaping () -> Void) {
        _date = State(initialValue: result.date)
        _items = State(initialValue: result.items.map { DraftItem(id: $0.id, label: $0.text, food: $0.food, amount: $0.amount, estimated: $0.estimatedPortion) })
        notes = result.notes; self.completion = completion
    }
    var valid: Bool { !items.isEmpty && items.allSatisfy { $0.food != nil && $0.amount.isFinite && $0.amount > 0 && $0.amount <= 10000 } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Wann?") { DatePicker("Zeitpunkt", selection: $date, in: ...Date()) }
                Section("Erkannt · bitte prüfen") {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(item.food?.name ?? item.label).font(.headline)
                                Spacer()
                                Button { items.removeAll { $0.id == item.id } } label: { Image(systemName: "xmark.circle") }.buttonStyle(.borderless).accessibilityLabel("Lebensmittel entfernen")
                            }
                            if let food = item.food {
                                HStack {
                                    Text("Menge (\(food.unit))")
                                    TextField("Menge", value: $item.amount, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                }
                                if item.estimated { Text("Portionsgröße geschätzt – bitte abwiegen oder anpassen.").font(.caption).foregroundStyle(.orange) }
                                Text("≈ \(Int(food.per100.kcal * max(0, min(item.amount, 10000)) / 100)) kcal").foregroundStyle(.secondary)
                            } else { Text("Nicht eindeutig erkannt. Bitte ein Lebensmittel auswählen oder selbst ergänzen.").font(.subheadline).foregroundStyle(.orange) }
                            Button("Lebensmittel auswählen / ändern") { resolveID = item.id }.buttonStyle(.borderless)
                        }.padding(.vertical, 6)
                    }
                }
                Section {
                    ForEach(notes, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
                    Text("Reis und Nudeln beziehen sich standardmäßig auf gekochtes Gewicht. Für Trockengewicht „Reis trocken“ oder „Nudeln trocken“ schreiben.").font(.footnote).foregroundStyle(.secondary)
                    Button("\(items.count) Einträge speichern") {
                        let meals = items.compactMap { item in item.food.map { Meal(date: date, food: $0, amount: item.amount) } }
                        if store.update({ $0.meals.append(contentsOf: meals) }) { completion() }
                    }.disabled(!valid || date > Date())
                }
            }.navigationTitle("Passt das so?").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zurück") { dismiss() } } }
                .sheet(isPresented: Binding(get: { resolveID != nil }, set: { if !$0 { resolveID = nil } })) {
                    FoodPicker { food in
                        if let index = items.firstIndex(where: { $0.id == resolveID }) { items[index].food = food }
                        resolveID = nil
                    }
                }
        }
    }
}

struct FoodPicker: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var create = false
    @State private var barcode = false
    let select: (Food) -> Void
    var foods: [Food] { (store.diary.customFoods + FoodCatalog.foods).filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.aliases.contains { $0.localizedCaseInsensitiveContains(search) } } }
    var body: some View {
        NavigationStack {
            List {
                Button("Eigenes Lebensmittel hinzufügen", systemImage: "plus") { create = true }
                Button("Barcode scannen / eingeben", systemImage: "barcode.viewfinder") { barcode = true }
                ForEach(foods) { food in
                    Button { select(food) } label: {
                        VStack(alignment: .leading) { Text(food.name).foregroundStyle(.primary); Text("\(Int(food.per100.kcal)) kcal / 100 \(food.unit)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if foods.isEmpty { Text("Keine Treffer. Ergänze das Produkt über die Verpackungsangaben.").foregroundStyle(.secondary) }
            }.searchable(text: $search, prompt: "Lebensmittel suchen").navigationTitle("Lebensmittel")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
                .sheet(isPresented: $create) { CustomFoodView(initialName: search) { food in
                    if store.update({ $0.customFoods.append(food) }) { create = false; select(food) }
                } }
                .sheet(isPresented: $barcode) { BarcodeView { food in
                    if store.update({ diary in diary.customFoods.removeAll { $0.id == food.id }; diary.customFoods.append(food) }) { barcode = false; select(food) }
                } }
        }
    }
}

struct CustomFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var unit = "g"
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    let save: (Food) -> Void
    init(initialName: String, save: @escaping (Food) -> Void) { _name = State(initialValue: initialName); self.save = save }
    func number(_ s: String) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".")) }
    var food: Food? {
        guard let k = number(kcal), let p = number(protein), let c = number(carbs), let f = number(fat) else { return nil }
        let value = Food(name: name.trimmingCharacters(in: .whitespacesAndNewlines), per100: Nutrients(k, p, c, f), unit: unit)
        return value.isValid ? value : nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Produkt") { TextField("Name", text: $name); Picker("Angaben pro 100", selection: $unit) { Text("Gramm").tag("g"); Text("Milliliter").tag("ml") } }
                Section("Nährwerte pro 100 \(unit) · laut Verpackung") {
                    field("Kilokalorien", $kcal); field("Eiweiß (g)", $protein); field("Kohlenhydrate (g)", $carbs); field("Fett (g)", $fat)
                }
                Section { Text("Alle vier Werte ausfüllen; auch 0 ist möglich. Beim nächsten Mal erkennt H-Fit diesen Namen automatisch.").font(.footnote) }
            }.navigationTitle("Eigenes Lebensmittel").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") { if let food { save(food) } }.disabled(food == nil) }
                }
        }
    }
    func field(_ label: String, _ binding: Binding<String>) -> some View { HStack { Text(label); TextField("0", text: binding).keyboardType(.decimalPad).multilineTextAlignment(.trailing) } }
}

struct EditMealView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State var meal: Meal
    @State private var delete = false
    var body: some View {
        NavigationStack {
            Form {
                Section(meal.food.name) {
                    DatePicker("Zeitpunkt", selection: $meal.date, in: ...Date())
                    HStack { Text("Menge (\(meal.food.unit))"); TextField("Menge", value: $meal.amount, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
                Button("Änderungen speichern") {
                    if store.update({ diary in if let index = diary.meals.firstIndex(where: { $0.id == meal.id }) { diary.meals[index] = meal } }) { dismiss() }
                }.disabled(!meal.isValid || meal.date > Date())
                Button("Eintrag löschen", role: .destructive) { delete = true }
            }.navigationTitle("Eintrag bearbeiten").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
                .confirmationDialog("Diesen Eintrag löschen?", isPresented: $delete, titleVisibility: .visible) {
                    Button("Löschen", role: .destructive) { if store.update({ $0.meals.removeAll { $0.id == meal.id } }) { dismiss() } }
                }
        }
    }
}
