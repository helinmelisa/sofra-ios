import Foundation
@main struct StoreCheck {
    @MainActor static func main() throws {
        let root = URL(filePath: CommandLine.arguments[1])
        let url = root.appending(path: "data.json")
        let store = FoodStore(storageURL: url)
        let day = AppData.dayKey()
        for value in 1...500 { store.data.water[day] = value }
        store.data.addShopping(["Kahve"])
        store.flushPendingSave()
        let saved = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: url))
        precondition(saved.water[day] == 500 && saved.shopping.count == 1)
        let reopened = FoodStore(storageURL: url)
        precondition(reopened.data.water[day] == 500)
        let matchBefore = reopened.recipeMatches.first { $0.id == "yogurt" }!
        reopened.data.inventory += [Ingredient(name: "Yulaf", quantity: "100 g"), Ingredient(name: "Muz", quantity: "2 adet")]
        let matchAfter = reopened.recipeMatches.first { $0.id == "yogurt" }!
        precondition(!matchBefore.missing.isEmpty && matchAfter.missing.isEmpty)
        reopened.flushPendingSave()
        let corruptURL = root.appending(path: "corrupt.json")
        try Data("original invalid data".utf8).write(to: corruptURL)
        let corrupt = FoodStore(storageURL: corruptURL)
        precondition(corrupt.saveError != nil)
        corrupt.data.water[day] = 99
        corrupt.flushPendingSave()
        let unchanged = try String(contentsOf: corruptURL, encoding: .utf8)
        precondition(unchanged == "original invalid data")
        print("PASS: 500 coalesced writes retain final state, background flush, reopen, inventory cache invalidation and corrupt-file preservation")
    }
}
