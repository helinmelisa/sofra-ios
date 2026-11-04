import Foundation

struct RecipePlan: Identifiable, Codable, Equatable {
    var recipeID: String
    var servings: Int
    var id: String { recipeID }
    var recipe: Recipe? { Recipe.all.first { $0.id == recipeID } }
}

struct PreparedMeal: Identifiable, Codable {
    var id = UUID()
    var dish: String
    var recipeID: String?
    var createdAt = Date.now
    var initialPortions: Int
    var remaining: Int
}

struct LeftoverUse: Identifiable, Codable {
    var id = UUID()
    var preparedID: UUID
    var day: String
    var slot: String
    var portions: Int
    var undone = false
}

struct ShoppingLine: Identifiable {
    var id: String
    var name: String
    var amounts: [StockAmount]
    var recipeIDs: [String]
    var manualIDs: [UUID]
    var manualUnspecified: Bool
    var quantityText: String {
        let amounts = amounts.map(\.text).joined(separator: " + ")
        if amounts.isEmpty { return "Miktar ekle" }
        return amounts + (manualUnspecified ? " + ek ihtiyaç" : "")
    }
    var signature: String { quantityText }
    var recipeNames: [String] { recipeIDs.compactMap { id in Recipe.all.first { $0.id == id }?.name } }
}

struct PurchaseDraft: Identifiable {
    var id: String { line.id }
    var line: ShoppingLine
    var quantity: String
    var location: StorageLocation
}

extension AppData {
    var activeRecipePlans: [RecipePlan] { (recipePlans ?? []).filter { $0.servings > 0 && $0.recipe != nil } }
    var readyMeals: [PreparedMeal] { (preparedMeals ?? []).filter { $0.remaining > 0 }.sorted { $0.createdAt < $1.createdAt } }

    mutating func setRecipePlan(_ recipe: Recipe, servings: Int) {
        let count = min(8, max(1, servings))
        if recipePlans == nil { recipePlans = [] }
        if let index = recipePlans?.firstIndex(where: { $0.recipeID == recipe.id }) { recipePlans?[index].servings = count }
        else { recipePlans?.append(RecipePlan(recipeID: recipe.id, servings: count)) }
    }
    mutating func removeRecipePlan(_ id: String) { recipePlans?.removeAll { $0.recipeID == id } }

    /// Presence of stock with unknown or incompatible units is surfaced rather than inventing a conversion.
    var planStockWarnings: [String] {
        var warnings = Set<String>()
        for plan in activeRecipePlans {
            guard let recipe = plan.recipe else { continue }
            for name in recipe.ingredients {
                guard let need = recipe.amount(for: name) else { continue }
                let stocks = inventory.filter { Recipe.ingredientKey($0.recipeName ?? $0.name) == Recipe.ingredientKey(name) }
                if stocks.contains(where: { stock in
                    guard let amount = StockAmount.parse(stock.quantity) else { return true }
                    return amount.value > 0 && amount.dimension != need.dimension
                }) { warnings.insert(name) }
            }
        }
        return warnings.sorted()
    }

