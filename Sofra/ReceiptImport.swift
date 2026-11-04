import SwiftUI
import PhotosUI
import Vision
import ImageIO
import Translation

/// Reads on-device and joins receipt columns by vertical position before parsing.
enum ReceiptOCR {
    static func text(from data: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let orientation = CGImagePropertyOrientation(rawValue: (properties?[kCGImagePropertyOrientation] as? UInt32) ?? 1) ?? .up
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["pt-PT", "en-US"]
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
            let observations = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            var rows: [[VNRecognizedTextObservation]] = []
            for observation in observations {
                if let last = rows.last, let anchor = last.first,
                   abs(anchor.boundingBox.midY - observation.boundingBox.midY) < min(anchor.boundingBox.height, observation.boundingBox.height) * 0.55 {
                    rows[rows.count - 1].append(observation)
                } else { rows.append([observation]) }
            }
            return rows.map { row in
                row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                    .compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            }.joined(separator: "\n")
        }.value
    }
}

struct ReceiptImportView: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var items: [ReceiptItem] = []
    @State private var busy = false
    @State private var error: String?
    @State private var hasRead = false
    @State private var translating = false
    @State private var loadTask: Task<Void, Never>?
    private var selectedCount: Int { items.filter { $0.selected && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label(hasRead ? "Başka fiş seç" : "Fiş fotoğrafı seç", systemImage: "doc.text.viewfinder")
                            .frame(minHeight: 44)
                    }.disabled(busy || translating)
                    if busy { ProgressView("Fiş okunuyor…") }
                    if let error { Text(error).foregroundStyle(.red) }
                } footer: {
                    Text("Portekizce ürünler cihazda Türkçeye çevrilir. Dil paketleri ilk kullanımda indirilebilir. Birden fazla ekran görüntüsü varsa sırayla ekle.")
                }
                if hasRead && !busy {
                    Section {
                        if #available(iOS 18.0, *) {
                            ReceiptTranslationControl(items: $items, translating: $translating)
                        } else {
                            Text("Dinamik çeviri iOS 18 veya üstünü gerektirir. Bu cihazda yalnızca kayıtlı ürün sözlüğü kullanılıyor.")
                                .font(.caption)
                        }
                        Text("\(selectedCount) ürün seçili. Adları, miktarları ve saklama alanlarını kontrol et.")
                        Text("Aynı ürün mutfakta varsa eski miktar korunur; fişteki miktar yanına eklenir ve saklama alanı değiştirilmez.")
                            .font(.caption).foregroundStyle(.secondary)
                        if items.isEmpty { Text("Ürün bulunamadı. Fişin ürün satırlarını daha yakından çekip tekrar dene.") }
                    }
                    ForEach($items) { $item in
                        Section {
                            Toggle("Mutfağa ekle", isOn: $item.selected)
                            Text(item.source).font(.caption).foregroundStyle(.secondary)
                            if item.canonicalName == nil && item.translated {
                                Text("Yeni ürün çevrildi. Gıda olduğunu ve saklama alanını kontrol edip eklemek istediğini seç.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if !item.translated {
                                Text("Çeviri bulunamadı. Ürün adını düzenleyip eklemek istediğini seç.")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            TextField("Türkçe ürün adı", text: $item.name).disabled(translating)
                            TextField("Miktar · bilinmiyorsa boş bırak", text: $item.quantity)
                            Picker("Saklama alanı", selection: $item.location) {
                                ForEach(StorageLocation.allCases) { area in Text(area.rawValue).tag(area) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fişten mutfağa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle (\(selectedCount))") {
                        store.data.importReceipt(items)
                        dismiss()
                    }.disabled(busy || translating || selectedCount == 0)
                }
            }
            .onChange(of: photo) { _, selected in
                loadTask?.cancel()
                loadTask = Task { @MainActor in
                    busy = true; error = nil; items = []; hasRead = false
                    defer { busy = false }
                    do {
                        guard let data = try await selected?.loadTransferable(type: Data.self) else {
                            throw CocoaError(.fileReadUnknown)
                        }
                        let text = try await ReceiptOCR.text(from: data)
                        try Task.checkCancellation()
                        items = ReceiptParser.parse(text)
                        hasRead = true
                    } catch is CancellationError {
                    } catch {
                        self.error = "Fotoğraf okunamadı. Net bir fiş ekran görüntüsüyle tekrar dene."
                    }
                }
            }
            .onDisappear { loadTask?.cancel() }
        }.tint(Ink.dark)
    }
}


@available(iOS 18.0, *)
private struct ReceiptTranslationControl: View {
    @Binding var items: [ReceiptItem]
    @Binding var translating: Bool
    @State private var configuration: TranslationSession.Configuration?
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if translating { ProgressView("Ürünler Türkçeye çevriliyor…") }
            if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary) }
            Button("Ürünleri yeniden çevir") { start() }.disabled(translating || items.isEmpty)
        }
        .task { if !items.isEmpty { start() } }
        .translationTask(configuration) { session in
            do {
                try await session.prepareTranslation()
                let batch = items.map { TranslationSession.Request(sourceText: $0.source, clientIdentifier: $0.id.uuidString) }
                let responses = try await session.translations(from: batch)
                try Task.checkCancellation()
                for response in responses {
                    if let id = response.clientIdentifier, let index = items.firstIndex(where: { $0.id.uuidString == id }) {
                        let text = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty { items[index].name = text; items[index].translated = true }
                    }
                }
                message = "Cihaz içi çeviri tamamlandı. Yeni ürünlerin adını ve saklama alanını kontrol et."
            } catch is CancellationError {
                message = "Çeviri iptal edildi. Ürün adlarını elle düzenleyebilir veya tekrar deneyebilirsin."
            } catch {
                message = "Dinamik çeviri tamamlanamadı. Portekizce–Türkçe dil paketlerini ve bağlantını kontrol et; tekrar deneyebilir veya adları elle düzenleyebilirsin."
            }
            translating = false
        }
    }
    private func start() {
        translating = true
        message = ""
        if configuration == nil {
            configuration = .init(source: Locale.Language(identifier: "pt"), target: Locale.Language(identifier: "tr"))
        } else { configuration?.invalidate() }
    }
}
