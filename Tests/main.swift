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

let receiptText = """
Pijama M Winnie Pooh-0521041 12,99 A
Promoção Lidl Plus -3,00
MANGA MATURADA 1,12 B
0,386 kg x 2,89 EUR/kg
MAIZENA AMIDO DE MILHO 2,59 B
ATUM EM AZEITE PACK 4 3,65 B
IOGURTE GREGO NATURAL 2,25 B
PEPINO 0,41 B
0,220 kg x 1,85 EUR/kg
Deposito 0.10 0,10 F
PRODUTO DESCONHECIDO 1,00 A
Total 48,26
"""
let imported = ReceiptParser.parse(receiptText)
precondition(imported.count == 6)
precondition(imported[0].name == "Mango" && imported[0].quantity == "0,386 kg")
precondition(imported[1].name == "Mısır nişastası")
precondition(imported[2].quantity == "4’lü paket")
precondition(imported[3].name == "Yoğurt" && imported[3].location == .fridge)
precondition(imported[4].name == "Salatalık" && imported[4].quantity == "0,220 kg")
precondition(!imported[5].selected && !imported[5].translated)
var kitchen = AppData()
kitchen.inventory = []
kitchen.importReceipt(imported)
precondition(kitchen.inventory.count == 5)
precondition(!Recipe.all.first { $0.id == "yogurt" }!.missing(in: kitchen.inventory).contains("Yoğurt"))
let readyBefore = Recipe.all.filter { $0.missing(in: kitchen.inventory).isEmpty }
precondition(readyBefore.isEmpty)
kitchen.inventory += [Ingredient(name: "Domates", quantity: "2"), Ingredient(name: "Zeytinyağı", quantity: "1 şişe")]
precondition(Recipe.all.filter { $0.missing(in: kitchen.inventory).isEmpty }.map(\.id).contains("salad"))
kitchen.inventory.removeAll { $0.name == "Salatalık" }
precondition(!Recipe.all.filter { $0.missing(in: kitchen.inventory).isEmpty }.map(\.id).contains("salad"))
let yogurtIndex = kitchen.inventory.firstIndex { $0.name == "Yoğurt" }!
kitchen.inventory[yogurtIndex].quantity = "1 kase"
kitchen.inventory[yogurtIndex].location = .freezer
kitchen.importReceipt([imported[3]])
precondition(kitchen.inventory[yogurtIndex].quantity.hasPrefix("1 kase;"))
precondition(kitchen.inventory[yogurtIndex].location == .freezer)
print("PASS: receipt translation, weight, exclusions, review, stock preservation and live recipe eligibility")
