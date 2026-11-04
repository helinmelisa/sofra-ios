import SwiftUI

struct RecipeListView: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAll = false
    @State private var category: RecipeCategory = .all
    @State private var search = ""
    @State private var planning: Recipe?
    var selectionLabel = "Yarının öğle yemeği olarak seç"
    var onSelect: ((Recipe) -> Void)? = nil

    private var recipes: [Recipe] {
        Recipe.all.filter { recipe in
            let query = Recipe.key(search)
            return (category == .all || recipe.category == category) &&
                (query.isEmpty || Recipe.key(recipe.name).contains(query) || recipe.ingredients.contains { Recipe.key($0).contains(query) }) &&
                (showAll || !query.isEmpty || recipe.missing(in: store.data.inventory).count <= 2)
        }.sorted {
            let a = $0.missing(in: store.data.inventory).count, b = $1.missing(in: store.data.inventory).count
            if a != b { return a < b }
            return $0.minutes == $1.minutes ? $0.id < $1.id : $0.minutes < $1.minutes
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                NavigationLink { RecipePlanView() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Caption(text: "Önce ne pişirelim?")
                            Text("Pişireceklerim").font(.system(.title2, design: .serif))
                            Text("\(store.data.activeRecipePlans.count) tarif · \(store.data.readyMeals.reduce(0) { $0 + $1.remaining }) hazır porsiyon")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                    }.padding(.vertical, 10)
                }.buttonStyle(.plain)
                TextField("Tarif veya malzeme ara", text: $search).textFieldStyle(.roundedBorder)
                Picker("Tarif görünümü", selection: $showAll) {
                    Text("Mutfaktan öneriler").tag(false)
                    Text("Tümü · \(Recipe.all.count)").tag(true)
                }.pickerStyle(.segmented)
                Picker("Tür", selection: $category) {
                    ForEach(RecipeCategory.allCases) { Text($0.rawValue).tag($0) }
                }
                if recipes.isEmpty {
                    ContentUnavailableView("Bu seçimde tarif yok", systemImage: "carrot", description: Text("Tüm tarifleri açabilir, aramanı değiştirebilir veya mutfağına malzeme ekleyebilirsin."))
                }
                let ready = recipes.filter { $0.missing(in: store.data.inventory).isEmpty }
                let missing = recipes.filter { !$0.missing(in: store.data.inventory).isEmpty }
                if !ready.isEmpty {
                    Caption(text: "Evdekilerle · \(ready.count) tarif")
                    ForEach(ready) { recipe in recipeRow(recipe) }
                }
                if !missing.isEmpty {
                    Caption(text: showAll || !search.isEmpty ? "Eksikleri tamamlayarak" : "1–2 eksiğin var")
                    ForEach(missing) { recipe in recipeRow(recipe) }
                }
                Text("Malzeme varlığına göre önerilir. Miktarları tarifte kontrol et. Planına eklediğinde hesaplanabilen eksikler alışverişe otomatik yansır.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(26)
        }.background(Ink.paper).foregroundStyle(Ink.dark)
            .toolbar(.visible, for: .navigationBar)
            .navigationTitle("Tarifler").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $planning) { RecipePlanSheet(recipe: $0) }
    }
    private func recipeRow(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                NavigationLink { RecipeDetail(recipe: recipe) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(recipe.minutes) DK · \(recipe.category.rawValue)").font(.caption).foregroundStyle(Ink.rust)
                        Text(recipe.name).font(.system(.title2, design: .serif))
                        let missing = recipe.missing(in: store.data.inventory)
                        Text(missing.isEmpty ? "Malzemeler mutfakta" : "Eksik: " + missing.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                Button { planning = recipe } label: {
                    Image(systemName: store.data.activeRecipePlans.contains(where: { $0.recipeID == recipe.id }) ? "checkmark.circle.fill" : "plus.circle")
                        .font(.title2).frame(width: 44, height: 44)
                }.accessibilityLabel("\(recipe.name) pişirme planı")
            }
            if let onSelect {
                Button(selectionLabel) { onSelect(recipe); dismiss() }.buttonStyle(.bordered)
            }
            Divider()
        }
    }
}

