import SwiftUI
import Charts
import HFitCore
import Combine

enum Palette {
    static let lime = Color(red: 0.78, green: 0.96, blue: 0.31)
    static let background = Color(red: 0.055, green: 0.07, blue: 0.09)
    static let card = Color(red: 0.105, green: 0.125, blue: 0.15)
}

@main struct HFitApp: App {
    @StateObject private var store = DiaryStore()
    @StateObject private var motion = MotionService()
    @StateObject private var ai = AICompanion()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(motion).environmentObject(ai)
                .preferredColorScheme(.dark).tint(Palette.lime)
                .onChange(of: phase) { _, phase in if phase == .active { motion.refresh() } }
                .alert("H-Fit", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("OK") { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: DiaryStore
    var body: some View {
        if store.diary.profile.setup == nil && !store.recoveryRequired {
            SetupView(profile: store.diary.profile)
        } else {
        TabView {
            TodayView().tabItem { Label("Heute", systemImage: "circle.dotted.circle.fill") }
            ActivityView().tabItem { Label("Bewegung", systemImage: "figure.walk") }
            CoachView().tabItem { Label("Assistent", systemImage: "bubble.left.and.text.bubble.right") }
            HistoryView().tabItem { Label("Verlauf", systemImage: "chart.bar.xaxis") }
            ProfileView().tabItem { Label("Mein Plan", systemImage: "person.crop.circle") }
        }
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card, in: RoundedRectangle(cornerRadius: 26)) }
}

struct TodayView: View {
    @EnvironmentObject private var store: DiaryStore
    @EnvironmentObject private var motion: MotionService
    @State private var add = false
    @State private var editing: Meal?
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var today = Date()
    var total: Nutrients { store.diary.total(on: today) }
    var target: Double { store.diary.calorieGoal(on: today) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(today.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.subheadline).foregroundStyle(.secondary)
                            Text(store.diary.profile.name.isEmpty ? "Dein Tag. Dein Tempo." : "Hey, \(store.diary.profile.name).")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        }
                        Spacer()
                        Image(systemName: "leaf.fill").font(.title2).foregroundStyle(Palette.lime).padding(14).background(Palette.card, in: Circle())
                    }
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("HEUTE GEGESSEN").font(.caption.weight(.semibold)).tracking(1.4).foregroundStyle(.secondary)
                                Text("\(Int(total.kcal.rounded()))").font(.system(size: 52, weight: .bold, design: .rounded)).contentTransition(.numericText())
                                Text("Kilokalorien · geschätzt").font(.subheadline).foregroundStyle(.secondary)
                                if target > 0 {
                                    Text("Dein Richtwert: \(Int(target)) kcal").font(.subheadline).foregroundStyle(Palette.lime)
                                    Text(total.kcal <= target ? "Noch \(Int((target - total.kcal).rounded())) kcal offen" : "\(Int((total.kcal - target).rounded())) kcal über Richtwert").font(.subheadline)
                                }
                            }
                            Spacer(minLength: 8)
                            ZStack {
                                Circle().stroke(.white.opacity(0.08), lineWidth: 10)
                                Circle().trim(from: 0, to: target > 0 ? min(total.kcal / target, 1) : 0).stroke(Palette.lime, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                                Image(systemName: "fork.knife").font(.title).foregroundStyle(Palette.lime)
                            }.frame(width: 86, height: 86).accessibilityHidden(true)
                        }
                        HStack(spacing: 0) {
                            macro("Eiweiß", total.protein, .cyan)
                            macro("Kohlenhydrate", total.carbs, Palette.lime)
                            macro("Fett", total.fat, .orange)
                        }.padding(.top, 20)
                        if store.diary.proteinGoal(on: today) > 0 {
                            Text("Eiweiß: \(Int(total.protein.rounded())) / \(Int(store.diary.proteinGoal(on: today))) g").font(.caption).foregroundStyle(.secondary).padding(.top, 10)
                        }
                    }
                    Button { add = true } label: {
                        HStack {
                            Image(systemName: "waveform").font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Was hast du gegessen?").font(.headline)
                                Text("Einfach sagen oder schreiben").font(.subheadline)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }.padding(20).foregroundStyle(Palette.background).background(Palette.lime, in: RoundedRectangle(cornerRadius: 24))
                    }.buttonStyle(.plain)
                    HStack {
                        Label(motion.steps.map { "\($0.formatted()) Schritte" } ?? "Schritte verbinden", systemImage: "figure.walk")
                        Spacer()
                        Text(store.diary.profile.goal.rawValue).foregroundStyle(.secondary)
                    }.font(.subheadline)
                    WaterCard()
                    HStack { Text("Dein Tagebuch").font(.title2.bold()); Spacer(); Text("Heute").foregroundStyle(.secondary) }
                    let meals = store.diary.meals.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }.sorted { $0.date < $1.date }
                    if meals.isEmpty {
                        Card {
                            Label("Dein erster Eintrag wartet.", systemImage: "text.bubble").font(.headline)
                            Text("Zum Beispiel: „Heute um 8 Uhr 60 g Haferflocken mit 200 ml Milch und eine Banane.“")
                                .foregroundStyle(.secondary).padding(.top, 8)
                        }
                    } else {
                        ForEach(meals) { meal in Button { editing = meal } label: { MealRow(meal: meal) }.buttonStyle(.plain) }
                    }
                    Card {
                        Label("Ein Impuls für heute", systemImage: "sparkles").foregroundStyle(Palette.lime).font(.headline)
                        Text(LocalCoach.insight(store.diary, on: today)).padding(.top, 8)
                        Text("Allgemeine Orientierung, keine persönliche Ernährungsberatung.").font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                    }
                }.padding(20)
            }.background(Palette.background).toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $add) { CaptureView() }
                .sheet(item: $editing) { EditMealView(meal: $0) }
                .onReceive(timer) { value in today = value; motion.refreshIfNewDay() }
        }
    }
    private func macro(_ name: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(Int(value.rounded())) g").font(.title3.bold()).foregroundStyle(color)
            Text(name).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MealRow: View {
    let meal: Meal
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: meal.food.unit == "ml" ? "cup.and.saucer.fill" : "fork.knife").foregroundStyle(Palette.lime).frame(width: 38, height: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(meal.food.name).font(.headline)
                Text("\(meal.amount.formatted(.number.precision(.fractionLength(0...1)))) \(meal.food.unit) · \(meal.date.formatted(date: .omitted, time: .shortened))").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text("≈ \(Int(meal.nutrients.kcal.rounded()))").font(.headline.monospacedDigit())
        }.padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .combine).accessibilityHint("Menge ändern oder Eintrag löschen")
    }
}

