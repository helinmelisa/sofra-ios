import Foundation

enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case fridge = "Buzdolabı"
    case pantry = "Kiler"
    case freezer = "Dondurucu"
    var id: String { rawValue }

    static func suggested(for name: String) -> StorageLocation {
        let key = Recipe.key(name)
        if ["Yumurta", "Yoğurt", "Domates", "Salatalık"].contains(where: { Recipe.key($0) == key }) {
            return .fridge
        }
        return .pantry
    }
}

struct Ingredient: Identifiable, Codable {
    var id: UUID
    var name: String
    var quantity: String
    var location: StorageLocation

    init(id: UUID = UUID(), name: String, quantity: String, location: StorageLocation? = nil) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.location = location ?? .suggested(for: name)
    }

    private enum CodingKeys: String, CodingKey { case id, name, quantity, location }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        quantity = try values.decode(String.self, forKey: .quantity)
        location = try values.decodeIfPresent(StorageLocation.self, forKey: .location) ?? .suggested(for: name)
    }
}

struct ShoppingItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var checked = false
}

struct Recipe: Identifiable {
    let id: String
    let name: String
    let minutes: Int
    let ingredients: [String]
    let steps: [String]

    func missing(in inventory: [Ingredient]) -> [String] {
        let available = Set(inventory.map { Self.key($0.name) })
        return ingredients.filter { !available.contains(Self.key($0)) }
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
               steps: ["Makarnayı paketindeki süreye göre haşla.", "Doğranmış domatesleri zeytinyağında pişir.", "Makarnayı süzüp sosla karıştır."])
    ]
}

enum LunchPlace: String, Codable, CaseIterable, Identifiable {
    case prep = "Lamaces · evden hazırlık"
    case lidl = "Lamaces · Lidl"
    case cafeteria = "Sequira · yemekhane"
    var id: String { rawValue }
    var suggestion: String {
        switch self {
        case .prep: "Nohutlu öğle kasesi"
        case .lidl: "Sandviç, yoğurt ve meyve"
        case .cafeteria: "Menüyü yerinde seç"
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
