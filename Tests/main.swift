import Foundation
var data = AppData()
let eggs = Recipe.all.first { $0.id == "eggs" }!
precondition(eggs.missing(in: data.inventory).isEmpty)
data.inventory.removeAll { $0.name == "Domates" }
precondition(eggs.missing(in: data.inventory) == ["Domates"])
data.addShopping([" Nohut ", "nohut", "", "Yoğurt"])
precondition(data.shopping.count == 2)
data.shopping[0].checked = true
data.addShopping(["Nohut"])
precondition(!data.shopping[0].checked && data.shopping.count == 2)
let today = AppData.dayKey()
data.water[today] = 3
data.completed[today] = ["lunch"]
data.lunches[today] = LunchPlan(date: today, place: .cafeteria, meal: "Öğle", note: "Not")
let decoded = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(data))
precondition(decoded.water[today] == 3)
precondition(decoded.completed[today] == ["lunch"])
precondition(decoded.lunches[today]?.place == .cafeteria)
precondition(decoded.shopping.count == 2)
print("PASS: ingredient matching, shopping deduplication, reactivation, persistence round-trip")

let legacy = "{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"Yoğurt\",\"quantity\":\"1 kase\"}"
let migrated = try JSONDecoder().decode(Ingredient.self, from: Data(legacy.utf8))
precondition(migrated.location == .fridge)
let frozen = Ingredient(name: "Nohut", quantity: "1 kap", location: .freezer)
let restored = try JSONDecoder().decode(Ingredient.self, from: JSONEncoder().encode(frozen))
precondition(restored.location == .freezer)
precondition(Recipe.all[0].missing(in: [frozen]).contains("Nohut") == false)
print("PASS: legacy migration, storage persistence, matching across storage locations")