    var shoppingLines: [ShoppingLine] {
        struct Need { var name: String; var amounts: [String: Double]; var recipeIDs: [String] }
        var needs: [String: Need] = [:]
        for plan in activeRecipePlans {
            guard let recipe = plan.recipe else { continue }
            for name in recipe.ingredients {
                guard let amount = recipe.amount(for: name, servings: plan.servings) else { continue }
                let key = Recipe.ingredientKey(name)
                var need = needs[key] ?? Need(name: name, amounts: [:], recipeIDs: [])
                need.amounts[amount.dimension, default: 0] += amount.baseValue
                if !need.recipeIDs.contains(recipe.id) { need.recipeIDs.append(recipe.id) }
                needs[key] = need
            }
        }
        var lines: [String: ShoppingLine] = [:]
        for (key, need) in needs {
            let stocks = inventory.filter { Recipe.ingredientKey($0.recipeName ?? $0.name) == key }
            var missing: [StockAmount] = []
            for (dimension, total) in need.amounts.sorted(by: { $0.key < $1.key }) {
                let known = stocks.compactMap { StockAmount.parse($0.quantity) }
                let ambiguous = stocks.contains { stock in
                    guard let parsed = StockAmount.parse(stock.quantity) else { return true }
                    return parsed.value > 0 && parsed.dimension != dimension
                }
                let available = known.filter { $0.dimension == dimension }.reduce(0) { $0 + $1.baseValue }
                // Unknown stock is not presumed empty. A review notice appears in the plan.
                let shortfall = ambiguous ? 0 : max(0, total - available)
                if shortfall > 0.000001 {
                    missing.append(StockAmount(value: shortfall, unit: dimension == "mass" ? "g" : dimension == "volume" ? "ml" : dimension))
                }
            }
            if !missing.isEmpty {
                lines[key] = ShoppingLine(id: key, name: need.name, amounts: missing, recipeIDs: need.recipeIDs, manualIDs: [], manualUnspecified: false)
            }
        }
        for item in shopping {
            let key = Recipe.ingredientKey(item.name)
            var line = lines[key] ?? ShoppingLine(id: key, name: item.name, amounts: [], recipeIDs: [], manualIDs: [], manualUnspecified: false)
            line.manualIDs.append(item.id)
            if let amount = StockAmount.parse(item.quantity ?? ""), amount.value > 0 {
                if let index = line.amounts.firstIndex(where: { $0.dimension == amount.dimension }) {
                    line.amounts[index].value += amount.converted(to: line.amounts[index].unit)
                } else { line.amounts.append(amount) }
            } else { line.manualUnspecified = true }
            lines[key] = line
        }
        return lines.values.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    func isChecked(_ line: ShoppingLine) -> Bool {
        let manualChecked = line.manualIDs.allSatisfy { id in shopping.first { $0.id == id }?.checked == true }
        return manualChecked && (line.recipeIDs.isEmpty || recipeShoppingChecks?[line.id] == line.signature)
    }
    mutating func toggleShopping(_ line: ShoppingLine) {
        let checked = !isChecked(line)
        for id in line.manualIDs {
            if let index = shopping.firstIndex(where: { $0.id == id }) { shopping[index].checked = checked }
        }
        if !line.recipeIDs.isEmpty {
            if recipeShoppingChecks == nil { recipeShoppingChecks = [:] }
            recipeShoppingChecks?[line.id] = checked ? line.signature : nil
        }
    }
    mutating func addShoppingItem(name: String, quantity: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        addShopping([clean])
        if let index = shopping.firstIndex(where: { Recipe.ingredientKey($0.name) == Recipe.ingredientKey(clean) }) {
            shopping[index].quantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : quantity
        }
    }
    mutating func transferPurchases(_ drafts: [PurchaseDraft]) throws {
        guard !drafts.isEmpty, Set(drafts.map(\.id)).count == drafts.count else { throw KitchenError.invalid("Alınan ürünleri kontrol et.") }
        let current = shoppingLines
        var updated = inventory
        for draft in drafts {
            guard let line = current.first(where: { $0.id == draft.id }), line.signature == draft.line.signature, isChecked(line) else {
                throw KitchenError.invalid("Liste değişti. Ekranı kapatıp alınanları tekrar kontrol et.")
            }
            guard let purchased = StockAmount.parse(draft.quantity), purchased.value > 0 else {
                throw KitchenError.invalid("\(line.name): aldığın miktarı ör. 500 g veya 2 adet olarak gir.")
            }
            if let index = updated.firstIndex(where: { Recipe.ingredientKey($0.recipeName ?? $0.name) == line.id }) {
                if let old = StockAmount.parse(updated[index].quantity), old.dimension == purchased.dimension {
                    updated[index].quantity = StockAmount(value: old.value + purchased.converted(to: old.unit), unit: old.unit).text
                } else if StockAmount.parse(updated[index].quantity)?.value == 0 {
                    updated[index].quantity = purchased.text
                } else { updated[index].quantity += "; alınan +\(purchased.text)" }
            } else {
                updated.append(Ingredient(name: line.name, quantity: purchased.text, location: draft.location))
            }
        }
        inventory = updated
        let ids = Set(drafts.flatMap { $0.line.manualIDs })
        shopping.removeAll { ids.contains($0.id) }
        for draft in drafts { recipeShoppingChecks?[draft.id] = nil }
    }

    func leftoverUse(on day: String, slot: MealSlot) -> LeftoverUse? {
        leftoverUses?.last { !$0.undone && $0.day == day && $0.slot == slot.rawValue }
    }
    mutating func eatPrepared(_ id: UUID, portions: Int, day: String, slot: MealSlot) throws {
        guard cooking(on: day, slot: slot) == nil, leftoverUse(on: day, slot: slot) == nil,
              !completed[day, default: []].contains(slot.rawValue) else { throw KitchenError.invalid("Bu öğün zaten tamamlandı.") }
        guard portions > 0, let index = preparedMeals?.firstIndex(where: { $0.id == id }), let meal = preparedMeals?[index], meal.remaining >= portions else {
            throw KitchenError.invalid("Bu yemekten yeterli porsiyon kalmadı.")
        }
        preparedMeals?[index].remaining -= portions
        if leftoverUses == nil { leftoverUses = [] }
        leftoverUses?.append(LeftoverUse(preparedID: id, day: day, slot: slot.rawValue, portions: portions))
        completed[day, default: []].insert(slot.rawValue)
    }
    mutating func undoPreparedUse(_ id: UUID) throws {
        guard let index = leftoverUses?.firstIndex(where: { $0.id == id && !$0.undone }), let use = leftoverUses?[index],
              let mealIndex = preparedMeals?.firstIndex(where: { $0.id == use.preparedID }) else { throw KitchenError.invalid("Geri alınacak hazır yemek kaydı bulunamadı.") }
        preparedMeals?[mealIndex].remaining += use.portions
        leftoverUses?[index].undone = true
        completed[use.day, default: []].remove(use.slot)
    }
}
