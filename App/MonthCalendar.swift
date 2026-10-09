import SwiftUI
import HFitCore

struct MonthCalendar: View {
    @EnvironmentObject private var store: DiaryStore
    @Binding var selected: Date
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())!.start
    private let calendar = Calendar.current
    private var cells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let offset = (weekday - 2 + 7) % 7
        return Array(repeating: nil, count: offset) + range.map { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Vorheriger Monat")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Nächster Monat")
                    .disabled(calendar.isDate(month, equalTo: Date(), toGranularity: .month))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 14) {
                ForEach(Array(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"].enumerated()), id: \.offset) { _, day in Text(day).font(.caption).foregroundStyle(.secondary) }
                ForEach(cells.indices, id: \.self) { index in
                    if let date = cells[index] {
                        let score = DayBalance.score(store.diary, on: date)
                        let future = calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
                        Button { selected = date } label: {
                            ZStack {
                                Circle().stroke(.white.opacity(0.1), lineWidth: 4)
                                if let score {
                                    Circle().trim(from: 0, to: max(0.08, score)).stroke(ringColor(score), style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                                }
                                Text("\(calendar.component(.day, from: date))").font(.subheadline.weight(.semibold)).foregroundStyle(future ? Color.secondary : Color.primary)
                            }.aspectRatio(1, contentMode: .fit).padding(2)
                                .background(calendar.isDate(date, inSameDayAs: selected) ? Palette.lime.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).disabled(future)
                            .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(score.map { "Zielbilanz \(Int(($0 * 100).rounded())) Prozent" } ?? "keine bewertbare Zielbilanz")")
                    } else { Color.clear.aspectRatio(1, contentMode: .fit) }
                }
            }
            HStack(spacing: 12) { legend("Näher am Ziel", .green); legend("Abweichung", .red); legend("Unvollständig", .gray) }.font(.caption2)
            Text("Zielbilanz, keine Gesundheitsbewertung. Grün und ein voller Ring bedeuten näher an deinen Kalorien-/Eiweißrichtwerten. Nur als vollständig markierte Tage werden verglichen; fehlende Angaben bleiben grau. Grundlage sind deine aktuellen Zieleinstellungen.").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 8)
    }
    private func move(_ delta: Int) { if let value = calendar.date(byAdding: .month, value: delta, to: month) { month = value } }
    private func ringColor(_ score: Double) -> Color { Color(red: 1 - score, green: 0.25 + 0.6 * score, blue: 0.22) }
    private func legend(_ text: String, _ color: Color) -> some View { HStack(spacing: 4) { Circle().fill(color).frame(width: 6, height: 6); Text(text) } }
}
