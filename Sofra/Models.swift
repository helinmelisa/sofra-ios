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
    ]
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
            result.append(ReceiptItem(source: source, name: match?.name ?? source,
                                      quantity: match?.quantity ?? "", location: match?.location ?? .pantry,
                                      selected: match != nil, translated: match != nil))
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
            if let index = inventory.firstIndex(where: { Recipe.key($0.name) == Recipe.key(name) }) {
                let addition = quantity.isEmpty ? "fişten alındı, miktarı kontrol et" : "fişten +\(quantity)"
                inventory[index].quantity = inventory[index].quantity.isEmpty ? addition : inventory[index].quantity + "; " + addition
                // Keep the user's existing storage choice.
            } else {
                inventory.append(Ingredient(name: name, quantity: quantity.isEmpty ? "Miktarı kontrol et" : quantity, location: item.location))
            }
        }
    }
}
