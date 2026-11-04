import Foundation

enum MealOrigin: String, CaseIterable, Identifiable, Codable {
    case prepared = "Hazır", recipe = "Tarif", outside = "Dışarıdan"
    var id: String { rawValue }
}

struct DailyRecipeLink: Codable {
    var day: String
    var slot: String
    var recipeID: String
    var servings: Int
}

extension DayMeal {
    var origin: MealOrigin {
        if preparedID != nil { return .prepared }
        if let source { return source }
        return recipe == nil ? .outside : .recipe
    }
}

extension AppData {
    func lunchPlace(on day: String) -> LunchPlace { lunchContexts?[day] ?? lunches[day]?.place ?? .home }
    mutating func setLunchPlace(_ place: LunchPlace, day: String) {
        if lunchContexts == nil { lunchContexts = [:] }
        lunchContexts?[day] = place
    }
    var scheduledRecipePortions: [String: Int] {
        var counts: [String: Int] = [:]
        for link in dailyRecipeLinks?.values ?? Dictionary<String, DailyRecipeLink>().values {
            guard link.day >= Self.dayKey(), !completed[link.day, default: []].contains(link.slot) else { continue }
            counts[link.recipeID, default: 0] += link.servings
        }
        return counts
    }
    mutating func linkMealShopping(_ meal: DayMeal, day: String, slot: MealSlot) {
        if dailyRecipeLinks == nil { dailyRecipeLinks = [:] }
        let key = day + "/" + slot.rawValue
        if meal.origin == .recipe, let recipe = meal.recipe {
            dailyRecipeLinks?[key] = DailyRecipeLink(day: day, slot: slot.rawValue, recipeID: recipe.id, servings: min(8, max(1, meal.servings ?? 1)))
        } else { dailyRecipeLinks?[key] = nil }
    }
    mutating func selectMeal(_ meal: DayMeal, day: String, slot: MealSlot) throws {
        guard !completed[day, default: []].contains(slot.rawValue), cooking(on: day, slot: slot) == nil, leftoverUse(on: day, slot: slot) == nil else {
            throw KitchenError.invalid("Bu öğün tamamlandı. Yemeği değiştirmeden önce kaydı geri al.")
        }
        guard !meal.dish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw KitchenError.invalid("Yemek adını yaz veya bir yemek seç.") }
        if let id = meal.preparedID {
            guard readyMeals.contains(where: { $0.id == id }) else { throw KitchenError.invalid("Bu hazır yemekten porsiyon kalmadı.") }
        }
        updateMeal(meal, day: day, slot: slot)
    }
    mutating func markOutsideEaten(day: String, slot: MealSlot) throws {
        let item = meal(on: day, slot: slot)
        guard !item.dish.isEmpty, item.origin == .outside,
              !completed[day, default: []].contains(slot.rawValue) else { throw KitchenError.invalid("Kaydedilecek dışarıdan öğün bulunamadı.") }
        completed[day, default: []].insert(slot.rawValue)
    }
    mutating func undoMeal(day: String, slot: MealSlot) throws {
        if let cooked = cooking(on: day, slot: slot) { try undoCooking(cooked.id) }
        else if let used = leftoverUse(on: day, slot: slot) { try undoPreparedUse(used.id) }
        else { completed[day, default: []].remove(slot.rawValue) }
    }
    func featuredMeal(on date: Date) -> MealSlot? {
        let day = Self.dayKey(date)
        let pending = MealSlot.allCases.filter { !completed[day, default: []].contains($0.rawValue) }.sorted { meal(on: day, slot: $0).time < meal(on: day, slot: $1).time }
        guard !pending.isEmpty else { return nil }
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let now = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        func minutes(_ slot: MealSlot) -> Int {
            let parts = meal(on: day, slot: slot).time.split(separator: ":").compactMap { Int($0) }
            return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
        }
        if let due = pending.last(where: { !meal(on: day, slot: $0).dish.isEmpty && minutes($0) <= now && now - minutes($0) <= 180 }) { return due }
        return pending.first(where: { minutes($0) >= now }) ?? pending.last
    }
}

struct PersonalIngredient: Identifiable {
    var id = UUID()
    var name = ""
    var quantity = ""
}

struct RecipeMatch: Identifiable {
    var recipe: Recipe
    var missing: [String]
    var searchText: String
    var id: String { recipe.id }
}

extension Recipe {
    func missing(available: Set<String>) -> [String] { ingredients.filter { !available.contains(Self.ingredientKey($0)) } }
    static func personal(id: String? = nil, name: String, minutes: Int, portions: Int, ingredients: [PersonalIngredient], instructions: String) throws -> Recipe {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, (1...8).contains(portions), (1...480).contains(minutes), !ingredients.isEmpty else {
            throw KitchenError.invalid("Yemek adını, porsiyonu ve en az bir malzemeyi ekle.")
        }
        var names: [String] = []
        var amounts: [String: StockAmount] = [:]
        for ingredient in ingredients {
            let clean = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, var amount = StockAmount.parse(ingredient.quantity), amount.value > 0 else {
                throw KitchenError.invalid("Her malzemeye ad ve ör. 200 g veya 2 adet gibi bir miktar gir.")
            }
            let key = Self.ingredientKey(clean)
            guard amounts[key] == nil else { throw KitchenError.invalid("\(clean) iki kez eklenmiş. Miktarları tek satırda birleştir.") }
            amount.value /= Double(portions)
            names.append(clean)
            amounts[key] = amount
        }
        let steps = instructions.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return Recipe(id: id ?? "personal-" + UUID().uuidString, name: title, minutes: minutes, ingredients: names, steps: steps, customAmounts: amounts)
    }
}

extension AppData {
    var allRecipes: [Recipe] { Recipe.all + (customRecipes ?? []) }
    func recipe(withID id: String) -> Recipe? { allRecipes.first { $0.id == id } }
    mutating func savePersonalRecipe(_ recipe: Recipe) {
        if customRecipes == nil { customRecipes = [] }
        if let index = customRecipes?.firstIndex(where: { $0.id == recipe.id }) { customRecipes?[index] = recipe }
        else { customRecipes?.append(recipe) }
        if let plans = recipePlans {
            for (index, plan) in plans.enumerated() where plan.recipeID == recipe.id { recipePlans?[index].snapshot = recipe }
        }
        if var days = dayMeals {
            for day in Array(days.keys) where day >= Self.dayKey() {
                guard var slots = days[day] else { continue }
                for slot in Array(slots.keys) where !completed[day, default: []].contains(slot) {
                    guard var meal = slots[slot], meal.recipeID == recipe.id, meal.origin == .recipe else { continue }
                    meal.personalRecipe = recipe
                    meal.dish = recipe.name
                    slots[slot] = meal
                }
                days[day] = slots
            }
            dayMeals = days
        }
    }
    func matchedRecipes() -> [RecipeMatch] {
        let available = Set(inventory.filter { StockAmount.parse($0.quantity)?.value != 0 }.map { Recipe.ingredientKey($0.recipeName ?? $0.name) })
        return allRecipes.map { RecipeMatch(recipe: $0, missing: $0.missing(available: available), searchText: Recipe.key($0.name + " " + $0.ingredients.joined(separator: " "))) }
            .sorted { a, b in
                if a.missing.count != b.missing.count { return a.missing.count < b.missing.count }
                return a.recipe.minutes == b.recipe.minutes ? a.id < b.id : a.recipe.minutes < b.recipe.minutes
            }
    }
}
