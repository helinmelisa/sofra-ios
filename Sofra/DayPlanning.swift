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
