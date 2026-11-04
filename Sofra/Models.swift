import Foundation

enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case fridge = "Buzdolabı"
    case pantry = "Kiler"
    case freezer = "Dondurucu"
    var id: String { rawValue }

    static func suggested(for name: String) -> StorageLocation {
        let key = Recipe.ingredientKey(name)
        if ["Yumurta", "Yoğurt", "Domates", "Salatalık", "Süt", "Peynir", "Krema", "Ispanak", "Mantar", "Tavuk", "Dana kıyma"].contains(where: { Recipe.ingredientKey($0) == key }) {
            return .fridge
        }
        return .pantry
    }
}

struct Ingredient: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var quantity: String
    var location: StorageLocation
    var recipeName: String? = nil

    init(id: UUID = UUID(), name: String, quantity: String, location: StorageLocation? = nil) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.location = location ?? .suggested(for: name)
    }

    private enum CodingKeys: String, CodingKey { case id, name, quantity, location, recipeName }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        quantity = try values.decode(String.self, forKey: .quantity)
        location = try values.decodeIfPresent(StorageLocation.self, forKey: .location) ?? .suggested(for: name)
        recipeName = try values.decodeIfPresent(String.self, forKey: .recipeName)
    }
}

struct ShoppingItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var checked = false
    var quantity: String? = nil
}

struct Recipe: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let minutes: Int
    let ingredients: [String]
    let steps: [String]
    var customAmounts: [String: StockAmount]? = nil

    func missing(in inventory: [Ingredient]) -> [String] {
        return missing(available: Set(inventory.filter { StockAmount.parse($0.quantity)?.value != 0 }.map { Self.ingredientKey($0.recipeName ?? $0.name) }))
    }

    static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
            .lowercased(with: Locale(identifier: "tr_TR"))
    }

    static let all = [
        Recipe(id: "bowl", name: "Nohutlu öğle kasesi", minutes: 15,
               ingredients: ["Nohut", "Domates", "Salatalık", "Zeytinyağı"],
               steps: ["Haşlanmış nohudu süz ve durula.", "Domates ve salatalığı doğra.", "Hepsini zeytinyağıyla karıştır. Soğuk servis et."]),
        Recipe(id: "eggs", name: "Domatesli yumurta", minutes: 12,
               ingredients: ["Yumurta", "Domates", "Zeytinyağı"],
               steps: ["Domatesleri doğrayıp zeytinyağında yumuşat.", "Yumurtaları ekle ve karıştır.", "Yumurtalar tamamen pişince servis et."]),
        Recipe(id: "yogurt", name: "Yoğurtlu yulaf", minutes: 5,
               ingredients: ["Yoğurt", "Yulaf", "Muz"],
               steps: ["Yoğurt ve yulafı bir kasede karıştır.", "Dilimlenmiş muzu üzerine ekle."]),
        Recipe(id: "pasta", name: "Domatesli makarna", minutes: 20,
               ingredients: ["Makarna", "Domates", "Zeytinyağı"],
               steps: ["Makarnayı paketindeki süreye göre haşla.", "Doğranmış domatesleri zeytinyağında pişir.", "Makarnayı süzüp sosla karıştır."]),
        Recipe(id: "salad", name: "Domatesli salatalık salatası", minutes: 8,
               ingredients: ["Domates", "Salatalık", "Zeytinyağı"],
               steps: ["Domates ve salatalığı yıkayıp doğra.", "Zeytinyağı ekleyip karıştır."]),
        Recipe(id: "potato", name: "Patatesli yumurta", minutes: 25,
               ingredients: ["Patates", "Yumurta", "Zeytinyağı"],
               steps: ["Patatesleri soyup küçük küpler halinde doğra.", "Zeytinyağında, ara sıra karıştırarak içi yumuşayana kadar pişir.", "Yumurtaları ekle, tamamen pişene kadar karıştır."]),
        Recipe(id: "tuna", name: "Ton balıklı marul salatası", minutes: 10,
               ingredients: ["Ton balığı", "Iceberg marul", "Domates", "Zeytinyağı"],
               steps: ["Marul ve domatesi yıkayıp doğra.", "Konserve ton balığını süzüp sebzelere ekle.", "Zeytinyağıyla karıştırıp servis et."]),
        Recipe(id: "carrot", name: "Yoğurtlu havuç", minutes: 15,
               ingredients: ["Havuç", "Yoğurt", "Zeytinyağı"],
               steps: ["Havucu yıkayıp rendele.", "Zeytinyağında yumuşayana kadar pişir ve soğumaya bırak.", "Soğuyan havucu yoğurtla karıştır."])
    ] + RecipeCatalog.additional
}

