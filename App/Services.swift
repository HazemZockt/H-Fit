import SwiftUI
import HFitCore
import CoreMotion
import Speech
import AVFoundation
import UniformTypeIdentifiers
import Combine

@MainActor final class DiaryStore: ObservableObject {
    @Published private(set) var diary = Diary()
    @Published var error: String?
    @Published private(set) var recoveryRequired = false
    private let url: URL
    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--hfit-ui-test")
        url = URL.applicationSupportDirectory.appending(path: testing ? "HFitUITests/diary.json" : "HFit/diary.json")
        if testing { try? FileManager.default.removeItem(at: url) }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let loaded = try JSONDecoder().decode(Diary.self, from: Data(contentsOf: url))
                try loaded.validate(); diary = loaded
            }
        } catch { recoveryRequired = true; self.error = "Dein Tagebuch konnte nicht geladen werden. Die Datei bleibt erhalten. Stelle eine gültige Sicherung wieder her, bevor du neue Daten speicherst." }
    }
    @discardableResult func update(_ mutation: (inout Diary) -> Void) -> Bool {
        guard !recoveryRequired else { error = "Bitte zuerst eine Sicherung wiederherstellen. Die vorhandene Datei wird nicht überschrieben."; return false }
        var next = diary; mutation(&next)
        return persist(next)
    }
    @discardableResult private func persist(_ next: Diary) -> Bool {
        do {
            try next.validate()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(next)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            diary = next; recoveryRequired = false; return true
        } catch { self.error = "Speichern fehlgeschlagen: \(error.localizedDescription)"; return false }
    }
    func restore(_ next: Diary) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let backup = url.deletingLastPathComponent().appending(path: "before-restore-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: url, to: backup)
            }
            return persist(next)
        } catch { self.error = "Die vorhandenen Daten konnten nicht gesichert werden: \(error.localizedDescription)"; return false }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(diary: Diary) throws { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; data = try encoder.encode(diary) }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

@MainActor final class MotionService: ObservableObject {
    @Published var steps: Int?
    @Published var kilometers: Double?
    @Published var message = "Schritte freigeben, um deine Bewegung zu sehen."
    @Published var enabled = UserDefaults.standard.bool(forKey: "motionEnabled")
    private let pedometer = CMPedometer()
    private var queriedDay = Date.distantPast
    func connect() {
        guard CMPedometer.isStepCountingAvailable() else { message = "Auf diesem Gerät ist keine Schrittzählung verfügbar."; return }
        enabled = true; UserDefaults.standard.set(true, forKey: "motionEnabled")
        refresh()
    }
    func refresh() {
        guard enabled else { return }
        pedometer.stopUpdates()
        queriedDay = Calendar.current.startOfDay(for: Date())
        let start = queriedDay
        pedometer.queryPedometerData(from: start, to: Date()) { [weak self] data, error in
            Task { @MainActor in self?.receive(data, error: error, start: start) }
        }
        pedometer.startUpdates(from: start) { [weak self] data, error in
            Task { @MainActor in self?.receive(data, error: error, start: start) }
        }
    }
    func refreshIfNewDay() { if !Calendar.current.isDateInToday(queriedDay) { refresh() } }
    private func receive(_ data: CMPedometerData?, error: Error?, start: Date) {
        guard start == queriedDay else { return }
        if let data { steps = data.numberOfSteps.intValue; kilometers = data.distance.map { $0.doubleValue / 1000 }; message = "Vom iPhone erfasst · heute" }
        else if error != nil { steps = nil; kilometers = nil; message = "Keine Bewegungsdaten verfügbar. Prüfe Einstellungen → Datenschutz & Sicherheit → Bewegung & Fitness." }
    }
}

@MainActor final class SpeechService: ObservableObject {
    @Published var transcript = ""
    @Published var recording = false
    @Published var requesting = false
    @Published var message: String?
    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var hasTap = false
    private var timeout: Task<Void, Never>?
    private var sessionID = UUID()
    func start() async {
        guard !recording, !requesting else { return }
        requesting = true
        let authorizationID = UUID()
        sessionID = authorizationID
        defer { requesting = false }
        let status = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
        guard sessionID == authorizationID else { return }
        guard status == .authorized else { message = "Spracherkennung ist nicht freigegeben. Tippen funktioniert weiterhin. Du kannst die Freigabe in den iPhone-Einstellungen ändern."; return }
        let microphone = await withCheckedContinuation { continuation in AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) } }
        guard sessionID == authorizationID else { return }
        guard microphone else { message = "Bitte erlaube den Mikrofonzugriff in den iPhone-Einstellungen."; return }
        guard recognizer?.isAvailable == true else { message = "Die deutsche Spracherkennung ist gerade nicht verfügbar. Nutze die Tastatur oder versuche es mit Internetverbindung erneut."; return }
        do {
            stop()
            let currentID = UUID()
            sessionID = currentID
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer?.supportsOnDeviceRecognition == true { request.requiresOnDeviceRecognition = true }
            self.request = request; transcript = ""; message = nil
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw NSError(domain: "HFit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Kein Mikrofon verfügbar."]) }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }; hasTap = true
            task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self, self.recording, self.sessionID == currentID else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if result?.isFinal == true || error != nil {
                        if error != nil, self.transcript.isEmpty { self.message = "Die Aufnahme konnte nicht erkannt werden. Bitte erneut versuchen oder tippen." }
                        self.stop()
                    }
                }
            }
            engine.prepare(); try engine.start(); recording = true
            timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(50)); self?.stop() } catch { }
            }
        } catch { stop(); message = error.localizedDescription }
    }
    func stop() {
        sessionID = UUID()
        recording = false; timeout?.cancel(); timeout = nil
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio(); task?.cancel(); task = nil; request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
