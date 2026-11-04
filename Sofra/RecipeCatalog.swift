import Foundation

enum RecipeCategory: String, CaseIterable, Identifiable {
    case all = "Hepsi", breakfast = "Kahvaltı", main = "Ana yemek", salad = "Salata & kase", soup = "Çorba"
    var id: String { rawValue }
}

enum RecipeCatalog {
    static let additional: [Recipe] = [
        Recipe(id: "omelet", name: "Sade omlet", minutes: 8, ingredients: ["Yumurta", "Zeytinyağı"], steps: ["Yumurtaları bir kasede çırp.", "Zeytinyağını tavada ısıt, yumurtayı ekle.", "Altı ve üstü pişene kadar kısık ateşte pişir, katlayıp servis et."]),
        Recipe(id: "cheese-omelet", name: "Peynirli omlet", minutes: 10, ingredients: ["Yumurta", "Peynir", "Zeytinyağı"], steps: ["Yumurtaları çırp, peyniri ufala.", "Yağlı tavaya yumurtaları dök, peyniri üzerine dağıt.", "Yumurta tamamen pişince omleti katla."]),
        Recipe(id: "spinach-eggs", name: "Ispanaklı yumurta", minutes: 15, ingredients: ["Ispanak", "Yumurta", "Zeytinyağı"], steps: ["Ispanağı iyice yıka ve doğra.", "Zeytinyağında suyunu çekene kadar çevir.", "Yumurtaları ekle ve tamamen pişir."]),
        Recipe(id: "mushroom-eggs", name: "Mantarlı yumurta", minutes: 15, ingredients: ["Mantar", "Yumurta", "Zeytinyağı"], steps: ["Mantarları temizle ve dilimle.", "Zeytinyağında suyu çekilene kadar sotele.", "Çırpılmış yumurtayı ekleyip pişir."]),
        Recipe(id: "menemen", name: "Sebzeli menemen", minutes: 20, ingredients: ["Yumurta", "Domates", "Biber", "Soğan", "Zeytinyağı"], steps: ["Soğan ve biberi küçük doğrayıp yağda yumuşat.", "Doğranmış domatesi ekle, suyunu biraz çektir.", "Yumurtaları ekle ve karıştırarak tamamen pişir."]),
        Recipe(id: "cucumber-yogurt", name: "Yoğurtlu salatalık", minutes: 5, ingredients: ["Salatalık", "Yoğurt"], steps: ["Salatalığı yıkayıp küçük doğra.", "Yoğurtla karıştır, istersen kıvamı için biraz su ekle."]),
        Recipe(id: "cacik", name: "Sarımsaklı cacık", minutes: 8, ingredients: ["Salatalık", "Yoğurt", "Sarımsak"], steps: ["Salatalığı yıka ve rendele.", "Sarımsağı ezip yoğurtla karıştır.", "Salatalığı ekle, kıvamı için azar azar su ilave et."]),
        Recipe(id: "avocado-toast", name: "Avokadolu yumurtalı ekmek", minutes: 15, ingredients: ["Ekmek", "Avokado", "Yumurta", "Zeytinyağı"], steps: ["Ekmeği kızart, avokadoyu ez.", "Yumurtayı zeytinyağında tamamen pişir.", "Ekmeğe avokadoyu yay ve yumurtayı üzerine koy."]),
        Recipe(id: "cheese-toast", name: "Peynirli tost", minutes: 8, ingredients: ["Ekmek", "Peynir"], steps: ["Peyniri iki dilim ekmeğin arasına koy.", "Tost makinesinde veya tavada iki tarafını kızart."]),
        Recipe(id: "banana-pancake", name: "Muzlu yulaf pankeki", minutes: 15, ingredients: ["Muz", "Yulaf", "Yumurta", "Zeytinyağı"], steps: ["Muzu ez, yumurta ve ince öğütülmüş yulafla karıştır.", "Hafifçe yağlanmış tavaya küçük parçalar dök.", "İki tarafını da pişir; ortası çiğ kalmasın."]),
        Recipe(id: "apple-oats", name: "Elmalı yoğurtlu yulaf", minutes: 8, ingredients: ["Elma", "Yulaf", "Yoğurt"], steps: ["Elmayı yıkayıp küçük doğra veya rendele.", "Yoğurt ve yulafı karıştır, elmayı üzerine ekle."]),
        Recipe(id: "milk-porridge", name: "Sütlü muzlu yulaf", minutes: 10, ingredients: ["Yulaf", "Süt", "Muz"], steps: ["Yulaf ve sütü küçük bir tencereye al.", "Karıştırarak yulaf yumuşayana kadar pişir.", "Dilimlenmiş muzu ekleyip servis et."]),
        Recipe(id: "tomato-toast", name: "Domatesli peynirli ekmek", minutes: 12, ingredients: ["Ekmek", "Domates", "Peynir", "Zeytinyağı"], steps: ["Ekmeğin üzerine az zeytinyağı sür.", "Domates dilimleri ve ufalanmış peyniri yerleştir.", "Fırının ızgara ayarında peynir yumuşayıp ekmek kızarana kadar pişir."]),
        Recipe(id: "tuna-pasta", name: "Limonlu ton balıklı makarna", minutes: 20, ingredients: ["Makarna", "Ton balığı", "Limon", "Zeytinyağı"], steps: ["Makarnayı paketindeki süreye göre haşla.", "Süzülmüş konserve ton balığını zeytinyağıyla tavada hafifçe ısıt.", "Makarnayı ekle, üzerine limon sık ve karıştır."]),
        Recipe(id: "yogurt-pasta", name: "Sarımsaklı yoğurtlu makarna", minutes: 20, ingredients: ["Makarna", "Yoğurt", "Sarımsak", "Zeytinyağı"], steps: ["Makarnayı haşla ve süz, biraz ılımaya bırak.", "Ezilmiş sarımsak ve yoğurdu karıştır.", "Makarnayla birleştirip zeytinyağını ekle."]),
        Recipe(id: "corn-pasta", name: "Mısırlı makarna salatası", minutes: 20, ingredients: ["Makarna", "Tatlı mısır", "Yoğurt"], steps: ["Makarnayı haşla, süzüp soğut.", "Pişmiş veya konserve mısırı süz.", "Makarna, mısır ve yoğurdu karıştır."]),
        Recipe(id: "creamy-mushroom", name: "Kremalı mantarlı makarna", minutes: 25, ingredients: ["Makarna", "Mantar", "Krema", "Zeytinyağı"], steps: ["Makarnayı paketindeki süreye göre haşla.", "Dilimlenmiş mantarları yağda sotele.", "Kremayı ekleyip birkaç dakika hafifçe kaynat, makarnayla karıştır."]),
        Recipe(id: "spinach-pasta", name: "Ispanaklı makarna", minutes: 20, ingredients: ["Makarna", "Ispanak", "Sarımsak", "Zeytinyağı"], steps: ["Makarnayı haşla.", "Yıkanmış ıspanağı sarımsak ve yağla tavada pişir.", "Makarnayı ekle; gerekirse biraz haşlama suyuyla karıştır."]),
        Recipe(id: "lentil-soup", name: "Kırmızı mercimek çorbası", minutes: 35, ingredients: ["Kırmızı mercimek", "Soğan", "Havuç", "Zeytinyağı"], steps: ["Mercimeği yıka; soğan ve havucu doğra.", "Sebzeleri zeytinyağında birkaç dakika çevir, mercimeği ekle.", "Üzerini bolca geçecek su ekleyip mercimek yumuşayana kadar pişir.", "Blenderdan geçir, kıvamını sıcak suyla ayarla."]),
        Recipe(id: "vegetable-soup", name: "Patatesli havuç çorbası", minutes: 30, ingredients: ["Patates", "Havuç", "Soğan", "Zeytinyağı"], steps: ["Sebzeleri soyup küçük doğra.", "Soğanı yağda çevir, diğer sebzeleri ekle.", "Üzerini geçecek su ekleyip yumuşayana kadar pişir; istersen blenderdan geçir."]),
        Recipe(id: "tomato-soup", name: "Pirinçli domates çorbası", minutes: 30, ingredients: ["Domates", "Pirinç", "Soğan", "Zeytinyağı"], steps: ["Soğanı doğrayıp yağda yumuşat.", "Rendelenmiş domatesleri ekle ve birkaç dakika pişir.", "Yıkanmış pirinç ve su ekleyip pirinç yumuşayana kadar pişir."]),
        Recipe(id: "lentil-bulgur", name: "Mercimekli bulgur", minutes: 30, ingredients: ["Bulgur", "Kırmızı mercimek", "Soğan", "Zeytinyağı"], steps: ["Soğanı doğrayıp yağda çevir.", "Yıkanmış mercimeği suyla birlikte ekleyip yarı yumuşayana kadar pişir.", "Bulguru ekle, suyunu gerektiği kadar tamamla ve kısık ateşte yumuşayana kadar pişir."]),
        Recipe(id: "chickpea-rice", name: "Nohutlu pilav", minutes: 25, ingredients: ["Pirinç", "Nohut", "Zeytinyağı"], steps: ["Pirinci yıka ve yağda birkaç dakika çevir.", "Haşlanmış nohudu ve pirinç paketindeki orana göre sıcak suyu ekle.", "Kısık ateşte suyunu çekene kadar pişir ve demlendir."]),
        Recipe(id: "vegetable-bulgur", name: "Sebzeli bulgur pilavı", minutes: 25, ingredients: ["Bulgur", "Domates", "Biber", "Soğan", "Zeytinyağı"], steps: ["Doğranmış soğan ve biberi yağda yumuşat.", "Domatesi ekle, ardından bulguru koy.", "Bulgurun paketindeki su oranıyla kısık ateşte pişir."]),
        Recipe(id: "carrot-rice", name: "Havuçlu pilav", minutes: 25, ingredients: ["Pirinç", "Havuç", "Zeytinyağı"], steps: ["Havucu rendeleyip yağda çevir.", "Yıkanmış pirinci ekle, birkaç dakika karıştır.", "Paketindeki orana göre su ilave edip kısık ateşte pişir ve demlendir."]),
        Recipe(id: "spinach-yogurt", name: "Yoğurtlu ıspanak", minutes: 20, ingredients: ["Ispanak", "Yoğurt", "Zeytinyağı"], steps: ["Ispanağı iyice yıka ve doğra.", "Zeytinyağında yumuşayıp suyunu çekene kadar pişir.", "Ilıdıktan sonra yoğurtla birlikte servis et."]),
        Recipe(id: "potato-yogurt", name: "Yoğurtlu patates kasesi", minutes: 25, ingredients: ["Patates", "Yoğurt", "Zeytinyağı"], steps: ["Patatesi soyup küp doğra ve suda yumuşayana kadar haşla.", "Süzüp biraz ılımasını bekle.", "Yoğurt ve zeytinyağıyla karıştır."]),
        Recipe(id: "roasted-vegetables", name: "Fırında patates ve havuç", minutes: 40, ingredients: ["Patates", "Havuç", "Zeytinyağı"], steps: ["Patates ve havucu benzer büyüklükte doğra.", "Zeytinyağıyla harmanlayıp tepsiye tek sıra yay.", "200°C fırında, ara sıra çevirerek içleri yumuşayana kadar pişir."]),
        Recipe(id: "chicken-pan", name: "Tavuklu sebze tavası", minutes: 30, ingredients: ["Tavuk", "Kabak", "Havuç", "Zeytinyağı"], steps: ["Tavuğu küçük parçalar, sebzeleri ince dilimler halinde doğra.", "Tavuğu yağda çevir, sebzeleri ekle.", "Sebzeler yumuşayıp tavuğun içi tamamen pişene kadar pişir; gerekirse az su ekle."]),
        Recipe(id: "beef-peas", name: "Kıymalı bezelye", minutes: 35, ingredients: ["Dana kıyma", "Bezelye", "Domates", "Soğan", "Zeytinyağı"], steps: ["Soğanı yağda yumuşat, kıymayı ekleyip tamamen pişir.", "Doğranmış domatesi ve bezelyeyi ekle.", "Az suyla bezelye yumuşayana kadar kısık ateşte pişir."]),
        Recipe(id: "tuna-chickpea", name: "Ton balıklı nohut salatası", minutes: 10, ingredients: ["Nohut", "Ton balığı", "Domates", "Limon"], steps: ["Haşlanmış nohudu ve konserve ton balığını süz.", "Domatesi doğrayıp hepsini karıştır.", "Üzerine limon sıkıp servis et."]),
        Recipe(id: "cheese-salad", name: "Peynirli çoban salata", minutes: 10, ingredients: ["Domates", "Salatalık", "Peynir", "Zeytinyağı"], steps: ["Domates ve salatalığı yıkayıp doğra.", "Peyniri ufalayıp ekle.", "Zeytinyağıyla karıştırıp servis et."])
    ]
    static let breakfastIDs: Set<String> = ["eggs", "yogurt", "omelet", "cheese-omelet", "spinach-eggs", "mushroom-eggs", "menemen", "avocado-toast", "cheese-toast", "banana-pancake", "apple-oats", "milk-porridge", "tomato-toast"]
    static let saladIDs: Set<String> = ["bowl", "salad", "tuna", "carrot", "cucumber-yogurt", "cacik", "tuna-chickpea", "cheese-salad", "corn-pasta"]
    static let amounts: [String: String] = [
        "Yumurta":"2 adet", "Domates":"1 adet", "Salatalık":"1 adet", "Zeytinyağı":"10 ml", "Yoğurt":"150 g", "Nohut":"150 g", "Yulaf":"40 g", "Muz":"1 adet", "Makarna":"80 g", "Patates":"200 g", "Ton balığı":"100 g", "Iceberg marul":"100 g", "Havuç":"100 g", "Peynir":"50 g", "Ispanak":"150 g", "Mantar":"150 g", "Biber":"1 adet", "Soğan":"1 adet", "Ekmek":"2 dilim", "Avokado":"1 adet", "Elma":"1 adet", "Süt":"200 ml", "Limon":"1 adet", "Sarımsak":"1 diş", "Tatlı mısır":"80 g", "Krema":"75 ml", "Kırmızı mercimek":"80 g", "Pirinç":"70 g", "Bulgur":"70 g", "Tavuk":"150 g", "Kabak":"150 g", "Dana kıyma":"120 g", "Bezelye":"150 g"
    ]
}

extension Recipe {
    var category: RecipeCategory {
        if RecipeCatalog.breakfastIDs.contains(id) { return .breakfast }
        if RecipeCatalog.saladIDs.contains(id) { return .salad }
        if id.contains("soup") { return .soup }
        return .main
    }
    static func canonicalIngredientName(_ name: String) -> String {
        let aliases = ["Yarım yağlı süt": "Süt", "Tam yağlı süt": "Süt", "Yağsız süt": "Süt", "Rendelenmiş peynir": "Peynir", "Beyaz peynir": "Peynir", "Kaşar peyniri": "Peynir", "Krema (crème fraîche)": "Krema", "Kırmızı patates": "Patates"]
        return aliases.first { key($0.key) == key(name) }?.value ?? name
    }
    static func ingredientKey(_ name: String) -> String { key(canonicalIngredientName(name)) }
    func amount(for ingredient: String, servings: Int = 1) -> StockAmount? {
        guard var amount = StockAmount.parse(RecipeCatalog.amounts[Self.canonicalIngredientName(ingredient)] ?? "") else { return nil }
        amount.value *= Double(max(1, servings))
        return amount
    }
}
