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
precondition(!readyBefore.contains { $0.id == "yogurt" })
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

var homeDay = AppData()
homeDay.lunches[today] = LunchPlan(date: today, place: .home, meal: "Domatesli yumurta", note: "Evden çalışma")
let homeDecoded = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(homeDay))
precondition(homeDecoded.lunches[today]?.place == .home)
precondition(homeDecoded.lunches[today]?.meal == "Domatesli yumurta")
let oldPlace = try JSONDecoder().decode(LunchPlace.self, from: Data("\"Lamaces · evden hazırlık\"".utf8))
precondition(oldPlace == .prep)
print("PASS: home workday plan and existing office plan compatibility")

func expectFailure(_ action: () throws -> Void) {
    do { try action(); preconditionFailure("Expected validation failure") }
    catch { }
}
precondition(StockAmount.parse("0,386 kg")?.baseValue == 386)
precondition(StockAmount.parse("1 l")?.baseValue == 1000)
precondition(StockAmount.parse("1 kase; fişten +1") == nil)
precondition(StockAmount.parse("-1 g") == nil)
precondition(StockAmount(value: 10, unit: "g").text == "10 g")
precondition(StockAmount(value: 0, unit: "adet").text == "0 adet")
var cooked = AppData()
cooked.inventory = [Ingredient(name: "Yumurta", quantity: "4 adet"), Ingredient(name: "Domates", quantity: "3 adet"), Ingredient(name: "Zeytinyağı", quantity: "0,5 l")]
let originalStock = cooked.inventory.map(\.quantity)
let eggDrafts = cooked.usage(for: eggs)
let cookingID = UUID()
try cooked.cook(id: cookingID, dish: eggs.name, drafts: eggDrafts, day: today, slot: .dinner)
precondition(cooked.inventory.map(\.quantity) == ["2 adet", "2 adet", "0,49 l"])
precondition(cooked.completed[today, default: []].contains("dinner"))
expectFailure { try cooked.cook(id: cookingID, dish: eggs.name, drafts: eggDrafts) }
expectFailure { try cooked.cook(id: UUID(), dish: eggs.name, drafts: cooked.usage(for: eggs), day: today, slot: .dinner) }
try cooked.undoCooking(cookingID)
precondition(cooked.inventory.map(\.quantity) == originalStock)
precondition(!cooked.completed[today, default: []].contains("dinner"))
precondition(cooked.cooking(on: today, slot: .dinner) == nil)
var badDrafts = cooked.usage(for: eggs)
badDrafts[1].used = "99 adet"
expectFailure { try cooked.cook(id: UUID(), dish: eggs.name, drafts: badDrafts) }
precondition(cooked.inventory.map(\.quantity) == originalStock)
badDrafts = cooked.usage(for: eggs)
badDrafts[0].used = "1 g"
expectFailure { try cooked.cook(id: UUID(), dish: eggs.name, drafts: badDrafts) }
precondition(cooked.inventory.map(\.quantity) == originalStock)
badDrafts = cooked.usage(for: eggs)
badDrafts[0].used = "0 adet"
expectFailure { try cooked.cook(id: UUID(), dish: eggs.name, drafts: badDrafts) }
let id2 = UUID()
try cooked.cook(id: id2, dish: eggs.name, drafts: cooked.usage(for: eggs))
cooked.inventory[0].quantity = "7 adet"
expectFailure { try cooked.undoCooking(id2) }
precondition(cooked.inventory[1].quantity == "2 adet")
let edited = DayMeal(time: "14:15", dish: "Domatesli yumurta", note: "Geç öğle", recipeID: "eggs")
cooked.updateMeal(edited, day: today, slot: .lunch)
precondition(cooked.meal(on: today, slot: .lunch).time == "14:15")
let cookedDecoded = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(cooked))
precondition(cookedDecoded.meal(on: today, slot: .lunch).note == "Geç öğle")
precondition(cookedDecoded.meal(on: today, slot: .lunch).recipe?.id == "eggs")
precondition(cookedDecoded.cookingHistory?.count == 2)
var oldJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(cooked)) as! [String: Any]
oldJSON.removeValue(forKey: "dayMeals")
oldJSON.removeValue(forKey: "cookingHistory")
let oldData = try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: oldJSON))
precondition(oldData.dayMeals == nil && oldData.cookingHistory == nil)
var zeroStock = AppData()
zeroStock.inventory[0].quantity = "0 adet"
precondition(eggs.missing(in: zeroStock.inventory).contains("Yumurta"))
var translated = imported[3]
translated.name = "Doğal Yunan yoğurdu"
var dynamicKitchen = AppData()
dynamicKitchen.inventory = []
dynamicKitchen.importReceipt([translated])
precondition(dynamicKitchen.inventory[0].recipeName == "Yoğurt")
precondition(!Recipe.all.first { $0.id == "yogurt" }!.missing(in: dynamicKitchen.inventory).contains("Yoğurt"))
var ambiguous = AppData()
let ambiguousDrafts = ambiguous.usage(for: eggs)
expectFailure { try ambiguous.cook(id: UUID(), dish: eggs.name, drafts: ambiguousDrafts) }
precondition(ambiguous.inventory[0].quantity == "4 adet")
var clarified = ambiguousDrafts
if let oil = clarified.firstIndex(where: { $0.name == "Zeytinyağı" }) { clarified[oil].available = "500 ml" }
try ambiguous.cook(id: UUID(), dish: eggs.name, drafts: clarified)
precondition(ambiguous.inventory.first { $0.name == "Zeytinyağı" }?.quantity == "490 ml")
print("PASS: meal editing, cooking, stock conversions, atomic validation, duplicate protection, undo, zero stock, migration and translated recipe aliases")

