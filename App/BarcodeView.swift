import SwiftUI
import VisionKit
import Vision
import AVFoundation
import HFitCore

struct BarcodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var scanning = false
    @State private var loading = false
    @State private var message: String?
    @State private var food: Food?
    @State private var unit = "g"
    @State private var lookupTask: Task<Void, Never>?
    let select: (Food) -> Void
    var validCode: Bool { [8, 12, 13, 14].contains(code.count) && code.allSatisfy { $0.isASCII && $0.isNumber } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Produkt finden") {
                    TextField("Barcode-Ziffern", text: $code).keyboardType(.numberPad)
                    Button("Mit Kamera scannen", systemImage: "barcode.viewfinder") {
                        Task {
                            guard DataScannerViewController.isSupported else { message = "Der Kamerascanner wird hier nicht unterstützt. Bitte die Ziffern eingeben."; return }
                            let allowed = await AVCaptureDevice.requestAccess(for: .video)
                            if allowed && DataScannerViewController.isAvailable { scanning = true }
                            else { message = "Kamera nicht verfügbar. Prüfe die Kamerafreigabe in den Einstellungen oder tippe den Code ein." }
                        }
                    }
                    Button("Produkt suchen") { lookup() }.disabled(!validCode || loading)
                    if loading { ProgressView("Produkt wird geladen …") }
                    if let message { Text(message).foregroundStyle(.orange) }
                }
                if let food {
                    Section(food.name) {
                        Text("Pro 100 g/ml: \(Int(food.per100.kcal)) kcal · \(food.per100.protein.formatted()) g Eiweiß · \(food.per100.carbs.formatted()) g Kohlenhydrate · \(food.per100.fat.formatted()) g Fett")
                        Picker("Einheit laut Verpackung", selection: $unit) { Text("g").tag("g"); Text("ml").tag("ml") }.pickerStyle(.segmented)
                        Text("Prüfe Werte und Einheit auf der Verpackung. Community-Daten können falsch sein.").font(.footnote).foregroundStyle(.secondary)
                        Button("Dieses Produkt übernehmen") { var selected = food; selected.unit = unit; select(selected) }
                    }
                }
                Section {
                    Text("Bei einer Suche werden der Barcode und deine IP-Adresse an Open Food Facts übermittelt. Die Kameraaufnahme und dein Tagebuch werden nicht hochgeladen.")
                    Link("Quelle: Open Food Facts · ODbL", destination: URL(string: "https://world.openfoodfacts.org/terms-of-use")!)
                }.font(.footnote)
            }.navigationTitle("Barcode").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
                .sheet(isPresented: $scanning) {
                    NavigationStack {
                        BarcodeScanner { value in code = value; scanning = false; lookup() } failure: { value in message = value; scanning = false }
                            .navigationTitle("Barcode ins Bild halten")
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { scanning = false } } }
                    }
                }
                .onChange(of: code) { _, _ in food = nil; message = nil }
                .onDisappear { lookupTask?.cancel() }
        }
    }
    private func lookup() {
        guard validCode else { message = "Bitte 8, 12, 13 oder 14 Ziffern eingeben."; return }
        lookupTask?.cancel(); loading = true; message = nil; food = nil
        let requestedCode = code
        lookupTask = Task { @MainActor in
            do {
                let result = try await FoodLookup.fetch(barcode: requestedCode)
                try Task.checkCancellation()
                if code == requestedCode { food = result }
            } catch is CancellationError { }
            catch { if !Task.isCancelled { message = error.localizedDescription } }
            if !Task.isCancelled { loading = false }
        }
    }
}

enum FoodLookup {
    static func fetch(barcode: String) async throws -> Food {
        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=product_name,brands,nutriments")!
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("HFit/1.0 (personal iOS nutrition diary)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw error("Die Produktdatenbank ist gerade nicht erreichbar. Bitte später erneut versuchen.") }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["status"] as? NSNumber)?.intValue == 1,
              let product = root["product"] as? [String: Any],
              let name = product["product_name"] as? String, !name.isEmpty,
              let values = product["nutriments"] as? [String: Any] else { throw error("Produkt nicht gefunden. Du kannst es mit den Verpackungsangaben selbst hinzufügen.") }
        func value(_ key: String) -> Double? {
            if let n = values[key] as? NSNumber { return n.doubleValue }
            if let s = values[key] as? String { return Double(s) }; return nil
        }
        guard let kcal = value("energy-kcal_100g") ?? value("energy-kj_100g").map({ $0 / 4.184 }),
              let protein = value("proteins_100g"), let carbs = value("carbohydrates_100g"), let fat = value("fat_100g") else {
            throw error("Die Nährwerte dieses Produkts sind unvollständig. Bitte selbst von der Verpackung übernehmen.")
        }
        let food = Food(id: "off-\(barcode)", name: String(name.prefix(120)), per100: Nutrients(kcal, protein, carbs, fat))
        guard food.isValid else { throw error("Die Produktdaten sind nicht plausibel. Bitte die Verpackungsangaben verwenden.") }
        return food
    }
    private static func error(_ text: String) -> NSError { NSError(domain: "HFitBarcode", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
}

struct BarcodeScanner: UIViewControllerRepresentable {
    let scanned: (String) -> Void
    let failure: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(scanned: scanned, failure: failure) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce, .code128])], qualityLevel: .balanced, recognizesMultipleItems: false, isGuidanceEnabled: true, isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        DispatchQueue.main.async {
            do { try controller.startScanning() } catch { failure("Der Scanner konnte nicht gestartet werden. Bitte Barcode eintippen.") }
        }
        return controller
    }
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) { controller.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let scanned: (String) -> Void
        let failure: (String) -> Void
        var delivered = false
        init(scanned: @escaping (String) -> Void, failure: @escaping (String) -> Void) { self.scanned = scanned; self.failure = failure }
        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !delivered else { return }
            for item in addedItems { if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                delivered = true; scanner.stopScanning(); scanned(value); return
            } }
        }
        func dataScanner(_ scanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            guard !delivered else { return }; delivered = true; failure("Scanner nicht verfügbar. Bitte Barcode eintippen.")
        }
    }
}