struct RecipePlanSheet: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    var initialServings = 1
    @State private var servings = 1
    private var preview: AppData {
        var data = store.data
        data.setRecipePlan(recipe, servings: servings)
        return data
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(recipe.name).font(.system(.title2, design: .serif))
                    Stepper("\(servings) porsiyon", value: $servings, in: 1...8)
                    Text("Kendin için bir öğün veya sonraki günlere de yetecek kadar hazırlayabilirsin.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Malzemeler · \(servings) porsiyon") {
                    ForEach(recipe.ingredients, id: \.self) { name in
                        LabeledContent(name, value: recipe.amount(for: name, servings: servings)?.text ?? "Miktarı kontrol et")
                    }
                }
                Section("Alışverişe otomatik yansıyacak") {
                    let lines = preview.shoppingLines.filter { $0.recipeIDs.contains(recipe.id) }
                    if lines.isEmpty { Text("Hesaplanan yeni eksik yok.") }
                    ForEach(lines) { line in
                        VStack(alignment: .leading, spacing: 5) {
                            LabeledContent(line.name, value: line.quantityText)
                            if line.recipeIDs.count > 1 { Text("Diğer planlı tariflerle toplam miktar").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    Text("Ortak malzemeler tek satırda toplanır; mutfaktaki uyumlu miktar yalnızca bir kez düşülür.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !preview.planStockWarnings.filter({ recipe.ingredients.contains($0) }).isEmpty {
                    Section("Mutfakta miktar kontrolü") {
                        Text(preview.planStockWarnings.filter { recipe.ingredients.contains($0) }.joined(separator: ", "))
                        Text("Bu ürünlerde miktar belirsiz veya birimler farklı. Mutfakta var sayıldı; ek alışveriş gerekip gerekmediğini kontrol et.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.navigationTitle("Pişirme planı").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Planı kaydet") { store.data.setRecipePlan(recipe, servings: servings); dismiss() }
                    }
                }
                .onAppear { servings = store.data.activeRecipePlans.first { $0.recipeID == recipe.id }?.servings ?? initialServings }
        }.tint(Ink.dark)
    }
}

struct RecipePlanView: View {
    @EnvironmentObject private var store: FoodStore
    @State private var schedule: PreparedMeal?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Önce ne\npişirelim?").font(.system(size: 38, design: .serif))
                Text("Porsiyon sayısını değiştirince eksikler alışverişte otomatik güncellenir.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if store.data.activeRecipePlans.isEmpty {
                    Text("Tariflerdeki + düğmesiyle pişireceklerini seç.").font(.system(.title3, design: .serif))
                }
                ForEach(store.data.activeRecipePlans) { plan in
                    if let recipe = plan.recipe {
                        VStack(alignment: .leading, spacing: 12) {
                            NavigationLink(recipe.name) { RecipeDetail(recipe: recipe) }.font(.system(.title2, design: .serif))
                            Stepper("\(plan.servings) porsiyon", value: Binding(get: {
                                store.data.activeRecipePlans.first { $0.id == plan.id }?.servings ?? 1
                            }, set: { store.data.setRecipePlan(recipe, servings: $0) }), in: min(8, max(1, store.data.scheduledRecipePortions[recipe.id] ?? 1))...max(8, plan.servings))
                            Button("Plandan çıkar", role: .destructive) { store.data.removeRecipePlan(plan.id) }.font(.caption)
                            Divider()
                        }
                    }
                }
                NavigationLink { ShoppingView(embedded: true) } label: {
                    Label("Alışverişi gör · \(store.data.shoppingLines.count) ürün", systemImage: "basket")
                }.buttonStyle(.borderedProminent).tint(Ink.dark).foregroundStyle(.white)
                if !store.data.planStockWarnings.isEmpty {
                    Text("Miktarını kontrol et: " + store.data.planStockWarnings.joined(separator: ", "))
                        .font(.caption).foregroundStyle(Ink.rust)
                }
                if !store.data.readyMeals.isEmpty {
                    Caption(text: "Hazır yemeklerin")
                    ForEach(store.data.readyMeals) { ready in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(ready.dish).font(.system(.title2, design: .serif))
                            Text("\(ready.remaining) porsiyon kaldı · \(ready.createdAt.formatted(.dateTime.day().month(.abbreviated)))")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Bir öğüne yerleştir") { schedule = ready }.buttonStyle(.bordered)
                            Divider()
                        }
                    }
                }
            }.padding(26)
        }.background(Ink.paper).foregroundStyle(Ink.dark)
            .navigationTitle("Pişireceklerim").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .sheet(item: $schedule) { PreparedScheduleSheet(meal: $0) }
    }
}