precondition(Recipe.all.count == 40)
precondition(Set(Recipe.all.map(\.id)).count == Recipe.all.count)
for recipe in Recipe.all {
    precondition(!recipe.steps.isEmpty && recipe.minutes > 0)
    for name in recipe.ingredients {
        precondition((recipe.amount(for: name)?.value ?? 0) > 0, "Missing amount: \(recipe.id) / \(name)")
    }
}
var planningData = AppData()
planningData.inventory = [Ingredient(name: "Domates", quantity: "1 adet"), Ingredient(name: "Zeytinyağı", quantity: "500 ml")]
let bowlRecipe = Recipe.all.first { $0.id == "bowl" }!
planningData.setRecipePlan(eggs, servings: 1)
planningData.setRecipePlan(bowlRecipe, servings: 1)
let sharedTomato = planningData.shoppingLines.first { $0.name == "Domates" }!
precondition(sharedTomato.quantityText == "1 adet") // 1 + 1 needed, subtract 1 in stock only once
precondition(sharedTomato.recipeIDs.count == 2)
precondition(planningData.shoppingLines.filter { $0.name == "Domates" }.count == 1)
precondition(!planningData.shoppingLines.contains { $0.name == "Zeytinyağı" })
let eggsLine = planningData.shoppingLines.first { $0.name == "Yumurta" }!
planningData.toggleShopping(eggsLine)
precondition(planningData.isChecked(planningData.shoppingLines.first { $0.name == "Yumurta" }!))
planningData.setRecipePlan(bowlRecipe, servings: 2)
precondition(planningData.isChecked(planningData.shoppingLines.first { $0.name == "Yumurta" }!)) // unrelated edits keep purchase state
planningData.setRecipePlan(eggs, servings: 2)
precondition(!planningData.isChecked(planningData.shoppingLines.first { $0.name == "Yumurta" }!)) // quantity increase needs review
planningData.addShoppingItem(name: "Domates", quantity: "2 adet")
precondition(planningData.shoppingLines.filter { $0.name == "Domates" }.count == 1)
planningData.removeRecipePlan("eggs")
planningData.removeRecipePlan("bowl")
precondition(planningData.shoppingLines.count == 1 && planningData.shoppingLines[0].quantityText == "2 adet")
let manualLine = planningData.shoppingLines[0]
planningData.toggleShopping(manualLine)
let purchase = PurchaseDraft(line: manualLine, quantity: "3 adet", location: .fridge)
try planningData.transferPurchases([purchase])
precondition(planningData.inventory.first { $0.name == "Domates" }?.quantity == "4 adet")
precondition(planningData.shoppingLines.isEmpty)
expectFailure { try planningData.transferPurchases([purchase]) }
var ambiguousPlan = AppData()
ambiguousPlan.setRecipePlan(eggs, servings: 1)
precondition(ambiguousPlan.planStockWarnings.contains("Zeytinyağı"))
precondition(!ambiguousPlan.shoppingLines.contains { $0.name == "Zeytinyağı" })
// Quantified purchases fulfil planned needs without deleting the plan.
var purchasePlan = AppData()
purchasePlan.inventory = []
purchasePlan.setRecipePlan(eggs, servings: 1)
let generated = purchasePlan.shoppingLines
for line in generated { purchasePlan.toggleShopping(line) }
try purchasePlan.transferPurchases(generated.map { PurchaseDraft(line: $0, quantity: $0.amounts[0].text, location: .fridge) })
precondition(purchasePlan.shoppingLines.isEmpty)
precondition(purchasePlan.activeRecipePlans.count == 1)
// Three portions cooked, one eaten: stock is deducted once and two ready portions remain.
var leftovers = AppData()
leftovers.inventory = [Ingredient(name: "Yumurta", quantity: "10 adet"), Ingredient(name: "Domates", quantity: "8 adet"), Ingredient(name: "Zeytinyağı", quantity: "500 ml")]
leftovers.setRecipePlan(eggs, servings: 3)
let batchID = UUID()
try leftovers.cook(id: batchID, dish: eggs.name, drafts: leftovers.usage(for: eggs, servings: 3), recipeID: eggs.id, servings: 3, eatenNow: 1)
precondition(leftovers.activeRecipePlans.isEmpty)
precondition(leftovers.inventory.map(\.quantity) == ["4 adet", "5 adet", "470 ml"])
let readyMeal = leftovers.readyMeals[0]
precondition(readyMeal.remaining == 2)
let stockAfterBatch = leftovers.inventory.map(\.quantity)
leftovers.updateMeal(DayMeal(time: "13:00", dish: readyMeal.dish, note: "Hazır yemek", recipeID: nil, preparedID: readyMeal.id), day: today, slot: .lunch)
try leftovers.eatPrepared(readyMeal.id, portions: 1, day: today, slot: .lunch)
precondition(leftovers.inventory.map(\.quantity) == stockAfterBatch)
precondition(leftovers.readyMeals[0].remaining == 1)
precondition(leftovers.meal(on: today, slot: .lunch).recipe == nil)
expectFailure { try leftovers.eatPrepared(readyMeal.id, portions: 1, day: today, slot: .lunch) }
expectFailure { try leftovers.undoCooking(batchID) }
try leftovers.undoPreparedUse(leftovers.leftoverUse(on: today, slot: .lunch)!.id)
precondition(leftovers.readyMeals[0].remaining == 2)
try leftovers.undoCooking(batchID)
precondition(leftovers.readyMeals.isEmpty && leftovers.activeRecipePlans[0].servings == 3)
precondition(leftovers.inventory.map(\.quantity) == ["10 adet", "8 adet", "500 ml"])
// A smaller batch leaves the unprepared portion of the plan active.
let smallBatch = UUID()
try leftovers.cook(id: smallBatch, dish: eggs.name, drafts: leftovers.usage(for: eggs), recipeID: eggs.id, servings: 1, eatenNow: 1)
precondition(leftovers.activeRecipePlans[0].servings == 2)
let roundTrip = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(leftovers))
precondition(roundTrip.activeRecipePlans[0].servings == 2)
let oldShoppingJSON = Data("{\"id\":\"00000000-0000-0000-0000-000000000003\",\"name\":\"Kahve\",\"checked\":true}".utf8)
let oldShoppingItem = try JSONDecoder().decode(ShoppingItem.self, from: oldShoppingJSON)
precondition(oldShoppingItem.checked && oldShoppingItem.quantity == nil)
print("PASS: 40 complete recipes, shared requirements, one-time stock allocation, servings, purchase state, manual preservation, purchase transfer, leftovers, partial batches and migration")

