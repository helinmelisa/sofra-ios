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
            TodayView().tabItem { Label("Bugün", systemImage: "sun.max") }
            TomorrowView().tabItem { Label("Yarın", systemImage: "calendar") }
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

struct TodayView: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date.now
    @State private var editingMeal: MealEditRequest?
    @State private var cookingMeal: CookingRequest?
    @State private var usingPrepared: PreparedUseRequest?
    @State private var mealError: String?
    private var key: String { AppData.dayKey(now) }
    private var water: Int { store.data.water[key, default: 0] }
    var body: some View {
        Journal(eyebrow: now.formatted(.dateTime.day().month(.abbreviated)).uppercased(), title: "Bugün,\nsana göre.") {
            Caption(text: "Günün akışı")
            ForEach(MealSlot.allCases) { slot in
                meal(slot)
                Divider()
            }
            VStack(alignment: .leading, spacing: 16) {
                Caption(text: "Bir yudum ara")
                HStack(alignment: .firstTextBaseline) {
                    Text("\(water * 250)").font(.system(size: 42, design: .serif))
                    Text("ml su").font(.subheadline)
                    Spacer()
                    Image(systemName: "drop").font(.title).foregroundStyle(Ink.rust)
                }
                HStack {
                    Button { store.data.water[key] = max(0, water - 1) } label: {
                        Image(systemName: "minus").frame(width: 44, height: 44)
                    }.disabled(water == 0).accessibilityLabel("250 ml suyu geri al")
                    Spacer()
                    Button("+ 250 ml") { store.data.water[key] = water + 1 }
                        .buttonStyle(.borderedProminent).tint(Ink.dark).foregroundStyle(.white)
                }
                Text("Her dokunuş bir bardak. Günlük kayıt gece yenilenir.").font(.caption).foregroundStyle(.secondary)
            }.padding(22).background(Ink.dark.opacity(0.06))
        }
        .sheet(item: $editingMeal) { request in MealEditorView(request: request) }
        .sheet(item: $usingPrepared) { PreparedUseSheet(request: $0) }
        .sheet(item: $cookingMeal) { request in CookingSheet(request: request) }
        .alert("Öğün güncellenemedi", isPresented: Binding(get: { mealError != nil }, set: { if !$0 { mealError = nil } })) {
            Button("Tamam") { mealError = nil }
        } message: { Text(mealError ?? "") }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private func meal(_ slot: MealSlot) -> some View {
        let item = store.data.meal(on: key, slot: slot)
        let done = store.data.completed[key, default: []].contains(slot.rawValue)
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 10) {
                Text(item.time).font(.caption.monospacedDigit())
                Image(systemName: slot.icon).font(.title2)
            }.frame(width: 48)
            VStack(alignment: .leading, spacing: 8) {
                Text(slot.title).font(.system(.title2, design: .serif))
                Text(item.dish.isEmpty ? "Yemek seç veya planını yaz" : item.dish)
                    .font(.subheadline).foregroundStyle(.secondary)
                if !item.note.isEmpty { Text(item.note).font(.caption).foregroundStyle(.secondary) }
                Button {
                    editingMeal = MealEditRequest(day: key, slot: slot, meal: item)
                } label: { Label("Düzenle", systemImage: "pencil").font(.caption).frame(minHeight: 36) }
            }
            Spacer(minLength: 0)
            Button {
                if done {
                    if let cooked = store.data.cooking(on: key, slot: slot) {
                        do { try store.data.undoCooking(cooked.id) } catch { mealError = error.localizedDescription }
                    } else if let use = store.data.leftoverUse(on: key, slot: slot) {
                        do { try store.data.undoPreparedUse(use.id) } catch { mealError = error.localizedDescription }
                    } else { store.data.completed[key, default: []].remove(slot.rawValue) }
                } else if let preparedID = item.preparedID {
                    usingPrepared = PreparedUseRequest(preparedID: preparedID, day: key, slot: slot)
                } else if item.dish.isEmpty {
                    editingMeal = MealEditRequest(day: key, slot: slot, meal: item)
                } else {
                    cookingMeal = CookingRequest(dish: item.dish, recipe: item.recipe, day: key, slot: slot, servings: store.data.activeRecipePlans.first { $0.recipeID == item.recipe?.id }?.servings ?? 1)
                }
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title2).frame(width: 44, height: 44)
            }.accessibilityLabel("\(slot.title): \(done ? "tamamlanmayı ve stok düşümünü geri al" : "tamamla")")
        }.padding(.vertical, 8)
    }
}

struct TomorrowView: View {
    @EnvironmentObject private var store: FoodStore
    @State private var place: LunchPlace = .prep
    @State private var meal = ""
    @State private var note = ""
    @State private var saved = false
    @State private var loadedDay: String?
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
    private var key: String { AppData.dayKey(targetDate) }

    var body: some View {
        Journal(eyebrow: "Bir adım önden", title: "Yarın\nne yesek?") {
            Text(targetDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline)
            Caption(text: "Öğle arası nerede?")
            ForEach(LunchPlace.allCases) { option in
                Button {
                    place = option; meal = option.suggestion; saved = false
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(option.rawValue).font(.system(.title3, design: .serif))
                            Text(option.suggestion).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: place == option ? "largecircle.fill.circle" : "circle")
                    }.padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).accessibilityAddTraits(place == option ? .isSelected : [])
                Divider()
            }
            VStack(alignment: .leading, spacing: 14) {
                Caption(text: "Planın")
                TextField("Öğle yemeği", text: $meal).textFieldStyle(.roundedBorder)
                TextField("Hazırlık notu", text: $note, axis: .vertical).textFieldStyle(.roundedBorder)
                Button(saved ? "Plan kaydedildi ✓" : "Yarını planla") {
                    store.data.dayMeals?[key]?[MealSlot.lunch.rawValue] = nil
                    store.data.lunches[key] = LunchPlan(date: key, place: place, meal: meal.trimmingCharacters(in: .whitespacesAndNewlines), note: note)
                    saved = true
                }.buttonStyle(.borderedProminent).tint(Ink.dark).foregroundStyle(.white)
                    .disabled(meal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if place == .home {
                    NavigationLink("Mutfaktakilerden tarif seç →") {
                        RecipeListView { recipe in
                            meal = recipe.name
                            saved = false
                        }
                    }
                }
                if place == .prep {
                    NavigationLink("Tarifi ve eksikleri gör →") { RecipeDetail(recipe: Recipe.all[0]) }
                }
                Text("Lidl ve yemekhane seçenekleri örnek planlardır. Güncel menü ve stok bilgisi bağlı değil.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear {
            targetDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
            guard loadedDay != key else { return }
            loadedDay = key
            if let plan = store.data.lunches[key] {
                place = plan.place; meal = plan.meal; note = plan.note
            } else { meal = place.suggestion }
            saved = false
        }
        .onChange(of: meal) { _, _ in saved = false }
        .onChange(of: note) { _, _ in saved = false }
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
            .onAppear { servings = store.data.activeRecipePlans.first { $0.recipeID == recipe.id }?.servings ?? 1 }
            .sheet(item: $cooking) { request in CookingSheet(request: request) { lastCookingID = $0 } }
            .alert("Stok güncellenemedi", isPresented: Binding(get: { stockError != nil }, set: { if !$0 { stockError = nil } })) {
                Button("Tamam") { stockError = nil }
            } message: { Text(stockError ?? "") }
    }
}
