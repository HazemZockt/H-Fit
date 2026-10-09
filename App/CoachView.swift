import SwiftUI
import HFitCore

struct CoachView: View {
    @EnvironmentObject private var store: DiaryStore
    @EnvironmentObject private var ai: AICompanion
    @State private var question = ""
    @State private var clear = false
    @State private var capture = false
    @State private var connection = false
    @State private var proposal: AIResponse?
    @State private var review = false
    @State private var requestTask: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Card {
                            Label(ai.pairing == nil ? "Dein Alltag, ausgewertet" : "Deine KI auf dem PC", systemImage: "sparkles").font(.headline).foregroundStyle(Palette.lime)
                            Text(ai.pairing == nil ? "Lokale Auswertungen sind sofort verfügbar. Verbinde deinen Windows-PC für echten KI-Chat und Rückfragen zu Mahlzeiten." : ai.status).foregroundStyle(.secondary).padding(.top, 8)
                            Button(ai.pairing == nil ? "PC verbinden" : "Verbindung verwalten") { connection = true }.padding(.top, 8).disabled(ai.busy)
                            Text("KI-Antworten können falsch sein. Nährwerte kommen aus Produktdaten; dein Tagebuch ändert sich nur nach Bestätigung.").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                        }
                        ForEach(["Wie ist meine Bilanz heute?", "Wie berechnest du meinen Bedarf?", "Wie viel Eiweiß fehlt?", "Wie war meine Woche?"], id: \.self) { text in
                            Button(text) { send(text) }.buttonStyle(.bordered).disabled(ai.busy)
                        }
                        ForEach(store.diary.chat ?? []) { entry in
                            VStack(alignment: .trailing, spacing: 8) {
                                Text(entry.question).padding(16).background(Palette.lime.opacity(0.16), in: RoundedRectangle(cornerRadius: 20)).frame(maxWidth: .infinity, alignment: .trailing)
                                Card { Text(entry.answer); Text("\(entry.provider ?? "Lokale Auswertung") · \(entry.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary).padding(.top, 10) }
                            }.id(entry.id)
                        }
                        if ai.busy {
                            ProgressView("KI antwortet auf deinem PC …")
                            Button("Antwort abbrechen") { requestTask?.cancel() }
                        }
                        if let proposal, !proposal.items.isEmpty {
                            Card {
                                Text("\(proposal.items.count) Lebensmittel vorgeschlagen · noch nicht eingetragen").font(.headline)
                                Button("Mengen und Produkte prüfen") { review = true }.buttonStyle(.borderedProminent).foregroundStyle(Palette.background).padding(.top, 8)
                                Button("Vorschlag verwerfen", role: .destructive) { self.proposal = nil }.padding(.top, 8)
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(20)
                }.background(Palette.background)
                    .onChange(of: store.diary.chat?.count) { _, _ in withAnimation { reader.scrollTo("bottom", anchor: .bottom) } }
                    .safeAreaInset(edge: .bottom) {
                        VStack(spacing: 10) {
                            HStack(alignment: .bottom) {
                                TextField("Frag zu deinem Tagebuch …", text: $question, axis: .vertical).lineLimit(1...4).textFieldStyle(.roundedBorder).disabled(ai.busy)
                                Button { send(question) } label: { Image(systemName: "arrow.up.circle.fill").font(.largeTitle) }.accessibilityLabel("Frage auswerten").disabled(ai.busy || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || question.count > 2000)
                            }
                            Button("Mahlzeit sagen oder schreiben", systemImage: "plus.circle") { capture = true }.font(.subheadline)
                        }.padding().background(Palette.card)
                    }
            }.navigationTitle("Dein Assistent")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Leeren", systemImage: "trash") { clear = true }.disabled(ai.busy || (store.diary.chat ?? []).isEmpty) } }
                .confirmationDialog("Chatverlauf löschen?", isPresented: $clear, titleVisibility: .visible) {
                    Button("Chat löschen", role: .destructive) { if store.update({ $0.chat = [] }) { proposal = nil } }
                } message: { Text("Dein Tagebuch und Profil bleiben erhalten.") }
                .sheet(isPresented: $capture) { CaptureView() }
                .sheet(isPresented: $connection) { AIConnectionView() }
                .sheet(isPresented: $review) { if let proposal { AIReviewView(response: proposal) { self.proposal = nil } } }
        }
    }
    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 2000 else { return }
        guard (store.diary.chat?.count ?? 0) < 400 else { store.error = "Dein Chat ist voll. Leere den Verlauf, um neue Fragen auszuwerten."; return }
        if let answer = LocalCoach.calculatedReply(trimmed, diary: store.diary) {
            var entry = ChatEntry(question: trimmed, answer: answer)
            entry.provider = "Aus deinem Tagebuch berechnet"
            if store.update({ $0.chat = ($0.chat ?? []) + [entry] }) { question = "" }
            return
        }
        if ai.pairing != nil {
            guard !ai.busy else { return }
            requestTask = Task {
                do {
                    let response = try await ai.ask(trimmed, diary: store.diary)
                    var entry = ChatEntry(question: trimmed, answer: response.reply)
                    entry.provider = "KI auf PC · \(response.model)"
                    if store.update({ $0.chat = ($0.chat ?? []) + [entry] }) { question = ""; proposal = response.items.isEmpty ? nil : response }
                } catch {
                    if !Task.isCancelled { store.error = error.localizedDescription }
                }
            }
            return
        }
        let entry = ChatEntry(question: trimmed, answer: LocalCoach.reply(trimmed, diary: store.diary))
        if store.update({ $0.chat = ($0.chat ?? []) + [entry] }) { question = "" }
    }
}