enum LunchPlace: String, Codable, CaseIterable, Identifiable {
    case prep = "Lamaces · evden hazırlık"
    case lidl = "Lamaces · Lidl"
    case cafeteria = "Sequira · yemekhane"
    case home = "Ev · evden çalışma"
    var id: String { rawValue }
    var suggestion: String {
        switch self {
        case .prep: "Nohutlu öğle kasesi"
        case .lidl: "Sandviç, yoğurt ve meyve"
        case .cafeteria: "Menüyü yerinde seç"
        case .home: "Mutfaktakilerle öğle yemeği"
        }
    }
}

struct LunchPlan: Codable {
    var date: String
    var place: LunchPlace
    var meal: String
    var note: String
}

struct AppData: Codable {
    var inventory = [Ingredient(name: "Yumurta", quantity: "4 adet"),
                     Ingredient(name: "Domates", quantity: "3 adet"),
                     Ingredient(name: "Yoğurt", quantity: "1 kase"),
                     Ingredient(name: "Zeytinyağı", quantity: "1 şişe")]
    var shopping: [ShoppingItem] = []
    var lunches: [String: LunchPlan] = [:]
    var water: [String: Int] = [:]
    var completed: [String: Set<String>] = [:]
    var dayMeals: [String: [String: DayMeal]]? = nil
    var cookingHistory: [CookingRecord]? = nil
    var recipePlans: [RecipePlan]? = nil
    var recipeShoppingChecks: [String: String]? = nil
    var preparedMeals: [PreparedMeal]? = nil
    var leftoverUses: [LeftoverUse]? = nil
    var lunchContexts: [String: LunchPlace]? = nil
    var dailyRecipeLinks: [String: DailyRecipeLink]? = nil
    var customRecipes: [Recipe]? = nil