struct ShoppingView: View {
    @EnvironmentObject private var store: FoodStore
    @State private var grouped = false
    @State private var adding = false
    @State private var checkout = false
    var embedded = false
    private var lines: [ShoppingLine] { store.data.shoppingLines }
    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("\(lines.count) üründen \(lines.filter { store.data.isChecked($0) }.count) alındı")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { adding = true } label: { Label("Ürün ekle", systemImage: "plus") }
            }
            Picker("Liste görünümü", selection: $grouped) {
                Text("Malzemeler").tag(false)
                Text("Tarife göre").tag(true)
            }.pickerStyle(.segmented)
            if lines.isEmpty {
                Text("Şimdilik bir eksik yok. Tarifler bölümünden pişireceklerini seçebilir veya bir ürün ekleyebilirsin.")
                    .font(.system(.title3, design: .serif)).padding(.vertical, 20)
            }
            if !grouped {
                ForEach(lines) { shoppingRow($0) }
            } else {
                let shared = lines.filter { $0.recipeIDs.count > 1 }
                if !shared.isEmpty {
                    Caption(text: "Ortak malzemeler")
                    ForEach(shared) { shoppingRow($0) }
                }
                ForEach(store.data.activeRecipePlans) { plan in
                    let own = lines.filter { $0.recipeIDs == [plan.recipeID] }
                    if let recipe = plan.recipe, !own.isEmpty {
                        Text(recipe.name).font(.system(.title2, design: .serif))
                        ForEach(own) { shoppingRow($0) }
                    }
                }
                let manual = lines.filter { $0.recipeIDs.isEmpty }
                if !manual.isEmpty {
                    Caption(text: "Diğer ihtiyaçlar")
                    ForEach(manual) { shoppingRow($0) }
                }
            }
            if !store.data.planStockWarnings.isEmpty {
                Text("Mutfakta miktarını kontrol et: " + store.data.planStockWarnings.joined(separator: ", ") + ". Bu ürünler var sayıldı; ihtiyaç varsa elle ekleyebilirsin.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if lines.contains(where: { store.data.isChecked($0) }) {
                Button("Alınanları mutfağa taşı") { checkout = true }
                    .buttonStyle(.borderedProminent).tint(Ink.dark).foregroundStyle(.white)
            }
        }
    }
    var body: some View {
        Group {
            if embedded {
                ScrollView { bodyContent.padding(26) }.background(Ink.paper).foregroundStyle(Ink.dark)
                    .navigationTitle("Alışveriş").navigationBarTitleDisplayMode(.inline)
                    .toolbar(.visible, for: .navigationBar)
            } else {
                Journal(eyebrow: "Bir sonraki alışveriş", title: "Küçük\nbir liste.") { bodyContent }
            }
        }
        .sheet(isPresented: $adding) { AddShoppingSheet() }
        .sheet(isPresented: $checkout) { ShoppingTransferSheet() }
    }
    private func shoppingRow(_ line: ShoppingLine) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { store.data.toggleShopping(line) } label: {
                Image(systemName: store.data.isChecked(line) ? "checkmark.circle.fill" : "circle")
                    .font(.title2).frame(width: 44, height: 44)
            }.accessibilityLabel("\(line.name), \(store.data.isChecked(line) ? "alındı, geri al" : "alındı olarak işaretle")")
            VStack(alignment: .leading, spacing: 7) {
                Text(line.name).font(.system(.title3, design: .serif)).strikethrough(store.data.isChecked(line))
                Text(line.quantityText).font(.subheadline)
                let sources = line.recipeNames + (line.manualIDs.isEmpty ? [] : ["Elle eklendi"])
                Text(sources.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                if !line.manualIDs.isEmpty {
                    Button("Elle eklenen ihtiyacı kaldır", role: .destructive) { store.data.shopping.removeAll { line.manualIDs.contains($0.id) } }
                }
                ForEach(line.recipeIDs, id: \.self) { id in
                    if let recipe = Recipe.all.first(where: { $0.id == id }) {
                        Button("\(recipe.name) tarifini plandan çıkar", role: .destructive) { store.data.removeRecipePlan(id) }
                    }
                }
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                .accessibilityLabel("\(line.name) seçenekleri")
        }.padding(.vertical, 4)
            .overlay(alignment: .bottom) { Divider().offset(y: 10) }
    }
}

private struct AddShoppingSheet: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var quantity = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField("Ürün adı", text: $name)
                TextField("Miktar · ör. 500 g, isteğe bağlı", text: $quantity)
                Text("Elle eklediğin ihtiyaçlar bir tarifi plandan çıkardığında korunur. Tarif için gerekenin üzerine ek ihtiyaç olarak sayılır.").font(.caption)
            }.navigationTitle("Ürün ekle").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Ekle") { store.data.addShoppingItem(name: name, quantity: quantity); dismiss() }
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }.tint(Ink.dark)
    }
}

