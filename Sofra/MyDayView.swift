import SwiftUI

struct MyDayView: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date.now
    @State private var tomorrow = false
    @State private var choosing: MealEditRequest?
    @State private var cooking: CookingRequest?
    @State private var prepared: PreparedUseRequest?
    @State private var error: String?
    @State private var lastSaved: MealSlot?
    private var date: Date { tomorrow ? Calendar.current.date(byAdding: .day, value: 1, to: now)! : now }
    private var key: String { AppData.dayKey(date) }
    private var feature: MealSlot? { tomorrow ? .lunch : store.data.featuredMeal(on: now) }
    private var lunchPlace: LunchPlace { store.data.lunchPlace(on: key) }
    private var suggestedReadyLunch: PreparedMeal? {
        let lunch = store.data.meal(on: key, slot: .lunch)
        if lunch.dish.isEmpty { return store.data.readyMeals.first }
        guard lunch.origin == .recipe, let recipe = lunch.recipe else { return nil }
        return store.data.readyMeals.first { $0.recipeID == recipe.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack {
                        Text("sofra").font(.system(.title3, design: .serif)).tracking(3)
                        Spacer()
                        Text(date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "tr_TR"))).uppercased())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("Gün", selection: $tomorrow) {
                        Text("Bugün").tag(false)
                        Text("Yarın").tag(true)
                    }.pickerStyle(.segmented)
                }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 10)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(tomorrow ? "Yarın" : "Bugün").font(.system(size: 34, weight: .regular, design: .serif))
                                .accessibilityAddTraits(.isHeader)
                            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "tr_TR"))))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if tomorrow { lunchContext }
                        if let feature { featuredMeal(feature) }
                        else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Bugün tamam.").font(.system(.title2, design: .serif))
                                Button("Yarını planla →") { tomorrow = true }
                            }.padding(.vertical, 12)
                        }
                        if let lastSaved, !tomorrow, store.data.completed[key, default: []].contains(lastSaved.rawValue) {
                            HStack {
                                Text("\(lastSaved.title) kaydedildi.").font(.caption)
                                Spacer()
                                Button("Geri al") { undo(lastSaved) }.font(.caption).frame(minHeight: 44)
                            }.foregroundStyle(Ink.rust)
                        }
                        if tomorrow, (lunchPlace == .home || lunchPlace == .prep), let ready = suggestedReadyLunch {
                            VStack(alignment: .leading, spacing: 10) {
                                Caption(text: "Pişirmeden hazır")
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(ready.dish).font(.system(.title3, design: .serif))
                                        Text("\(ready.remaining) porsiyon kaldı").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Seç") {
                                        select(DayMeal(time: MealSlot.lunch.time, dish: ready.dish, note: "", recipeID: nil, preparedID: ready.id, source: .prepared), slot: .lunch)
                                    }.buttonStyle(.bordered)
                                }
                            }
                        }
                        Caption(text: tomorrow ? "Diğer öğünleri de planlayabilirsin" : "Diğer öğünler")
                        ForEach(MealSlot.allCases.filter { $0 != feature }) { slot in compactMeal(slot) }
                        if !tomorrow { waterRow }
                    }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 28)
                }
            }.background(Ink.paper).foregroundStyle(Ink.dark)
                .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $choosing) { request in
            MealChooserView(request: request, lunchPlace: store.data.lunchPlace(on: request.day))
        }
        .sheet(item: $cooking) { request in
            CookingSheet(request: request) { _ in if request.day == AppData.dayKey(now) { lastSaved = request.slot } }
        }
        .sheet(item: $prepared) { request in PreparedUseSheet(request: request) { lastSaved = request.slot } }
        .alert("Öğün güncellenemedi", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Tamam") { error = nil }
        } message: { Text(error ?? "") }
        .onChange(of: tomorrow) { _, _ in lastSaved = nil }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { value in
            if AppData.dayKey(value) != AppData.dayKey(now) { lastSaved = nil }
            now = value
        }
    }
    private var lunchContext: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption(text: "Öğlen nerede olacaksın?")
            Picker("Öğle konumu", selection: Binding(get: {
                lunchPlace == .home ? 0 : lunchPlace == .cafeteria ? 2 : 1
            }, set: { index in
                store.data.setLunchPlace(index == 0 ? .home : index == 2 ? .cafeteria : .prep, day: key)
            })) {
                Text("Ev").tag(0)
                Text("Lamaces").tag(1)
                Text("Sequira").tag(2)
            }.pickerStyle(.segmented)
            if lunchPlace == .prep || lunchPlace == .lidl {
                Picker("Lamaces öğle seçimi", selection: Binding(get: { lunchPlace }, set: { store.data.setLunchPlace($0, day: key) })) {
                    Text("Evden götür").tag(LunchPlace.prep)
                    Text("Lidl").tag(LunchPlace.lidl)
                }.pickerStyle(.segmented)
            }
            Text(lunchPlace == .home ? "Hazır yemeklerden veya tariflerden seç." : lunchPlace == .prep ? "Akşamdan hazırlayıp yanına alabilirsin." : lunchPlace == .lidl ? "Lidl’den alacağın yemeği not et." : "Menüyü yerinde seçebilirsin; mutfak stokların değişmez.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func featuredMeal(_ slot: MealSlot) -> some View {
        let item = store.data.meal(on: key, slot: slot)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Caption(text: tomorrow ? "Öğle planın" : "Sıradaki · \(slot.title)")
                Spacer(minLength: 6)
                Button(item.time) { choose(slot) }.font(.caption.monospacedDigit())
                    .accessibilityLabel("\(slot.title) saatini düzenle")
            }
            Text(item.dish.isEmpty ? "Ne yemek istersin?" : item.dish)
                .font(.system(size: 28, weight: .regular, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
            Text(item.dish.isEmpty ? "Hazır yemekten, tariflerden veya dışarıdan seç." : description(item))
                .font(.subheadline).foregroundStyle(.secondary)
            if !item.note.isEmpty { Text(item.note).font(.caption).foregroundStyle(.secondary) }
            HStack(spacing: 12) {
                if item.dish.isEmpty {
                    Button("Yemek seç") { choose(slot) }.buttonStyle(.borderedProminent).tint(Ink.dark).foregroundStyle(.white)
                } else if tomorrow {
                    Button("Yemeği değiştir") { choose(slot) }.buttonStyle(.bordered)
                } else {
                    Button(item.origin == .recipe ? "Pişirdim" : "Yedim") { complete(slot) }
                        .buttonStyle(.borderedProminent).tint(Ink.dark).foregroundStyle(.white)
                    Button("Değiştir") { choose(slot) }.buttonStyle(.bordered)
                }
            }
            if tomorrow, !item.dish.isEmpty {
                Label("Planın kaydedildi", systemImage: "checkmark").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.dark.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
    private func compactMeal(_ slot: MealSlot) -> some View {
        let item = store.data.meal(on: key, slot: slot)
        let done = store.data.completed[key, default: []].contains(slot.rawValue)
        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Text(item.time).font(.caption.monospacedDigit()).foregroundStyle(.secondary).padding(.top, 5)
                VStack(alignment: .leading, spacing: 7) {
                    Text(slot.title).font(.system(.title3, design: .serif))
                    Text(item.dish.isEmpty ? "Henüz planlanmadı" : item.dish).font(.subheadline).foregroundStyle(.secondary)
                    if done {
                        HStack {
                            Label("Yendi", systemImage: "checkmark.circle.fill").font(.caption)
                            Button("Geri al") { undo(slot) }.font(.caption).frame(minHeight: 44)
                        }
                    } else {
                        HStack {
                            Button(item.dish.isEmpty ? "+ Yemek seç" : "Değiştir") { choose(slot) }.font(.caption).frame(minHeight: 44)
                            if !tomorrow && !item.dish.isEmpty {
                                Button(item.origin == .recipe ? "Pişirdim" : "Yedim") { complete(slot) }.font(.caption).frame(minHeight: 44)
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
        }
    }
    private var waterRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "drop").foregroundStyle(Ink.rust)
            Text("Su · \(store.data.water[key, default: 0] * 250) ml").font(.subheadline)
            Spacer()
            Menu {
                Button("250 ml geri al") { store.data.water[key] = max(0, store.data.water[key, default: 0] - 1) }
                    .disabled(store.data.water[key, default: 0] == 0)
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                .accessibilityLabel("Su kaydı seçenekleri")
            Button("+250 ml") { store.data.water[key, default: 0] += 1 }.buttonStyle(.bordered)
        }
    }
    private func description(_ meal: DayMeal) -> String {
        switch meal.origin {
        case .prepared:
            let remaining = store.data.preparedMeals?.first { $0.id == meal.preparedID }?.remaining ?? 0
            return "Hazır yemek · \(remaining) porsiyon kaldı"
        case .recipe: return "Pişirilecek · \(meal.servings ?? 1) porsiyon"
        case .outside: return "Dışarıdan · mutfak stokları kullanılmaz"
        }
    }
    private func choose(_ slot: MealSlot) { choosing = MealEditRequest(day: key, slot: slot, meal: store.data.meal(on: key, slot: slot)) }
    private func select(_ meal: DayMeal, slot: MealSlot) {
        do { try store.data.selectMeal(meal, day: key, slot: slot) } catch { self.error = error.localizedDescription }
    }
    private func complete(_ slot: MealSlot) {
        let item = store.data.meal(on: key, slot: slot)
        switch item.origin {
        case .prepared:
            guard let id = item.preparedID, store.data.readyMeals.contains(where: { $0.id == id }) else { choose(slot); return }
            prepared = PreparedUseRequest(preparedID: id, day: key, slot: slot)
        case .recipe:
            cooking = CookingRequest(dish: item.dish, recipe: item.recipe, day: key, slot: slot, servings: min(8, max(1, item.servings ?? 1)))
        case .outside:
            do { try store.data.markOutsideEaten(day: key, slot: slot); lastSaved = slot }
            catch { self.error = error.localizedDescription }
        }
    }
    private func undo(_ slot: MealSlot) {
        do { try store.data.undoMeal(day: key, slot: slot); lastSaved = nil }
        catch { self.error = error.localizedDescription }
    }
}

struct MealChooserView: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    let request: MealEditRequest
    let lunchPlace: LunchPlace
    @State private var source: MealOrigin = .recipe
    @State private var query = ""
    @State private var outside = ""
    @State private var note = ""
    @State private var time = Date.now
    @State private var servings = 1
    @State private var error: String?
    @State private var showAll = false
    @State private var personalEditor = false
    @State private var pendingPersonal: Recipe?
    @State private var pendingPortions = 1
    @State private var loaded = false
    private var recipeMatches: [RecipeMatch] {
        let normalized = Recipe.key(query)
        let matching = store.recipeMatches.filter { normalized.isEmpty || $0.searchText.contains(normalized) }
        return showAll || !query.isEmpty ? matching : Array(matching.prefix(8))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(request.day == AppData.dayKey() ? "Bugün" : request.day == AppData.dayKey(Calendar.current.date(byAdding: .day, value: 1, to: .now)!) ? "Yarın" : request.day)
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(request.slot.title).font(.system(.title, design: .serif))
                        Spacer()
                        DatePicker("Saat", selection: $time, displayedComponents: .hourAndMinute).labelsHidden()
                    }
                    Picker("Yemek kaynağı", selection: $source) {
                        ForEach(MealOrigin.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    switch source {
                    case .prepared: preparedChoices
                    case .recipe: recipeChoices
                    case .outside: outsideChoice
                    }
                    DisclosureGroup("Not ekle veya düzenle") {
                        TextField("İsteğe bağlı not", text: $note, axis: .vertical).textFieldStyle(.roundedBorder).padding(.vertical, 8)
                        Text(request.meal.dish.isEmpty ? "Yemeği seçtiğinde kaydedilir." : "Not ve saat otomatik kaydedilir.").foregroundStyle(.secondary)
                    }.font(.caption)
                    if let error { Text(error).foregroundStyle(.red).font(.subheadline) }
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively).background(Ink.paper).foregroundStyle(Ink.dark)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $personalEditor, onDismiss: {
                    if let recipe = pendingPersonal {
                        pendingPersonal = nil
                        save(DayMeal(time: request.meal.time, dish: recipe.name, note: "", recipeID: recipe.id, source: .recipe, servings: pendingPortions, personalRecipe: recipe))
                    }
                }) {
                    PersonalRecipeEditor(initial: request.meal.personalRecipe, initialServings: servings,
                        initialName: request.meal.origin == .recipe && request.meal.recipe == nil ? request.meal.dish : "") { recipe, count in
                        pendingPersonal = recipe
                        pendingPortions = count
                    }
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } } }
                .onAppear(perform: load)
                .onChange(of: time) { _, _ in saveCurrentDetails() }
                .onChange(of: note) { _, _ in saveCurrentDetails() }
        }.tint(Ink.dark)
    }
    private var preparedChoices: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.data.readyMeals.isEmpty {
                Text("Hazır yemek kalmadı.").font(.system(.title2, design: .serif))
                Button("Tariflerden seç") { source = .recipe }.buttonStyle(.bordered)
            }
            ForEach(store.data.readyMeals) { ready in
                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(ready.dish).font(.system(.title3, design: .serif))
                        Text("\(ready.remaining) hazır porsiyon").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Seç") { save(DayMeal(time: request.meal.time, dish: ready.dish, note: "", recipeID: nil, preparedID: ready.id, source: .prepared)) }.buttonStyle(.bordered)
                }
                Divider()
            }
            Text("Yalnızca yediğinde hazır porsiyon azalır. Malzemeler yeniden stoktan düşülmez.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var recipeChoices: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            Button { personalEditor = true } label: { Label(request.meal.personalRecipe == nil ? "Kendi yemeğimi yaz" : "Kendi tarifimi düzenle", systemImage: "square.and.pencil") }.buttonStyle(.bordered)
            Stepper("\(servings) porsiyon pişireceğim", value: $servings, in: 1...8)
            TextField("Tarif veya malzeme ara", text: $query).textFieldStyle(.roundedBorder)
            ForEach(recipeMatches) { match in
                let recipe = match.recipe
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(recipe.name).font(.system(.title3, design: .serif))
                        let missing = match.missing
                        Text(missing.isEmpty ? "\(recipe.minutes) dk · malzemeler mutfakta" : "\(recipe.minutes) dk · eksik: " + missing.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Button("Seç") { save(DayMeal(time: request.meal.time, dish: recipe.name, note: "", recipeID: recipe.id, source: .recipe, servings: servings, personalRecipe: recipe.customAmounts == nil ? nil : recipe)) }.buttonStyle(.bordered)
                }
                Divider()
            }
            if !showAll && query.isEmpty { Button("\(store.recipeMatches.count) tarifin tümünü göster") { showAll = true } }
            Text("Tarifin hesaplanabilen eksikleri alışverişe otomatik yansır. Seçmek stokları azaltmaz. Miktarı belirsiz ürünleri alışverişte kontrol edebilirsin.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var outsideChoice: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Ne yiyeceksin?", text: $outside).textFieldStyle(.roundedBorder).onSubmit(saveOutside)
            if request.slot == .lunch && (lunchPlace == .lidl || lunchPlace == .cafeteria) {
                Button(lunchPlace == .lidl ? "Lidl’den öğle yemeği olarak planla" : "Yemekhanede seçeceğim") {
                    outside = lunchPlace == .lidl ? "Lidl’den öğle yemeği" : "Yemekhanede seçeceğim"
                    saveOutside()
                }.buttonStyle(.bordered)
            }
            Button("Bu öğüne ekle", action: saveOutside).buttonStyle(.borderedProminent).tint(Ink.dark).foregroundStyle(.white)
                .disabled(outside.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Text("Bu öğün mutfak stoklarını değiştirmez.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func load() {
        guard !loaded else { return }; loaded = true
        let parts = request.meal.time.split(separator: ":").compactMap { Int($0) }
        time = Calendar.current.date(bySettingHour: parts.first ?? 12, minute: parts.last ?? 0, second: 0, of: .now) ?? .now
        note = request.meal.note
        servings = min(8, max(1, request.meal.servings ?? 1))
        if !request.meal.dish.isEmpty {
            source = request.meal.origin
            if source == .outside { outside = request.meal.dish }
        } else if request.slot == .lunch && (lunchPlace == .lidl || lunchPlace == .cafeteria) { source = .outside }
        else { source = store.data.readyMeals.isEmpty ? .recipe : .prepared }
    }
    private func saveCurrentDetails() {
        guard loaded else { return }
        var current = store.data.meal(on: request.day, slot: request.slot)
        guard !current.dish.isEmpty else { return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let value = String(format: "%02d:%02d", components.hour ?? 12, components.minute ?? 0)
        guard current.time != value || current.note != note else { return }
        current.time = value
        current.note = note
        store.data.updateMeal(current, day: request.day, slot: request.slot)
    }
    private func saveOutside() { save(DayMeal(time: request.meal.time, dish: outside, note: "", recipeID: nil, source: .outside)) }
    private func save(_ meal: DayMeal) {
        var item = meal
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        item.time = String(format: "%02d:%02d", components.hour ?? 12, components.minute ?? 0)
        item.note = note
        do { try store.data.selectMeal(item, day: request.day, slot: request.slot); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