enum Coaching {
    static func tip(profile: Profile, total: Nutrients) -> String {
        if !profile.adult { return "Regelmäßig essen, abwechslungsreich auswählen und Bewegung finden, die dir Spaß macht. Kalorienziele sind hier nur für Erwachsene vorgesehen." }
        switch profile.goal {
        case .balance: return "Abwechslung zählt: Kombiniere Gemüse oder Obst, eine Eiweißquelle und sättigende Beilagen. Einzelne Tage müssen nicht perfekt sein."
        case .lose: return "Regelmäßige Mahlzeiten mit Gemüse, Vollkorn und einer Eiweißquelle können beim Sattbleiben helfen. Vermeide Crashdiäten; achte auf Energie und Wohlbefinden."
        case .build:
            if profile.proteinTarget > 0, total.protein < profile.proteinTarget { return "Für dein selbst gewähltes Eiweißziel fehlen rechnerisch etwa \(Int((profile.proteinTarget - total.protein).rounded())) g. Tofu, Hülsenfrüchte oder Quark können eine Mahlzeit ergänzen. Training und Erholung gehören genauso dazu." }
            return "Verbinde regelmäßiges Krafttraining mit ausreichend Essen und Erholung. Verteile Eiweißquellen über deine Mahlzeiten und steigere dein Training schrittweise."
        }
    }
}