precondition(Recipe.ingredientKey("Yarım yağlı süt") == Recipe.ingredientKey("Süt"))
precondition(Recipe.ingredientKey("Rendelenmiş peynir") == Recipe.ingredientKey("Peynir"))
precondition(Recipe.all.first { $0.id == "milk-porridge" }!.missing(in: [Ingredient(name: "Yarım yağlı süt", quantity: "1 l"), Ingredient(name: "Yulaf", quantity: "1 kg"), Ingredient(name: "Muz", quantity: "2 adet")]).isEmpty)
var legacyPlanJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(leftovers)) as! [String: Any]
for key in ["recipePlans", "recipeShoppingChecks", "preparedMeals", "leftoverUses"] { legacyPlanJSON.removeValue(forKey: key) }
let legacyPlans = try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: legacyPlanJSON))
precondition(legacyPlans.activeRecipePlans.isEmpty && legacyPlans.readyMeals.isEmpty)
var massPlan = AppData()
massPlan.inventory = [Ingredient(name: "Nohut", quantity: "0,1 kg")]
massPlan.setRecipePlan(bowlRecipe, servings: 2)
precondition(massPlan.shoppingLines.first { $0.name == "Nohut" }?.quantityText == "200 g")
var allPrepared = AppData()
allPrepared.inventory = [Ingredient(name: "Yumurta", quantity: "8 adet"), Ingredient(name: "Domates", quantity: "4 adet"), Ingredient(name: "Zeytinyağı", quantity: "100 ml")]
try allPrepared.cook(id: UUID(), dish: eggs.name, drafts: allPrepared.usage(for: eggs, servings: 2), recipeID: eggs.id, servings: 2, eatenNow: 0)
precondition(allPrepared.readyMeals[0].remaining == 2)
let preparedRoundTrip = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(allPrepared))
precondition(preparedRoundTrip.readyMeals[0].remaining == 2)
expectFailure { try allPrepared.eatPrepared(allPrepared.readyMeals[0].id, portions: 3, day: today, slot: .dinner) }
precondition(allPrepared.readyMeals[0].remaining == 2)
var transferValidation = AppData()
transferValidation.inventory = []
transferValidation.setRecipePlan(eggs, servings: 1)
let transferLines = transferValidation.shoppingLines
for line in transferLines { transferValidation.toggleShopping(line) }
let transferDrafts = transferLines.map { PurchaseDraft(line: $0, quantity: $0.amounts[0].text, location: .pantry) }
var invalidDrafts = transferDrafts
invalidDrafts[invalidDrafts.count - 1].quantity = "bilinmiyor"
expectFailure { try transferValidation.transferPurchases(invalidDrafts) }
precondition(transferValidation.inventory.isEmpty)
expectFailure { try transferValidation.transferPurchases([transferDrafts[0], transferDrafts[0]]) }
print("PASS: common product aliases, older data, kg/g shortfalls, preparation-only batches, leftover limits and atomic purchase validation")