private struct ShoppingTransferSheet: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [PurchaseDraft] = []
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Alındı işareti stoklarını değiştirmez. Gerçekte aldığın paket miktarını gir; mutfağa taşıdığında stok artar.").font(.subheadline)
                }
                ForEach($drafts) { $draft in
                    Section(draft.line.name) {
                        TextField("Alınan miktar · ör. 500 g", text: $draft.quantity)
                        Picker("Saklama alanı", selection: $draft.location) {
                            ForEach(StorageLocation.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Mutfağa taşı").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Taşı") {
                            do { try store.data.transferPurchases(drafts); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }.disabled(drafts.isEmpty)
                    }
                }
                .onAppear {
                    drafts = store.data.shoppingLines.filter { store.data.isChecked($0) }.map { line in
                        PurchaseDraft(line: line, quantity: line.amounts.count == 1 && !line.manualUnspecified ? line.amounts[0].text : "", location: .suggested(for: line.name))
                    }
                }
        }.tint(Ink.dark)
    }
}

struct PreparedScheduleSheet: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    let meal: PreparedMeal
    @State private var date = Date.now
    @State private var slot: MealSlot = .dinner
    private var key: String { AppData.dayKey(date) }
    var body: some View {
        NavigationStack {
            Form {
                Text(meal.dish).font(.system(.title2, design: .serif))
                Text("\(meal.remaining) hazır porsiyon · Yediğinde yalnızca kalan porsiyon azalır.").font(.caption)
                DatePicker("Gün", selection: $date, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                Picker("Öğün", selection: $slot) { ForEach(MealSlot.allCases) { Text($0.title).tag($0) } }
                if store.data.completed[key, default: []].contains(slot.rawValue) { Text("Bu öğün zaten tamamlandı. Başka bir öğün seç.") }
            }.navigationTitle("Hazır yemekten planla").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Yerleştir") {
                            store.data.updateMeal(DayMeal(time: slot.time, dish: meal.dish, note: "Hazır yemek", recipeID: nil, preparedID: meal.id), day: key, slot: slot)
                            dismiss()
                        }.disabled(store.data.completed[key, default: []].contains(slot.rawValue))
                    }
                }
        }.tint(Ink.dark)
    }
}

struct PreparedUseRequest: Identifiable {
    let id = UUID()
    let preparedID: UUID
    let day: String
    let slot: MealSlot
}

struct PreparedUseSheet: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    let request: PreparedUseRequest
    var onSaved: (() -> Void)? = nil
    @State private var portions = 1
    @State private var error: String?
    private var meal: PreparedMeal? { store.data.preparedMeals?.first { $0.id == request.preparedID } }
    var body: some View {
        NavigationStack {
            Form {
                Text(meal?.dish ?? "Hazır yemek").font(.system(.title2, design: .serif))
                Text("\(meal?.remaining ?? 0) porsiyon kaldı. Malzemeler tekrar stoktan düşülmez.")
                Stepper("\(portions) porsiyon yedim", value: $portions, in: 1...max(1, meal?.remaining ?? 0))
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Hazır yemekten yedim").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Kaydet") {
                            do { try store.data.eatPrepared(request.preparedID, portions: portions, day: request.day, slot: request.slot); onSaved?(); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }.disabled((meal?.remaining ?? 0) < portions)
                    }
                }
        }.tint(Ink.dark)
    }
}

struct StockEditSheet: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    let stock: Ingredient
    @State private var quantity = ""
    @State private var location: StorageLocation = .fridge
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Text(stock.name).font(.system(.title2, design: .serif))
                TextField("Miktar · ör. 500 g veya 4 adet", text: $quantity)
                Picker("Saklama alanı", selection: $location) { ForEach(StorageLocation.allCases) { Text($0.rawValue).tag($0) } }
                Text("Sayısal miktarlar pişirme planındaki eksiklerin hesaplanmasını sağlar. Şişe veya paket yerine içeriğini g/ml olarak yazabilirsin.").font(.caption)
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Stok miktarı").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Kaydet") {
                            guard let index = store.data.inventory.firstIndex(where: { $0.id == stock.id }), store.data.inventory[index].quantity == stock.quantity else {
                                error = "Stok değişmiş. Kapatıp yeniden aç."; return
                            }
                            store.data.inventory[index].quantity = quantity
                            store.data.inventory[index].location = location
                            dismiss()
                        }.disabled(quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.onAppear { quantity = stock.quantity; location = stock.location }
        }.tint(Ink.dark)
    }
}
