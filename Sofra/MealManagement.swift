import SwiftUI

struct MealEditRequest: Identifiable {
    let id = UUID()
    let day: String
    let slot: MealSlot
    let meal: DayMeal
}

struct CookingRequest: Identifiable {
    let id = UUID()
    let dish: String
    let recipe: Recipe?
    var day: String? = nil
    var slot: MealSlot? = nil
}

struct MealEditorView: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    let request: MealEditRequest
    @State private var draft: DayMeal
    @State private var time: Date
    private var isCooked: Bool { store.data.cooking(on: request.day, slot: request.slot) != nil }
    init(request: MealEditRequest) {
        self.request = request
        _draft = State(initialValue: request.meal)
        let parts = request.meal.time.split(separator: ":").compactMap { Int($0) }
        _time = State(initialValue: Calendar.current.date(bySettingHour: parts.first ?? 12, minute: parts.last ?? 0, second: 0, of: .now) ?? .now)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Öğün") {
                    DatePicker("Saat", selection: $time, displayedComponents: .hourAndMinute)
                    TextField("Ne yiyeceksin?", text: $draft.dish)
                        .disabled(isCooked)
                        .onChange(of: draft.dish) { _, name in
                            draft.recipeID = Recipe.all.first { Recipe.key($0.name) == Recipe.key(name) }?.id
                        }
                    TextField("Not", text: $draft.note, axis: .vertical)
                }
                if isCooked {
                    Text("Bu öğünde stok düşümü yapıldı. Yemeği değiştirmek için önce Bugün ekranından tamamlanma işaretini geri al.")
                        .font(.caption)
                } else {
                    Section("Tariften seç") {
                        NavigationLink("Mutfaktaki malzemelerle tarifler") {
                            RecipeListView(selectionLabel: "Bu öğün için seç") { recipe in
                                draft.dish = recipe.name
                                draft.recipeID = recipe.id
                            }
                        }
                    }
                }
            }
            .navigationTitle(request.slot.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        var saved = draft
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                        saved.time = String(format: "%02d:%02d", parts.hour ?? 12, parts.minute ?? 0)
                        saved.dish = saved.dish.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.data.updateMeal(saved, day: request.day, slot: request.slot)
                        dismiss()
                    }.disabled(draft.dish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }.tint(Ink.dark)
    }
}

struct CookingSheet: View {
    @EnvironmentObject private var store: FoodStore
    @Environment(\.dismiss) private var dismiss
    let request: CookingRequest
    var onSaved: ((UUID) -> Void)? = nil
    @State private var drafts: [UsageDraft] = []
    @State private var loaded = false
    @State private var logToSlot: MealSlot?
    @State private var error: String?
    private var selected: Bool { drafts.contains(where: \.selected) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(request.dish).font(.system(.title2, design: .serif))
                    Text(request.recipe == nil ? "Kullandığın malzemeleri seç ve miktarlarını gir." : "Miktarlar tek kişilik başlangıç önerileridir. Gerçekte kullandığın miktarları düzenle.")
                        .font(.subheadline)
                    Text("Stok ve kullanım için 2 adet, 500 g veya 250 ml gibi bir miktar gir. Belirsiz kayıtları burada düzeltebilirsin.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let recipe = request.recipe {
                        let missing = recipe.missing(in: store.data.inventory)
                        if !missing.isEmpty {
                            Text("Mutfakta görünmeyenler: " + missing.joined(separator: ", ") + ". Bunlardan stok düşülmez.")
                                .font(.caption).foregroundStyle(Ink.rust)
                        }
                    }
                    if request.day == nil {
                        Picker("Bugünün akışına ekle", selection: $logToSlot) {
                            Text("Sadece stoktan düş").tag(nil as MealSlot?)
                            ForEach(MealSlot.allCases) { slot in Text(slot.title).tag(Optional(slot)) }
                        }
                    }
                    if drafts.isEmpty { Text("Mutfakta malzeme yok. Önce stoklarını ekle.") }
                }
                ForEach($drafts) { $draft in
                    Section(draft.name) {
                        Toggle("Kullandım", isOn: $draft.selected)
                        if draft.selected {
                            LabeledContent("Mevcut stok") {
                                TextField("Ör. 500 g", text: $draft.available).multilineTextAlignment(.trailing)
                            }
                            LabeledContent("Kullandığım") {
                                TextField("Ör. 100 g", text: $draft.used).multilineTextAlignment(.trailing)
                            }
                            if let available = StockAmount.parse(draft.available), let used = StockAmount.parse(draft.used), available.dimension == used.dimension, used.value > 0, used.baseValue <= available.baseValue {
                                let left = StockAmount(value: available.value - used.converted(to: available.unit), unit: available.unit)
                                Text("Kalan: \(left.text)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if request.day != nil {
                    Section {
                        Button("Stok kullanmadan tamamla") {
                            if let day = request.day, let slot = request.slot { store.data.completed[day, default: []].insert(slot.rawValue) }
                            dismiss()
                        }
                    } footer: { Text("Dışarıda yediysen veya bu öğünde mutfaktan malzeme kullanmadıysan.") }
                }
            }
            .navigationTitle("Pişirdim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Stoktan düş") {
                        do {
                            let slot = request.slot ?? logToSlot
                            let day = request.day ?? (slot == nil ? nil : AppData.dayKey())
                            try store.data.cook(id: request.id, dish: request.dish, drafts: drafts, day: day, slot: slot)
                            if request.day == nil, let day, let slot {
                                var meal = store.data.meal(on: day, slot: slot)
                                meal.dish = request.dish
                                meal.recipeID = request.recipe?.id
                                store.data.updateMeal(meal, day: day, slot: slot)
                            }
                            onSaved?(request.id)
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.disabled(!selected)
                }
            }
            .onAppear {
                if !loaded { drafts = store.data.usage(for: request.recipe); loaded = true }
            }
        }.tint(Ink.dark)
    }
}
