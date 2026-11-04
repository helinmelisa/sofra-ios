import SwiftUI

@main struct SofraApp: App {
    @StateObject private var store = FoodStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in if phase == .background { store.flushPendingSave() } }
        }
    }
}
