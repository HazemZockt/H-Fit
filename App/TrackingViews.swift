import SwiftUI
import Charts
import HFitCore

struct ActivityView: View {
    @EnvironmentObject private var motion: MotionService
    @EnvironmentObject private var store: DiaryStore
    @State private var add = false
    @State private var deleting: Workout?
    var body: some View {
        NavigationStack {
            List {
                Section("Deine Schritte heute") {
                    Label(motion.steps.map { $0.formatted() } ?? "Noch nicht verbunden", systemImage: "figure.walk").font(.largeTitle.bold()).foregroundStyle(Palette.lime)
                    if let km = motion.kilometers { Text("\(km.formatted(.number.precision(.fractionLength(1)))) km · vom iPhone geschätzt") }
                    Text(motion.message).font(.subheadline).foregroundStyle(.secondary)
                    Button(motion.enabled ? "Aktualisieren" : "Bewegungsdaten freigeben") { motion.connect() }
                    Text("Erfasst werden Schritte mit deinem iPhone. Apple Watch und Apple Health sind in dieser Version nicht verbunden. Schritte werden nicht automatisch in zusätzliche Essenskalorien umgerechnet.").font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("Training eintragen", systemImage: "plus") { add = true }
                    ForEach(store.diary.workouts.sorted { $0.date > $1.date }) { workout in
                        HStack {
                            Label(workout.name, systemImage: "figure.strengthtraining.traditional")
                            Spacer()
                            VStack(alignment: .trailing) { Text("\(Int(workout.minutes)) Min."); Text(workout.date, style: .date).font(.caption).foregroundStyle(.secondary) }
                        }.swipeActions { Button("Löschen", role: .destructive) { deleting = workout } }
                    }
                    if store.diary.workouts.isEmpty { Text("Spaziergang, Krafttraining oder Radfahren: Hier ist Platz für deine Bewegung.").foregroundStyle(.secondary) }
                } header: { Text("Deine Aktivitäten") }
            }.navigationTitle("In Bewegung")
                .sheet(isPresented: $add) { WorkoutForm() }
                .confirmationDialog("Training löschen?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                    Button("Löschen", role: .destructive) { if let deleting { _ = store.update { $0.workouts.removeAll { $0.id == deleting.id } } }; deleting = nil }
                }
        }
    }
}

struct WorkoutForm: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Krafttraining"
    @State private var minutes = 30.0
    @State private var date = Date()
    var workout: Workout { Workout(date: date, name: name, minutes: minutes) }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Aktivität", text: $name)
                HStack { Text("Minuten"); TextField("Dauer", value: $minutes, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                DatePicker("Wann?", selection: $date, in: ...Date())
                Button("Training speichern") { if store.update({ $0.workouts.append(workout) }) { dismiss() } }.disabled(!workout.isValid)
            }.navigationTitle("Training")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: DiaryStore
    @State private var selected = Date()
    @State private var editing: Meal?
    var days: [Date] { (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: Date())) } }
    var body: some View {
        NavigationStack {
            List {
                Section("Deine letzten 7 Tage") {
                    Chart(days, id: \.self) { day in
                        BarMark(x: .value("Tag", day, unit: .day), y: .value("kcal", store.diary.total(on: day).kcal)).foregroundStyle(Palette.lime).cornerRadius(5)
                    }.frame(height: 180).chartXAxis { AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.abbreviated)) } }
                    Text("Erfasste Kalorien. Tage ohne Einträge bedeuten fehlende Daten.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    DatePicker("Tag auswählen", selection: $selected, in: ...Date(), displayedComponents: .date)
                    let totals = store.diary.total(on: selected)
                    Text("\(Int(totals.kcal.rounded())) kcal · \(Int(totals.protein.rounded())) g Eiweiß").font(.headline)
                    let meals = store.diary.meals.filter { Calendar.current.isDate($0.date, inSameDayAs: selected) }.sorted { $0.date < $1.date }
                    ForEach(meals) { meal in Button { editing = meal } label: { MealRow(meal: meal) }.buttonStyle(.plain).listRowInsets(EdgeInsets()) }
                    if meals.isEmpty { Text("An diesem Tag ist noch nichts eingetragen.").foregroundStyle(.secondary) }
                } header: { Text("Tagebuch") }
                Section("Gewichtsverlauf") { WeightTrackingView() }
            }.navigationTitle("Dein Verlauf").sheet(item: $editing) { EditMealView(meal: $0) }
        }
    }
}

struct WeightTrackingView: View {
    @EnvironmentObject private var store: DiaryStore
    @State private var weight = ""
    @State private var date = Date()
    var kilograms: Double? { Double(weight.replacingOccurrences(of: ",", with: ".")) }
    var body: some View {
        if !store.diary.weights.isEmpty {
            Chart(store.diary.weights.sorted { $0.date < $1.date }) { item in
                LineMark(x: .value("Tag", item.date), y: .value("kg", item.kilograms)).foregroundStyle(Palette.lime)
                PointMark(x: .value("Tag", item.date), y: .value("kg", item.kilograms)).foregroundStyle(Palette.lime)
            }.frame(height: 150).chartYScale(domain: .automatic(includesZero: false))
        }
        HStack { Text("Gewicht (kg)"); TextField("z. B. 75,5", text: $weight).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
        DatePicker("Wiegetag", selection: $date, in: ...Date(), displayedComponents: .date)
        Button("Gewicht speichern") {
            if let kilograms, store.update({ $0.weights.append(WeightEntry(date: date, kilograms: kilograms)) }) { weight = "" }
        }.disabled(kilograms.map { !WeightEntry(date: date, kilograms: $0).isValid } ?? true)
        ForEach(store.diary.weights.sorted { $0.date > $1.date }.prefix(10)) { item in
            HStack { Text(item.date, style: .date); Spacer(); Text("\(item.kilograms.formatted()) kg") }
                .swipeActions { Button("Löschen", role: .destructive) { _ = store.update { $0.weights.removeAll { $0.id == item.id } } } }
        }
    }
}

struct WaterCard: View {
    @EnvironmentObject private var store: DiaryStore
    var entries: [WaterEntry] { store.diary.water.filter { Calendar.current.isDateInToday($0.date) } }
    var body: some View {
        Card {
            HStack {
                Label("Wasser", systemImage: "drop.fill").foregroundStyle(.cyan).font(.headline)
                Spacer()
                Text("\((entries.reduce(0) { $0 + $1.milliliters } / 1000).formatted(.number.precision(.fractionLength(2)))) l").font(.title2.bold())
            }
            HStack {
                Button("+ 250 ml") { _ = store.update { $0.water.append(WaterEntry(milliliters: 250)) } }.buttonStyle(.bordered)
                Button("+ 500 ml") { _ = store.update { $0.water.append(WaterEntry(milliliters: 500)) } }.buttonStyle(.bordered)
                Spacer()
                Button { if let last = entries.last { _ = store.update { $0.water.removeAll { $0.id == last.id } } } } label: { Image(systemName: "arrow.uturn.backward") }.disabled(entries.isEmpty).accessibilityLabel("Letzten Wassereintrag rückgängig machen")
            }.padding(.top, 8)
            Text("Wasser separat zählen; getrackte Getränke werden hier nicht automatisch addiert.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
