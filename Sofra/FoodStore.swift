import Foundation
import Combine

@MainActor final class FoodStore: ObservableObject {
    @Published var data: AppData {
        didSet {
            if oldValue.inventory != data.inventory || oldValue.customRecipes != data.customRecipes { recipeMatches = data.matchedRecipes() }
            save()
        }
    }
    @Published private(set) var recipeMatches: [RecipeMatch] = []
    @Published var saveError: String?
    private let url: URL
    private let persistenceQueue = DispatchQueue(label: "sofra.persistence", qos: .utility)
    private var pendingSave: DispatchWorkItem?

    init(storageURL: URL? = nil) {
        // Preserve the original installation's storage path.
        url = storageURL ?? URL.applicationSupportDirectory.appending(path: "NEXT/data.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do { data = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: url)) }
            catch {
                data = AppData()
                saveError = "Kayıtlı veriler okunamadı. Orijinal dosya korunuyor; uygulamayı kapatıp tekrar dene."
            }
        } else { data = AppData() }
        recipeMatches = data.matchedRecipes()
    }
    private func save() {
        guard saveError == nil else { return }
        let snapshot = data
        let destination = url
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            do {
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(snapshot).write(to: destination, options: .atomic)
            } catch {
                Task { @MainActor [weak self] in self?.saveError = "Değişiklikler kaydedilemedi. Depolama alanını kontrol edip uygulamayı yeniden aç." }
            }
        }
        pendingSave = work
        persistenceQueue.async(execute: work)
    }
    func flushPendingSave() { persistenceQueue.sync {} }
}