var daily = AppData()
daily.inventory = []
let todayKey = AppData.dayKey()
let tomorrowKey = AppData.dayKey(Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
let selectedRecipe = DayMeal(time: "13:00", dish: eggs.name, note: "Evde", recipeID: eggs.id, source: .recipe, servings: 1)
try daily.selectMeal(selectedRecipe, day: todayKey, slot: .lunch)
precondition(daily.meal(on: todayKey, slot: .lunch).origin == .recipe)
precondition(daily.shoppingLines.contains { $0.name == "Yumurta" })
precondition(daily.inventory.isEmpty && daily.completed.isEmpty)
try daily.selectMeal(selectedRecipe, day: tomorrowKey, slot: .lunch)
precondition(daily.activeRecipePlans.first { $0.recipeID == eggs.id }?.servings == 2)
precondition(daily.shoppingLines.first { $0.name == "Yumurta" }?.quantityText == "4 adet")
daily.setRecipePlan(eggs, servings: 3)
precondition(daily.activeRecipePlans.first { $0.recipeID == eggs.id }?.servings == 3) // manual batch covers the scheduled portions
let outsideSameName = DayMeal(time: "13:15", dish: eggs.name, note: "Dışarıda", recipeID: nil, source: .outside)
try daily.selectMeal(outsideSameName, day: todayKey, slot: .lunch)
precondition(daily.meal(on: todayKey, slot: .lunch).recipe == nil)
precondition(daily.scheduledRecipePortions[eggs.id] == 1)
try daily.markOutsideEaten(day: todayKey, slot: .lunch)
precondition(daily.inventory.isEmpty && daily.readyMeals.isEmpty)
expectFailure { try daily.selectMeal(selectedRecipe, day: todayKey, slot: .lunch) }
try daily.undoMeal(day: todayKey, slot: .lunch)
precondition(!daily.completed[todayKey, default: []].contains("lunch"))
daily.setLunchPlace(.lidl, day: tomorrowKey)
precondition(daily.lunchPlace(on: tomorrowKey) == .lidl)
precondition(daily.meal(on: tomorrowKey, slot: .lunch).dish == eggs.name)
var legacyLunch = AppData()
legacyLunch.lunches[todayKey] = LunchPlan(date: todayKey, place: .cafeteria, meal: eggs.name, note: "Eski plan")
precondition(legacyLunch.lunchPlace(on: todayKey) == .cafeteria)
precondition(legacyLunch.meal(on: todayKey, slot: .lunch).origin == .outside)
precondition(legacyLunch.meal(on: todayKey, slot: .lunch).recipe == nil)
let legacyDay = Data("{\"time\":\"13:00\",\"dish\":\"Domatesli yumurta\",\"note\":\"\",\"recipeID\":\"eggs\"}".utf8)
let migratedDayMeal = try JSONDecoder().decode(DayMeal.self, from: legacyDay)
precondition(migratedDayMeal.origin == .recipe)
var featureData = AppData()
let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!
precondition(featureData.featuredMeal(on: noon) == .lunch)
featureData.updateMeal(outsideSameName, day: todayKey, slot: .lunch)
let afterLunch = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: .now)!
precondition(featureData.featuredMeal(on: afterLunch) == .lunch)
try featureData.markOutsideEaten(day: todayKey, slot: .lunch)
precondition(featureData.featuredMeal(on: afterLunch) == .dinner)
featureData.completed[todayKey] = Set(MealSlot.allCases.map(\.rawValue))
precondition(featureData.featuredMeal(on: afterLunch) == nil)
var readySelection = AppData()
readySelection.inventory = []
readySelection.preparedMeals = [PreparedMeal(dish: "Kalan yemek", recipeID: eggs.id, initialPortions: 2, remaining: 2)]
try readySelection.selectMeal(selectedRecipe, day: tomorrowKey, slot: .dinner)
precondition(!readySelection.shoppingLines.isEmpty)
let existingReady = readySelection.readyMeals[0]
try readySelection.selectMeal(DayMeal(time: "19:30", dish: existingReady.dish, note: "", recipeID: nil, preparedID: existingReady.id, source: .prepared), day: tomorrowKey, slot: .dinner)
precondition(readySelection.shoppingLines.isEmpty)
precondition(readySelection.readyMeals[0].remaining == 2) // selecting is not eating
let dailyRoundTrip = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(daily))
precondition(dailyRoundTrip.lunchPlace(on: tomorrowKey) == .lidl)
precondition(dailyRoundTrip.meal(on: todayKey, slot: .lunch).origin == .outside)
print("PASS: unified day flow, meal sources, automatic shopping, scheduled portion aggregation, context persistence, legacy lunch, featured meal and stock-free outside/ready planning")

