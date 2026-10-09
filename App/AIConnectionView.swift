import SwiftUI
import VisionKit
import HFitCore

struct AIConnectionView: View {
    @EnvironmentObject private var ai: AICompanion
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var scanning = false
    @State private var connecting = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("KI auf deinem Windows-PC") {
                    Text("Öffne am PC die H-Fit-Kopplungsseite. Beide Geräte müssen im selben WLAN sein; dein PC muss eingeschaltet bleiben.")
                    Text(ai.status).foregroundStyle(Palette.lime)
                    if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                        Button("QR-Code scannen", systemImage: "qrcode.viewfinder") { scanning = true }
                    }
                    TextField("Kopplungscode vom PC", text: $code, axis: .vertical).lineLimit(2...5).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(connecting ? "Verbindung wird geprüft …" : "PC verbinden") { connect() }.disabled(connecting || code.isEmpty)
                    if let message { Text(message).foregroundStyle(.orange) }
                }
                Section("Was wird übertragen?") {
                    Text("Deine Frage, die letzten vier Chatpaare, berechnete Tages-/Wochenwerte, Alter/Ziel und bis zu 100 eigene Lebensmittel gehen verschlüsselt an deinen gekoppelten PC. Dort antwortet Ollama lokal. Der PC speichert den Chat nicht.")
                    Text("Bei unbekannten Lebensmitteln kann der PC den Lebensmittelnamen bei Open Food Facts nachschlagen. Dein Tagebuch wird nicht an die Produktdatenbank übertragen. Nährwerte und Mengen vor dem Speichern prüfen.")
                    Text("Der Kopplungsschlüssel bleibt im iPhone-Schlüsselbund und ist nicht Teil deiner Tagebuchsicherung.")
                }.font(.footnote)
                if ai.pairing != nil { Section { Button("PC trennen", role: .destructive) { ai.disconnect() }.disabled(ai.busy) } }
            }.navigationTitle("PC verbinden").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
                .sheet(isPresented: $scanning) {
                    NavigationStack {
                        QRPairScanner { value in code = value; scanning = false } failure: { error in message = error; scanning = false }
                            .navigationTitle("Kopplungscode scannen")
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { scanning = false } } }
                    }
                }
        }
    }
    private func connect() {
        connecting = true; message = nil
        Task {
            defer { connecting = false }
            do { try await ai.pair(code); code = ""; dismiss() }
            catch { message = error.localizedDescription }
        }
    }
}

private struct QRPairScanner: UIViewControllerRepresentable {
    let scanned: (String) -> Void
    let failure: (String) -> Void
    func makeCoordinator() -> BarcodeScanner.Coordinator { BarcodeScanner.Coordinator(scanned: scanned, failure: failure) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced,
                                                   recognizesMultipleItems: false, isGuidanceEnabled: true, isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        DispatchQueue.main.async { do { try controller.startScanning() } catch { failure("Kamera nicht verfügbar. Bitte Kopplungscode einfügen.") } }
        return controller
    }
    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: BarcodeScanner.Coordinator) { controller.stopScanning() }
}
