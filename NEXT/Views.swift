import SwiftUI

private enum Ink {
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

private struct Journal<Content: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Text("NEXT").font(.system(.headline, design: .serif)).tracking(4)
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

private struct Caption: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Ink.rust)
    }
}

struct TodayView: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date.now
    private var key: String { AppData.dayKey(now) }
    private var water: Int { store.data.water[key, default: 0] }
    var body: some View {
        Journal(eyebrow: now.formatted(.dateTime.day().month(.abbreviated)).uppercased(), title: "Bugün,\nsana göre.") {
            Caption(text: "Günün akışı")
            meal("breakfast", time: "08:45", title: "Kahvaltı", detail: "Yoğurtlu yulaf", icon: "sunrise")
            Divider()
            meal("lunch", time: "13:00", title: "Öğle arası",
                 detail: store.data.lunches[key].map { "\($0.meal) · \($0.place.rawValue)" } ?? "Henüz plan yok · Yarın ekranından bir sonraki öğle arasını planla.", icon: "fork.knife")
            Divider()
            meal("dinner", time: "19:30", title: "Evde akşam", detail: "Mutfaktaki malzemelerden bir tarif seç", icon: "moon")
            Text("Kahvaltı ve akşam satırları başlangıç örnekleridir.")
                .font(.caption).foregroundStyle(.secondary)
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
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private func meal(_ id: String, time: String, title: String, detail: String, icon: String) -> some View {
        let done = store.data.completed[key, default: []].contains(id)
        return HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 10) {
                Text(time).font(.caption.monospacedDigit())
                Image(systemName: icon).font(.title2)
            }.frame(width: 48)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(.title2, design: .serif))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                if done { store.data.completed[key, default: []].remove(id) }
                else { store.data.completed[key, default: []].insert(id) }
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title2).frame(width: 44, height: 44)
            }.accessibilityLabel("\(title): \(done ? "tamamlandı, geri al" : "tamamla")")
        }.padding(.vertical, 8)
    }
}

struct TomorrowView: View {
    @EnvironmentObject private var store: FoodStore
    @State private var place: LunchPlace = .prep
    @State private var meal = ""
    @State private var note = ""
    @State private var saved = false
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
                    store.data.lunches[key] = LunchPlan(date: key, place: place, meal: meal.trimmingCharacters(in: .whitespacesAndNewlines), note: note)
                    saved = true
                }.buttonStyle(.borderedProminent).tint(Ink.dark).foregroundStyle(.white)
                    .disabled(meal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if place == .prep {
                    NavigationLink("Tarifi ve eksikleri gör →") { RecipeDetail(recipe: Recipe.all[0]) }
                }
                Text("Lidl ve yemekhane seçenekleri örnek planlardır. Güncel menü ve stok bilgisi bağlı değil.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear {
            targetDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
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
    private var visibleIngredients: [Ingredient] {
        store.data.inventory.filter { $0.location == location }
    }
    private var recipes: [Recipe] {
        Recipe.all.sorted {
            let lhs = $0.missing(in: store.data.inventory).count
            let rhs = $1.missing(in: store.data.inventory).count
            return lhs == rhs ? $0.id < $1.id : lhs < rhs
        }
    }
    var body: some View {
        Journal(eyebrow: "Eldekilerle iyi yemek", title: "Mutfakta\nne var?") {
            Picker("Saklama alanı", selection: $location) {
                ForEach(StorageLocation.allCases) { area in
                    Text(area.rawValue).tag(area)
                }
            }.pickerStyle(.segmented)
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                    Text("Tarifler tüm bölümlerdeki malzeme adlarına göre eşleşir; miktarlar kontrol edilmez.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(recipes) { recipe in
                        NavigationLink { RecipeDetail(recipe: recipe) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(recipe.minutes) DK").font(.caption).tracking(2).foregroundStyle(Ink.rust)
                                Text(recipe.name).font(.system(.title2, design: .serif))
                                let missing = recipe.missing(in: store.data.inventory)
                                Text(missing.isEmpty ? "Tüm malzemeler rafta" : "\(missing.count) malzeme eksik →")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                        }.buttonStyle(.plain)
                        Divider()
                    }
                    }.padding(26)
                }.background(Ink.paper).foregroundStyle(Ink.dark)
                    .navigationTitle("Ne pişse?")
                    .navigationBarTitleDisplayMode(.inline)
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
    @State private var added = false
    private var missing: [String] { recipe.missing(in: store.data.inventory) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Caption(text: "Mutfaktan · \(recipe.minutes) dakika")
                Text(recipe.name).font(.system(size: 38, design: .serif))
                ForEach(recipe.ingredients, id: \.self) { ingredient in
                    Label(ingredient, systemImage: missing.contains(ingredient) ? "circle" : "checkmark.circle.fill")
                }
                if !missing.isEmpty {
                    Button(added ? "Alışveriş listesine eklendi ✓" : "Eksikleri listeye ekle") {
                        store.data.addShopping(missing); added = true
                    }.buttonStyle(.borderedProminent).tint(Ink.dark).foregroundStyle(.white)
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
        }.background(Ink.paper).foregroundStyle(Ink.dark).navigationBarTitleDisplayMode(.inline)
    }
}

struct ShoppingView: View {
    @EnvironmentObject private var store: FoodStore
    @State private var name = ""
    var body: some View {
        Journal(eyebrow: "Bir sonraki alışveriş", title: "Küçük\nbir liste.") {
            HStack {
                TextField("Listeye bir şey ekle", text: $name).textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button(action: add) { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .accessibilityLabel("Alışveriş listesine ekle")
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if store.data.shopping.isEmpty {
                Text("Şimdilik ihtiyacın olan bir şey yok. Tariflerdeki eksikleri buraya ekleyebilirsin.")
                    .font(.system(.title3, design: .serif)).padding(.vertical, 32)
            }
            ForEach(store.data.shopping) { item in
                HStack {
                    Button {
                        if let index = store.data.shopping.firstIndex(where: { $0.id == item.id }) {
                            store.data.shopping[index].checked.toggle()
                        }
                    } label: {
                        Label(item.name, systemImage: item.checked ? "checkmark.circle.fill" : "circle")
                            .strikethrough(item.checked).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.accessibilityLabel("\(item.name), \(item.checked ? "alındı" : "alınacak")")
                    Button {
                        store.data.shopping.removeAll { $0.id == item.id }
                    } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                        .accessibilityLabel("\(item.name) listesinden sil")
                }
                Divider()
            }
            if store.data.shopping.contains(where: \.checked) {
                Button("Alınanları mutfağa taşı") {
                    for item in store.data.shopping where item.checked {
                        if !store.data.inventory.contains(where: { Recipe.key($0.name) == Recipe.key(item.name) }) {
                            store.data.inventory.append(Ingredient(name: item.name, quantity: "Miktar ekle"))
                        }
                    }
                    store.data.shopping.removeAll(where: \.checked)
                }.buttonStyle(.borderedProminent).tint(Ink.dark).foregroundStyle(.white)
            }
        }
    }
    private func add() { store.data.addShopping([name]); name = "" }
}