    static func dayKey(_ date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    mutating func addShopping(_ names: [String]) {
        for name in names {
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            if let index = shopping.firstIndex(where: { Recipe.key($0.name) == Recipe.key(clean) }) {
                shopping[index].checked = false
            } else {
                shopping.append(ShoppingItem(name: clean))
            }
        }
    }
}

struct ReceiptItem: Identifiable {
    let id = UUID()
    var source: String
    var name: String
    var quantity: String
    var location: StorageLocation
    var selected: Bool
    var translated: Bool
    var canonicalName: String? = nil
}

/// A deliberately bounded Portuguese grocery vocabulary. Unmapped rows require review.
enum ReceiptParser {
    private struct Product {
        let prefix: String
        let name: String
        let location: StorageLocation
        var quantity = ""
    }
    private static let products: [Product] = [
        Product(prefix: "MAIZENA AMIDO DE MILHO", name: "Mısır nişastası", location: .pantry),
        Product(prefix: "ALFACE ICEBERG", name: "Iceberg marul", location: .fridge, quantity: "1 adet"),
        Product(prefix: "MILHO DOCE", name: "Tatlı mısır", location: .pantry),
        Product(prefix: "ATUM EM AZEITE PACK 4", name: "Ton balığı", location: .pantry, quantity: "4’lü paket"),
        Product(prefix: "ATUM", name: "Ton balığı", location: .pantry),
        Product(prefix: "CREME FRAICHE", name: "Krema (crème fraîche)", location: .fridge),
        Product(prefix: "QUEIJO RALADO", name: "Rendelenmiş peynir", location: .fridge),
        Product(prefix: "IOGURTE", name: "Yoğurt", location: .fridge),
        Product(prefix: "LEITE MEIO GORDO", name: "Yarım yağlı süt", location: .fridge),
        Product(prefix: "OVOS", name: "Yumurta", location: .fridge),
        Product(prefix: "MOLHO DE SOJA", name: "Soya sosu", location: .pantry),
        Product(prefix: "SHANDY", name: "Shandy içeceği", location: .pantry),
        Product(prefix: "CARNE PICADA DE BOVINO", name: "Dana kıyma", location: .fridge),
        Product(prefix: "CREME BRULEE", name: "Crème brûlée", location: .fridge),
        Product(prefix: "CEBOLA DOCE", name: "Tatlı soğan", location: .pantry),
        Product(prefix: "TOMATE", name: "Domates", location: .fridge),
        Product(prefix: "CENOURA", name: "Havuç", location: .fridge),
        Product(prefix: "BATATA CONSERVACAO VERMELHA", name: "Kırmızı patates", location: .pantry),
        Product(prefix: "BATATA", name: "Patates", location: .pantry),
        Product(prefix: "ALHO", name: "Sarımsak", location: .pantry),
        Product(prefix: "PEPINO", name: "Salatalık", location: .fridge),
        Product(prefix: "ABACATE", name: "Avokado", location: .pantry),
        Product(prefix: "MANGA", name: "Mango", location: .pantry),
        Product(prefix: "BANANA", name: "Muz", location: .pantry),
        Product(prefix: "AZEITE", name: "Zeytinyağı", location: .pantry),
        Product(prefix: "GRAO DE BICO", name: "Nohut", location: .pantry),
        Product(prefix: "ARROZ", name: "Pirinç", location: .pantry),
        Product(prefix: "MASSA", name: "Makarna", location: .pantry),
        Product(prefix: "AVEIA", name: "Yulaf", location: .pantry)
    ]

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_PT"))
            .uppercased().replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ text: String) -> [ReceiptItem] {
        var result: [ReceiptItem] = []
        var lastProduct: Int?
        for raw in text.components(separatedBy: .newlines) {
            let line = normalized(raw)
            guard !line.isEmpty else { continue }
            if let range = line.range(of: #"^\d+(?:[,.]\d+)?\s*(?:KG|G|ML|L)\b"#, options: .regularExpression) {
                if let index = lastProduct { result[index].quantity = String(line[range]).lowercased() }
                lastProduct = nil
                continue
            }
            let ignored = ["PROMOCAO", "DESCONTO", "DEPOSITO", "TOTAL", "SUBTOTAL", "IVA", "NIF", "PIJAMA", "PAGAMENTO", "MULTIBANCO", "TROCO", "CARTAO", "EURO", "EUR/", "LIDL PLUS"]
            if ignored.contains(where: { line.contains($0) }) {
                lastProduct = nil
                continue
            }
            let pricePattern = #"\s*-?\d+[,.]\d{2}\s*[A-F]?\s*$"#
            let hasPrice = line.range(of: pricePattern, options: .regularExpression) != nil
            let source = line.replacingOccurrences(of: pricePattern, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            let match = products.first { source == $0.prefix || source.hasPrefix($0.prefix + " ") }
            guard !source.isEmpty, match != nil || hasPrice,
                  source.range(of: #"[A-Z]{3}"#, options: .regularExpression) != nil else {
                lastProduct = nil
                continue
            }
            let originalSource = raw.replacingOccurrences(of: pricePattern, with: "", options: [.regularExpression, .caseInsensitive]).trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(ReceiptItem(source: originalSource, name: match?.name ?? source,
                                      quantity: match?.quantity ?? "", location: match?.location ?? .pantry,
                                      selected: match != nil, translated: match != nil, canonicalName: match?.name))
            lastProduct = result.count - 1
        }
        return result
    }
}

extension AppData {
    /// Existing stock is kept; receipt quantities are shown as a separate addition, never guessed or summed.
    mutating func importReceipt(_ items: [ReceiptItem]) {
        for item in items where item.selected {
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let quantity = item.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
            if let index = inventory.firstIndex(where: { Recipe.key($0.recipeName ?? $0.name) == Recipe.key(item.canonicalName ?? name) }) {
                let addition = quantity.isEmpty ? "fişten alındı, miktarı kontrol et" : "fişten +\(quantity)"
                inventory[index].quantity = inventory[index].quantity.isEmpty ? addition : inventory[index].quantity + "; " + addition
                // Keep the user's existing storage choice.
            } else {
                var stock = Ingredient(name: name, quantity: quantity.isEmpty ? "Miktarı kontrol et" : quantity, location: item.location)
                stock.recipeName = item.canonicalName
                inventory.append(stock)
            }
        }
    }
}


enum MealSlot: String, CaseIterable, Identifiable, Codable {
    case breakfast, lunch, dinner
    var id: String { rawValue }
    var title: String {
        switch self { case .breakfast: "Kahvaltı"; case .lunch: "Öğle arası"; case .dinner: "Akşam yemeği" }
    }
    var time: String {
        switch self { case .breakfast: "08:45"; case .lunch: "13:00"; case .dinner: "19:30" }
    }
    var icon: String {
        switch self { case .breakfast: "sunrise"; case .lunch: "fork.knife"; case .dinner: "moon" }
    }
}

struct DayMeal: Codable {
    var time: String
    var dish: String
    var note: String
    var recipeID: String?
    var preparedID: UUID? = nil
    var source: MealOrigin? = nil
    var servings: Int? = nil
    var personalRecipe: Recipe? = nil
    var recipe: Recipe? { guard preparedID == nil, source != .outside else { return nil }; return personalRecipe ?? Recipe.all.first { $0.id == recipeID || Recipe.key($0.name) == Recipe.key(dish) } }
}

struct StockAmount: Equatable, Codable {
    var value: Double
    var unit: String
    var dimension: String {
        switch unit { case "kg", "g": "mass"; case "l", "ml": "volume"; default: unit }
    }
    var baseValue: Double { value * (["kg", "l"].contains(unit) ? 1000 : 1) }
    func converted(to target: String) -> Double { baseValue / (["kg", "l"].contains(target) ? 1000 : 1) }
    var text: String {
        String(format: "%.3f", value).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: ".", with: ",") + " " + unit
    }
    private static let amountRegex = try! NSRegularExpression(pattern: #"^(\d+(?:[.,]\d+)?)\s*(kg|g|gr|gram|ml|l|lt|litre|adet|kase|paket|şişe|kap|dilim|diş)?$"#)
    static func parse(_ text: String) -> StockAmount? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let match = amountRegex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
              let numberRange = Range(match.range(at: 1), in: normalized),
              let value = Double(normalized[numberRange].replacingOccurrences(of: ",", with: ".")), value.isFinite else { return nil }
        let rawUnit = Range(match.range(at: 2), in: normalized).map { String(normalized[$0]) } ?? "adet"
        let unit = ["gr": "g", "gram": "g", "lt": "l", "litre": "l"][rawUnit] ?? rawUnit
        return StockAmount(value: value, unit: unit)
    }
}