let myIngredients = [PersonalIngredient(name: "Pirinç", quantity: "300 g"), PersonalIngredient(name: "Tavuk", quantity: "450 g")]
let myDish = try Recipe.personal(name: "Kendi tavuklu pilavım", minutes: 30, portions: 3, ingredients: myIngredients, instructions: "Pirinci pişir.\nTavuğu tamamen pişirip ekle.")
precondition(myDish.ingredients.count == 2 && myDish.steps.count == 2)
precondition(myDish.amount(for: "Pirinç")?.value == 100)
precondition(myDish.amount(for: "Tavuk", servings: 3)?.value == 450)
var personalData = AppData()
personalData.inventory = [Ingredient(name: "Pirinç", quantity: "50 g"), Ingredient(name: "Tavuk", quantity: "500 g")]
personalData.savePersonalRecipe(myDish)
precondition(personalData.allRecipes.count == Recipe.all.count + 1)
let myMeal = DayMeal(time: "19:30", dish: myDish.name, note: "", recipeID: myDish.id, source: .recipe, servings: 3, personalRecipe: myDish)
try personalData.selectMeal(myMeal, day: todayKey, slot: .dinner)
precondition(personalData.meal(on: todayKey, slot: .dinner).recipe?.id == myDish.id)
precondition(personalData.shoppingLines.first { $0.name == "Pirinç" }?.quantityText == "250 g")
precondition(personalData.shoppingLines.first { $0.name == "Pirinç" }?.recipeNames == [myDish.name])
precondition(!personalData.shoppingLines.contains { $0.name == "Tavuk" })
precondition(personalData.usage(for: myDish, servings: 3).first { $0.name == "Tavuk" }?.used == "450 g")
let personalRoundTrip = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(personalData))
precondition(personalRoundTrip.allRecipes.last?.id == myDish.id)
precondition(personalRoundTrip.meal(on: todayKey, slot: .dinner).recipe?.amount(for: "Pirinç", servings: 3)?.value == 300)
let ownMatch = personalRoundTrip.matchedRecipes().first { $0.id == myDish.id }!
precondition(ownMatch.missing.isEmpty)
precondition(ownMatch.searchText.contains(Recipe.key(myDish.name)))
var enough = personalRoundTrip
enough.inventory[0].quantity = "500 g"
try enough.cook(id: UUID(), dish: myDish.name, drafts: enough.usage(for: myDish, servings: 3), day: todayKey, slot: .dinner, recipeID: myDish.id, servings: 3, eatenNow: 1)
precondition(enough.inventory.map(\.quantity) == ["200 g", "50 g"])
precondition(enough.readyMeals[0].remaining == 2)
expectFailure { _ = try Recipe.personal(name: "", minutes: 20, portions: 1, ingredients: myIngredients, instructions: "") }
expectFailure { _ = try Recipe.personal(name: "Yemek", minutes: 20, portions: 1, ingredients: [], instructions: "") }
expectFailure { _ = try Recipe.personal(name: "Yemek", minutes: 20, portions: 1, ingredients: [PersonalIngredient(name: "Pirinç", quantity: "biraz")], instructions: "") }
expectFailure { _ = try Recipe.personal(name: "Yemek", minutes: 20, portions: 1, ingredients: [PersonalIngredient(name: "Pirinç", quantity: "100 g"), PersonalIngredient(name: "pirinç", quantity: "100 g")], instructions: "") }
var ownPlan = AppData()
ownPlan.savePersonalRecipe(myDish)
ownPlan.setRecipePlan(myDish, servings: 2)
precondition(ownPlan.activeRecipePlans[0].recipe?.id == myDish.id)
precondition(ownPlan.shoppingLines.first { $0.name == "Pirinç" }?.quantityText == "200 g")
let cachedMatches = personalData.matchedRecipes()
personalData.water[todayKey] = 7
precondition(personalData.matchedRecipes().map(\.id) == cachedMatches.map(\.id))
print("PASS: personal recipe validation, per-portion quantities, library persistence, custom shopping sources, cooking, leftovers and reusable ranked matches")
let revisedDish = try Recipe.personal(id: myDish.id, name: "Güncel pilavım", minutes: 25, portions: 1, ingredients: [PersonalIngredient(name: "Pirinç", quantity: "120 g"), PersonalIngredient(name: "Tavuk", quantity: "160 g")], instructions: "Pişir.")
personalData.setRecipePlan(myDish, servings: 3)
personalData.savePersonalRecipe(revisedDish)
precondition(personalData.customRecipes?.count == 1)
precondition(personalData.meal(on: todayKey, slot: .dinner).recipe?.name == revisedDish.name)
precondition(personalData.activeRecipePlans[0].recipe?.amount(for: "Pirinç")?.value == 120)
precondition(personalData.shoppingLines.first { $0.name == "Pirinç" }?.quantityText == "310 g")
print("PASS: personal recipe edits update pending meals and plan quantities without duplicate library entries")
