import SwiftUI

@MainActor final class FoodStore: ObservableObject {
    @Published var data: AppData { didSet { save() } }
    @Published var saveError: String?
    private let url: URL

    init() {
        url = URL.applicationSupportDirectory.appending(path: "NEXT/data.json")
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                data = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: url))
            } catch {
                data = AppData()
                saveError = "Kayıtlı veriler okunamadı. Orijinal dosya korunuyor; uygulamayı kapatıp tekrar dene."
            }
        } else {
            data = AppData()
        }
    }

    private func save() {
        guard saveError == nil else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(data).write(to: url, options: .atomic)
        } catch {
            saveError = "Değişiklikler kaydedilemedi. Depolama alanını kontrol edip uygulamayı yeniden aç."
        }
    }
}

@main struct NEXTApp: App {
    @StateObject private var store = FoodStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).preferredColorScheme(.light)
        }
    }
}
