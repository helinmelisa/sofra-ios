import SwiftUI

enum Ink {
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let dark = Color(red: 0.19, green: 0.24, blue: 0.20)
    static let rust = Color(red: 0.67, green: 0.28, blue: 0.17)
}

struct RootView: View {
    @EnvironmentObject private var store: FoodStore
    var body: some View {
        TabView {
            MyDayView().tabItem { Label("Günüm", systemImage: "sun.max") }
            NavigationStack { RecipeListView() }.tabItem { Label("Tarifler", systemImage: "book.closed") }
            KitchenView().tabItem { Label("Mutfak", systemImage: "carrot") }
            ShoppingView().tabItem { Label("Alışveriş", systemImage: "basket") }
        }
        .tint(Ink.dark)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = store.saveError {
                Text(error).font(.caption).padding().frame(maxWidth: .infinity)
                    .background(.yellow.opacity(0.3)).accessibilityAddTraits(.isStaticText)
            }
        }
    }
}

struct Journal<Content: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Text("sofra").font(.system(.headline, design: .serif)).tracking(4)
                        Spacer()
                        Text(eyebrow).font(.caption).tracking(2)
                    }
                    .padding(.top, 18)
                    Text(title).font(.system(size: 46, weight: .regular, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    content
                }.padding(.horizontal, 26).padding(.bottom, 32)
            }
            .background(Ink.paper).foregroundStyle(Ink.dark)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct Caption: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Ink.rust)
    }
}

struct KitchenView: View {
    @EnvironmentObject private var store: FoodStore
    @State private var name = ""
    @State private var quantity = ""
    @State private var location: StorageLocation = .fridge
    @State private var showingAdd = false
    @State private var showingReceipt = false
    @State private var editingStock: Ingredient?
    private var visibleIngredients: [Ingredient] {
        store.data.inventory.filter { $0.location == location }
    }
    var body: some View {
        Journal(eyebrow: "Eldekilerle iyi yemek", title: "Mutfakta\nne var?") {
            Picker("Saklama alanı", selection: $location) {
                ForEach(StorageLocation.allCases) { area in
                    Text(area.rawValue).tag(area)
                }
            }.pickerStyle(.segmented)
            Button { showingReceipt = true } label: {
                Label("Fişten mutfağa ekle", systemImage: "doc.text.viewfinder")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.bordered)
            HStack {
                Caption(text: "\(location.rawValue) · \(visibleIngredients.count) malzeme")
                Spacer()
                Button { showingAdd = true } label: {
                    Label("Ekle", systemImage: "plus").padding(.vertical, 8)
                }
            }
            if visibleIngredients.isEmpty {
                Text("Burada henüz malzeme yok. Ekle’ye dokunarak başlayabilirsin.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(visibleIngredients) { ingredient in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ingredient.name).font(.system(.title3, design: .serif))
                        Text(ingredient.quantity).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        Button("Miktarı düzenle") { editingStock = ingredient }
                        ForEach(StorageLocation.allCases.filter { $0 != ingredient.location }) { area in
                            Button("\(area.rawValue) bölümüne taşı") {
                                if let index = store.data.inventory.firstIndex(where: { $0.id == ingredient.id }) {
                                    store.data.inventory[index].location = area
                                }
                            }
                        }
                        Button("Kaldır", role: .destructive) {
                            store.data.inventory.removeAll { $0.id == ingredient.id }
                        }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    }.accessibilityLabel("\(ingredient.name) seçenekleri")
                }
                Divider()
            }
            NavigationLink {
                RecipeListView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Caption(text: "Bunlarla pişirebilirsin")
                        Text("Tüm mutfağından tarifler").font(.system(.title3, design: .serif))
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                }.padding(.vertical, 14)
            }.buttonStyle(.plain)
        }
        .sheet(item: $editingStock) { StockEditSheet(stock: $0) }
        .sheet(isPresented: $showingReceipt) { ReceiptImportView() }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                Form {
                    TextField("Malzeme adı", text: $name)
                    TextField("Miktar · ör. 3 adet", text: $quantity)
                    Picker("Saklama alanı", selection: $location) {
                        ForEach(StorageLocation.allCases) { area in
                            Text(area.rawValue).tag(area)
                        }
                    }
                }
                .navigationTitle("Malzeme ekle")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Vazgeç") { showingAdd = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Ekle") { addIngredient(); showingAdd = false }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }.tint(Ink.dark)
        }
    }
    private func addIngredient() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = store.data.inventory.firstIndex(where: { Recipe.key($0.name) == Recipe.key(clean) }) {
            store.data.inventory[index].quantity = quantity
            store.data.inventory[index].location = location
        } else { store.data.inventory.append(Ingredient(name: clean, quantity: quantity, location: location)) }
        name = ""; quantity = ""
    }
}

struct RecipeDetail: View {
    @EnvironmentObject private var store: FoodStore
    let recipe: Recipe
    @State private var servings = 1
    @State private var planning = false
    @State private var cooking: CookingRequest?
    @State private var lastCookingID: UUID?
    @State private var stockError: String?
    private var missing: [String] { recipe.missing(in: store.data.inventory) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Caption(text: "Mutfaktan · \(recipe.minutes) dakika")
                Text(recipe.name).font(.system(size: 38, design: .serif))
                Stepper("\(servings) porsiyon", value: $servings, in: 1...8)
                ForEach(recipe.ingredients, id: \.self) { ingredient in
                    HStack {
                        Label(ingredient, systemImage: missing.contains(ingredient) ? "circle" : "checkmark.circle.fill")
                        Spacer()
                        Text(recipe.amount(for: ingredient, servings: servings)?.text ?? "").font(.caption)
                    }
                }
                Button("Pişirme planı ve alışveriş") { planning = true }
                    .buttonStyle(.bordered).tint(Ink.dark)
                Button("Pişirdim · stoktan düş") {
                    cooking = CookingRequest(dish: recipe.name, recipe: recipe, servings: servings)
                }.buttonStyle(.borderedProminent).tint(Ink.dark).foregroundStyle(.white)
                if let id = lastCookingID {
                    Button("Son stok düşümünü geri al") {
                        do { try store.data.undoCooking(id); lastCookingID = nil }
                        catch { stockError = error.localizedDescription }
                    }
                }
                Divider()
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 16) {
                        Text(String(format: "%02d", index + 1)).foregroundStyle(Ink.rust)
                        Text(step)
                    }
                }
                Text("Porsiyonu ihtiyacına göre ayarla. Alerjenleri ve malzeme miktarlarını pişirmeden önce kontrol et.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(26)
        }.background(Ink.paper).foregroundStyle(Ink.dark)
            .toolbar(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $planning) { RecipePlanSheet(recipe: recipe, initialServings: servings) }
            .onAppear { servings = min(8, store.data.activeRecipePlans.first { $0.recipeID == recipe.id }?.servings ?? 1) }
            .sheet(item: $cooking) { request in CookingSheet(request: request) { lastCookingID = $0 } }
            .alert("Stok güncellenemedi", isPresented: Binding(get: { stockError != nil }, set: { if !$0 { stockError = nil } })) {
                Button("Tamam") { stockError = nil }
            } message: { Text(stockError ?? "") }
    }
}