struct UsageDraft: Identifiable {
    var id: UUID { ingredientID }
    let ingredientID: UUID
    let name: String
    let original: String
    var available: String
    var used: String
    var selected: Bool
}

struct CookingRecord: Identifiable, Codable {
    let id: UUID
    let dish: String
    let day: String?
    let slot: String?
    let before: [Ingredient]
    let after: [Ingredient]
    var undone = false
    var planBefore: RecipePlan? = nil
    var planRemaining: Int? = nil
    var preparedID: UUID? = nil
}

enum KitchenError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}

extension Recipe {
    /// Suggested quantities for one serving, editable before cooking.
    func suggestedUse(for name: String) -> String {
        return amount(for: name)?.text ?? ""
    }
}

extension AppData {
    func meal(on day: String, slot: MealSlot) -> DayMeal {
        if let stored = dayMeals?[day]?[slot.rawValue] { return stored }
        if slot == .lunch, let lunch = lunches[day] {
            return DayMeal(time: slot.time, dish: lunch.meal, note: lunch.note, recipeID: nil, source: lunch.place == .lidl || lunch.place == .cafeteria ? .outside : .recipe)
        }
        return DayMeal(time: slot.time, dish: "", note: "", recipeID: nil)
    }
    mutating func updateMeal(_ meal: DayMeal, day: String, slot: MealSlot) {
        if dayMeals == nil { dayMeals = [:] }
        dayMeals?[day, default: [:]][slot.rawValue] = meal
        linkMealShopping(meal, day: day, slot: slot)
    }
    func cooking(on day: String, slot: MealSlot) -> CookingRecord? {
        cookingHistory?.last { !$0.undone && $0.day == day && $0.slot == slot.rawValue }
    }
    func usage(for recipe: Recipe?, servings: Int = 1) -> [UsageDraft] {
        let stocks = recipe.map { recipe in inventory.filter { stock in recipe.ingredients.contains { Recipe.ingredientKey($0) == Recipe.ingredientKey(stock.recipeName ?? stock.name) } } } ?? inventory
        return stocks.map { stock in
            UsageDraft(ingredientID: stock.id, name: stock.name, original: stock.quantity,
                       available: stock.quantity, used: recipe?.amount(for: stock.recipeName ?? stock.name, servings: servings)?.text ?? "", selected: recipe != nil)
        }
    }
    mutating func cook(id: UUID, dish: String, drafts: [UsageDraft], day: String? = nil, slot: MealSlot? = nil, recipeID: String? = nil, servings: Int = 1, eatenNow: Int = 1) throws {
        guard !(cookingHistory ?? []).contains(where: { $0.id == id }) else { throw KitchenError.invalid("Bu pişirme zaten kaydedildi.") }
        guard (day == nil) == (slot == nil) else { throw KitchenError.invalid("Öğün günü ve türünü birlikte seç.") }
        if let day, let slot, cooking(on: day, slot: slot) != nil || leftoverUse(on: day, slot: slot) != nil || completed[day, default: []].contains(slot.rawValue) { throw KitchenError.invalid("Bu öğün zaten tamamlandı.") }
        guard (1...8).contains(servings), (0...servings).contains(eatenNow), day == nil || eatenNow > 0 else { throw KitchenError.invalid("Pişen ve yenen porsiyonları kontrol et.") }
        let selected = drafts.filter(\.selected)
        guard !selected.isEmpty else { throw KitchenError.invalid("Kullandığın en az bir malzemeyi seç.") }
        guard Set(selected.map(\.ingredientID)).count == selected.count else { throw KitchenError.invalid("Aynı malzeme birden fazla seçilmiş.") }
        var updates: [Ingredient] = []
        var previous: [Ingredient] = []
        for draft in selected {
            guard let stock = inventory.first(where: { $0.id == draft.ingredientID }), stock.quantity == draft.original else {
                throw KitchenError.invalid("Stok değişmiş. Ekranı kapatıp yeniden aç.")
            }
            guard let available = StockAmount.parse(draft.available), let used = StockAmount.parse(draft.used), used.value > 0 else {
                throw KitchenError.invalid("\(draft.name): stok ve kullanım miktarını ör. 500 g veya 2 adet olarak gir.")
            }
            guard available.dimension == used.dimension else {
                throw KitchenError.invalid("\(draft.name): birimler uyumlu olmalı. Ör. şişe yerine stok miktarını ml olarak belirt.")
            }
            guard available.baseValue + 0.000001 >= used.baseValue else { throw KitchenError.invalid("\(draft.name): stokta yeterli miktar yok.") }
            previous.append(stock)
            var updated = stock
            updated.quantity = StockAmount(value: max(0, available.value - used.converted(to: available.unit)), unit: available.unit).text
            updates.append(updated)
        }
        // Validate everything first; a failure must not partially consume the inventory.
        for updated in updates { if let index = inventory.firstIndex(where: { $0.id == updated.id }) { inventory[index] = updated } }
        if cookingHistory == nil { cookingHistory = [] }
        var record = CookingRecord(id: id, dish: dish, day: day, slot: slot?.rawValue, before: previous, after: updates)
        if let recipeID, let plan = recipePlans?.first(where: { $0.recipeID == recipeID }) {
            record.planBefore = plan
            record.planRemaining = max(0, plan.servings - servings)
            if plan.servings <= servings { recipePlans?.removeAll { $0.recipeID == recipeID } }
            else if let recipe = plan.recipe { setRecipePlan(recipe, servings: plan.servings - servings) }
        }
        if servings > eatenNow {
            let ready = PreparedMeal(dish: dish, recipeID: recipeID, initialPortions: servings - eatenNow, remaining: servings - eatenNow)
            if preparedMeals == nil { preparedMeals = [] }
            preparedMeals?.append(ready)
            record.preparedID = ready.id
        }
        cookingHistory?.append(record)
        if let day, let slot { completed[day, default: []].insert(slot.rawValue) }
    }
    mutating func undoCooking(_ id: UUID) throws {
        guard let index = cookingHistory?.firstIndex(where: { $0.id == id && !$0.undone }), let record = cookingHistory?[index] else {
            throw KitchenError.invalid("Geri alınacak pişirme bulunamadı.")
        }
        if let readyID = record.preparedID {
            guard let ready = preparedMeals?.first(where: { $0.id == readyID }), ready.remaining == ready.initialPortions,
                  !(leftoverUses ?? []).contains(where: { $0.preparedID == readyID && !$0.undone }) else {
                throw KitchenError.invalid("Kalan yemekten yenmiş. Önce o öğünleri geri al.")
            }
        }
        if let plan = record.planBefore {
            let current = recipePlans?.first { $0.recipeID == plan.recipeID }?.servings ?? 0
            guard current == record.planRemaining else { throw KitchenError.invalid("Pişirme planı sonradan değişti. Mutfak stoklarını elle kontrol et.") }
        }
        for after in record.after {
            guard inventory.contains(where: { $0.id == after.id && $0.quantity == after.quantity }) else {
                throw KitchenError.invalid("Bu malzemelerin stoku sonradan değişti. Mutfaktan miktarlarını düzenle.")
            }
        }
        for before in record.before {
            if let stockIndex = inventory.firstIndex(where: { $0.id == before.id }) { inventory[stockIndex].quantity = before.quantity }
        }
        if let readyID = record.preparedID { preparedMeals?.removeAll { $0.id == readyID } }
        if let plan = record.planBefore, let recipe = plan.recipe { setRecipePlan(recipe, servings: plan.servings) }
        cookingHistory?[index].undone = true
        if let day = record.day, let slot = record.slot { completed[day, default: []].remove(slot) }
    }
}
