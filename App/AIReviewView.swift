import SwiftUI
import HFitCore

struct AIReviewView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    let response: AIResponse
    let completed: () -> Void
    @State private var items: [DraftItem]
    @State private var date: Date
    @State private var pickerIndex: Int?
    @State private var saved = false
    init(response: AIResponse, completed: @escaping () -> Void) {
        self.response = response; self.completed = completed
        _date = State(initialValue: response.proposedDate())
        _items = State(initialValue: response.items.map { proposal in
            let candidate = proposal.candidates.count == 1 ? proposal.candidates.first : nil
            // Missing amounts remain zero/invalid, never an invented default portion.
            let amount = proposal.amount.map { proposal.unit == "piece" ? $0 * (candidate?.portion ?? 0) : $0 } ?? 0
            return DraftItem(id: UUID(), label: proposal.query, food: candidate, amount: amount,
                             estimated: proposal.uncertain || proposal.unit == "piece")
        })
    }
    private var valid: Bool { !saved && !items.isEmpty && items.allSatisfy { $0.food?.isValid == true && $0.amount.isFinite && $0.amount > 0 && $0.amount <= 10000 } && date <= Date() }
    private var totals: Nutrients { items.reduce(Nutrients()) { result, item in
        guard let food = item.food, item.amount.isFinite, item.amount > 0, item.amount <= 10000 else { return result }
        return result + food.per100.scaled(item.amount / 100)
    } }
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("KI-Vorschlag · noch nicht gespeichert. Prüfe jedes Lebensmittel, Zubereitung, Menge und Einheit. Fehlende Angaben musst du ergänzen.").foregroundStyle(.secondary) }
                Section("Zeitpunkt") { DatePicker("Wann?", selection: $date, in: ...Date()) }
                ForEach(items.indices, id: \.self) { index in
                    Section(items[index].label) {
                        let proposal = response.items[index]
                        if !proposal.candidates.isEmpty {
                            Menu("Produkt auswählen: \(items[index].food?.name ?? "Bitte auswählen")") {
                                ForEach(proposal.candidates) { food in
                                    Button(food.name) { select(food, index: index) }
                                }
                            }
                        }
                        if let food = items[index].food {
                            Text("\(Int(food.per100.kcal.rounded())) kcal / 100 \(food.unit)").font(.caption)
                            Picker("Einheit laut Verpackung", selection: Binding(get: { items[index].food?.unit ?? "g" }, set: { items[index].food?.unit = $0 })) {
                                Text("Gramm").tag("g"); Text("Milliliter").tag("ml")
                            }
                        } else { Text("Kein eindeutiges Produkt. Bitte auswählen oder mit Verpackungsangaben ergänzen.").foregroundStyle(.orange) }
                        TextField("Menge in g/ml (0 = fehlt)", value: $items[index].amount, format: .number).keyboardType(.decimalPad)
                        if items[index].estimated { Text("Stück-/Portionsgewicht oder Erkennung ist unsicher. Bitte abwiegen oder korrigieren.").font(.caption).foregroundStyle(.orange) }
                        Text(proposal.source).font(.caption).foregroundStyle(.secondary)
                        Button("Anderes / eigenes Lebensmittel") { pickerIndex = index }
                    }
                }
                Section {
                    Text("Berechnet: \(Int(totals.kcal.rounded())) kcal · \(Int(totals.protein.rounded())) g Eiweiß").font(.headline)
                    if !valid { Text("Die Summe enthält nur gültige Mengen. Bitte alle offenen Angaben ergänzen.").font(.caption).foregroundStyle(.orange) }
                    Button("Bestätigen und ins Tagebuch eintragen") {
                        guard valid else { return }
                        let meals = items.compactMap { item in item.food.map { Meal(date: date, food: $0, amount: item.amount, estimated: item.estimated) } }
                        if store.update({ $0.meals.append(contentsOf: meals) }) { saved = true; completed(); dismiss() }
                    }.disabled(!valid)
                    Link("Open Food Facts · Daten unter ODbL", destination: URL(string: "https://world.openfoodfacts.org/terms-of-use")!)
                }
            }.navigationTitle("Mahlzeit prüfen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
                .sheet(isPresented: Binding(get: { pickerIndex != nil }, set: { if !$0 { pickerIndex = nil } })) {
                    FoodPicker { food in if let index = pickerIndex { select(food, index: index) }; pickerIndex = nil }
                }
        }
    }
    private func select(_ food: Food, index: Int) {
        items[index].food = food
        if response.items[index].unit == "piece", let count = response.items[index].amount {
            items[index].amount = count * food.portion; items[index].estimated = true
        }
    }
}
