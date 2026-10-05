import SwiftUI
import HFitCore
import Combine

struct RecipesView: View {
    @EnvironmentObject private var store: DiaryStore
    @State private var add = false
    @State private var selected: Recipe?
    @State private var deleting: Recipe?
    var body: some View {
        List {
            Section { Button("Rezept erstellen", systemImage: "plus") { add = true } }
            Section("Deine Rezepte") {
                ForEach(store.diary.recipes) { recipe in
                    Button { selected = recipe } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(recipe.name).font(.headline).foregroundStyle(.primary)
                            Text("≈ \(Int(recipe.total.kcal / recipe.servings)) kcal pro Portion · \(recipe.ingredients.count) Zutaten").foregroundStyle(.secondary)
                        }
                    }.swipeActions { Button("Löschen", role: .destructive) { deleting = recipe } }
                }
                if store.diary.recipes.isEmpty { Text("Speichere dein Lieblingsfrühstück oder ein ganzes Gericht. H-Fit rechnet die Zutaten pro Portion aus.").foregroundStyle(.secondary) }
            }
        }.navigationTitle("Rezepte & Mahlzeiten")
            .sheet(isPresented: $add) { RecipeForm() }
            .sheet(item: $selected) { RecipeDetail(recipe: $0) }
            .confirmationDialog("Rezept löschen?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { if let deleting { _ = store.update { $0.recipes.removeAll { $0.id == deleting.id } } }; deleting = nil }
            }
    }
}

struct RecipeForm: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var servings = 2.0
    @State private var ingredients: [Meal] = []
    @State private var instructions = ""
    @State private var picker = false
    var recipe: Recipe { Recipe(name: name, ingredients: ingredients, servings: servings, instructions: instructions) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Dein Rezept") {
                    TextField("Rezeptname", text: $name)
                    HStack { Text("Ergibt Portionen"); TextField("Portionen", value: $servings, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
                Section("Zutaten für das gesamte Rezept") {
                    ForEach($ingredients) { $ingredient in
                        VStack(alignment: .leading) {
                            Text(ingredient.food.name)
                            HStack { Text(ingredient.food.unit).foregroundStyle(.secondary); TextField("Menge", value: $ingredient.amount, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                        }
                    }.onDelete { offsets in ingredients.remove(atOffsets: offsets) }
                    Button("Zutat hinzufügen", systemImage: "plus") { picker = true }
                }
                Section("Zubereitung · optional") { TextEditor(text: $instructions).frame(minHeight: 100) }
                Button("Rezept speichern") { if store.update({ $0.recipes.append(recipe) }) { dismiss() } }.disabled(!recipe.isValid)
            }.navigationTitle("Neues Rezept").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
                .sheet(isPresented: $picker) { FoodPicker { food in ingredients.append(Meal(date: Date(), food: food, amount: food.portion)); picker = false } }
        }
    }
}

struct RecipeDetail: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var portions = 1.0
    @State private var date = Date()
    var entries: [Meal] { recipe.meals(for: portions, at: date) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Für \(recipe.servings.formatted()) Portionen") {
                    ForEach(recipe.ingredients) { ingredient in
                        HStack { Text(ingredient.food.name); Spacer(); Text("\(ingredient.amount.formatted()) \(ingredient.food.unit)").foregroundStyle(.secondary) }
                    }
                    if !recipe.instructions.isEmpty { Text(recipe.instructions) }
                }
                Section("In dein Tagebuch") {
                    HStack { Text("Gegessene Portionen"); TextField("Portionen", value: $portions, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    DatePicker("Wann?", selection: $date, in: ...Date())
                    if portions.isFinite && portions > 0 && portions <= 100 { Text("≈ \(Int(recipe.total.kcal * portions / recipe.servings)) kcal") }
                    Button("Mahlzeit eintragen") { if store.update({ $0.meals.append(contentsOf: entries) }) { dismiss() } }.disabled(!portions.isFinite || portions <= 0 || portions > 100 || !entries.allSatisfy(\.isValid))
                }
                ShareLink(item: "\(recipe.name)\n\n" + recipe.ingredients.map { "\($0.amount.formatted()) \($0.food.unit) \($0.food.name)" }.joined(separator: "\n") + "\n\n\(recipe.instructions)") { Label("Zutatenliste teilen", systemImage: "square.and.arrow.up") }
            }.navigationTitle(recipe.name).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }
    }
}

struct FastingView: View {
    @EnvironmentObject private var store: DiaryStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        Form {
            Section("Essenspause") {
                Text("Optionaler Zeitmesser für Erwachsene. H-Fit empfiehlt keine Fastendauer. Essenspausen sind keine Voraussetzung für Gewichtsveränderungen.").font(.subheadline)
                if let start = store.diary.fastingStart {
                    let seconds = max(0, Int(now.timeIntervalSince(start)))
                    Text(String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)).font(.system(size: 44, weight: .bold, design: .monospaced)).foregroundStyle(Palette.lime)
                    Text("Begonnen: \(start.formatted())").foregroundStyle(.secondary)
                    Button("Pause beenden") { _ = store.update { $0.fastingStart = nil } }
                } else { Button("Zeitmessung starten") { _ = store.update { $0.fastingStart = Date() }; now = Date() } }
            }
            Section { Text("Bei Schwangerschaft, Stillzeit, Essstörungen, Untergewicht oder Erkrankungen wie Diabetes ist Fasten ohne fachliche Begleitung nicht geeignet. Beende die Pause, wenn du dich unwohl fühlst. Der Timer sendet keine Erinnerungen, Mahlzeiten werden unabhängig davon erfasst.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("Essenspause").onReceive(timer) { now = $0 }
    }
}
