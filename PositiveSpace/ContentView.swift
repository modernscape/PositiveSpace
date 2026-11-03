import SwiftUI
import SwiftData

// MARK: - SwiftData モデル定義

@Model
class ElementItem {
    var id: UUID
    var title: String
    var isPositive: Bool
    
    init(title: String, isPositive: Bool) {
        self.id = UUID()
        self.title = title
        self.isPositive = isPositive
    }
}

@Model
class HistoryItem {
    var id: UUID
    var title: String
    var isPositive: Bool
    var date: Date
    
    init(title: String, isPositive: Bool) {
        self.id = UUID()
        self.title = title
        self.isPositive = isPositive
        self.date = Date()
    }
}

// MARK: - メインビュー

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<ElementItem> { $0.isPositive == true })
    private var positiveItems: [ElementItem]
    
    @Query(filter: #Predicate<ElementItem> { $0.isPositive == false })
    private var negativeItems: [ElementItem]
    
    @Query(sort: \HistoryItem.date, order: .reverse)
    private var histories: [HistoryItem]
    
    // データ保存
    @AppStorage("targetGoal") private var targetGoal = "月収100万円"
    @AppStorage("targetDateString") private var targetDateString = "2026-12-31"
    @AppStorage("positivePoints") private var positivePoints: Int = 0
    let maxPoints: Int = 200
    
    // 選択中のIDセット
    @State private var selectedPositiveIDs: Set<PersistentIdentifier> = []
    @State private var selectedNegativeIDs: Set<PersistentIdentifier> = []
    
    // 追加・編集モーダル用
    @State private var showingAddPositive = false
    @State private var showingAddNegative = false
    @State private var editingItem: ElementItem? = nil
    @State private var inputTitle = ""
    
    var negativePoints: Int {
        max(0, maxPoints - positivePoints)
    }
    
    // 3列用のグリッド定義
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6)
        ]
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { outerGeometry in
                let halfWidth = outerGeometry.size.width * 0.45 // 画面幅の約半分に設定
                
                VStack(spacing: 12) {
                    // 1. 【固定】目標・期限ヘッダー
                    targetHeaderView
                        .padding(.horizontal)
                        .padding(.top, 4)
                    
                    // 2. 【固定】Positive ヘッダー（タイトルを画面幅の半分くらいに調整）
                    positiveHeaderView(titleWidth: halfWidth)
                        .padding(.horizontal)
                    
                    // 3. 【スクロール可能】Positive 項目リスト（3列）
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(positiveItems) { item in
                                itemCell(item: item, isPositiveStyle: true, isSelected: selectedPositiveIDs.contains(item.persistentModelID)) {
                                    if selectedPositiveIDs.contains(item.persistentModelID) {
                                        selectedPositiveIDs.remove(item.persistentModelID)
                                    } else {
                                        selectedPositiveIDs.insert(item.persistentModelID)
                                    }
                                } onEdit: {
                                    editingItem = item
                                    inputTitle = item.title
                                }
                            }
                            
                            Button(action: { showingAddPositive = true }) {
                                Image(systemName: "plus")
                                    .foregroundColor(Color("PositiveColor"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 4. 【固定】中央ゲージエリア
                    gaugeSectionView
                        .padding(.horizontal)
                    
                    // 5. 【スクロール可能】Negative 項目リスト（3列）
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(negativeItems) { item in
                                itemCell(item: item, isPositiveStyle: false, isSelected: selectedNegativeIDs.contains(item.persistentModelID)) {
                                    if selectedNegativeIDs.contains(item.persistentModelID) {
                                        selectedNegativeIDs.remove(item.persistentModelID)
                                    } else {
                                        selectedNegativeIDs.insert(item.persistentModelID)
                                    }
                                } onEdit: {
                                    editingItem = item
                                    inputTitle = item.title
                                }
                            }
                            
                            Button(action: { showingAddNegative = true }) {
                                Image(systemName: "plus")
                                    .foregroundColor(Color("NegativeColor"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 6. 【固定】Negative フッター（タイトルを画面幅の半分くらいに調整）
                    negativeFooterView(titleWidth: halfWidth)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupInitialDataIfNeeded()
            }
            .alert("項目を編集", isPresented: Binding(
                get: { editingItem != nil },
                set: { if !$0 { editingItem = nil } }
            )) {
                TextField("項目名", text: $inputTitle)
                Button("保存") {
                    if let item = editingItem, !inputTitle.isEmpty {
                        item.title = inputTitle
                        editingItem = nil
                        inputTitle = ""
                    }
                }
                Button("削除", role: .destructive) {
                    if let item = editingItem {
                        modelContext.delete(item)
                        editingItem = nil
                        inputTitle = ""
                    }
                }
                Button("キャンセル", role: .cancel) {
                    editingItem = nil
                    inputTitle = ""
                }
            }
        }
    }
    
    // MARK: - 各パーツ
    
    private var targetHeaderView: some View {
        VStack(alignment: .center, spacing: 2) {
            Text("目標 : \(targetGoal)")
                .font(.headline)
                .bold()
            HStack(spacing: 12) {
                Text("期限 : \(targetDateString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("(残り : \(remainingDateText))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var remainingDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let targetDate = formatter.date(from: targetDateString) else { return "00/00/00" }
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date(), to: targetDate)
        return String(format: "%02d/%02d/%02d", max(0, components.year ?? 0), max(0, components.month ?? 0), max(0, components.day ?? 0))
    }
    
    // Positive ヘッダー（タイトル幅を画面幅の半分に指定）
    private func positiveHeaderView(titleWidth: CGFloat) -> some View {
        ZStack {
            HStack {
                Button(action: {
                    applyPositiveDecreaseAction()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .disabled(selectedPositiveIDs.isEmpty)
                .opacity(selectedPositiveIDs.isEmpty ? 0.3 : 1.0)
                
                Spacer()
                
                Button(action: {
                    applyPositiveIncreaseAction()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color("PositiveColor"))
                }
                .disabled(selectedPositiveIDs.isEmpty)
                .opacity(selectedPositiveIDs.isEmpty ? 0.3 : 1.0)
            }
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("PositiveColor"))
                .frame(width: titleWidth, height: 40)
            
            Text("Positive")
                .foregroundColor(.white)
                .bold()
        }
        .frame(maxWidth: .infinity)
        .alert("ポジティブ要素を追加", isPresented: $showingAddPositive) {
            TextField("要素名", text: $inputTitle)
            Button("追加") {
                if !inputTitle.isEmpty {
                    modelContext.insert(ElementItem(title: inputTitle, isPositive: true))
                    inputTitle = ""
                }
            }
            Button("キャンセル", role: .cancel) { inputTitle = "" }
        }
    }
    
    // ゲージエリア
    private var gaugeSectionView: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(positivePoints)")
                    .foregroundColor(Color("PositiveColor"))
                    .bold()
                Spacer()
                Text("\(negativePoints)")
                    .foregroundColor(Color("NegativeColor"))
                    .bold()
            }
            .font(.subheadline)
            .padding(.horizontal, 4)
            
            let ratio = Double(positivePoints) / Double(maxPoints)
            
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let positiveWidth = max(0, min(totalWidth, totalWidth * ratio))
                let negativeWidth = max(0, totalWidth - positiveWidth)
                
                let positiveHistoriesText = histories.filter { $0.isPositive }.map { $0.title }.joined(separator: " ")
                let negativeHistoriesText = histories.filter { !$0.isPositive }.map { $0.title }.joined(separator: " ")
                
                HStack(spacing: 4) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("PositiveColor"))
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(positiveHistoriesText)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                    .frame(width: max(0, positiveWidth - 2), height: 48)
                    
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("NegativeColor"))
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(negativeHistoriesText)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .topTrailing)
                        }
                    }
                    .frame(width: max(0, negativeWidth - 2), height: 48)
                }
            }
            .frame(height: 48)
        }
    }
    
    // Negative フッター（タイトル幅を画面幅の半分に指定）
    private func negativeFooterView(titleWidth: CGFloat) -> some View {
        ZStack {
            HStack {
                Button(action: {
                    applyNegativeDecreaseAction()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color("NegativeColor"))
                }
                .disabled(selectedNegativeIDs.isEmpty)
                .opacity(selectedNegativeIDs.isEmpty ? 0.3 : 1.0)
                
                Spacer()
                
                Button(action: {
                    applyNegativeIncreaseAction()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .disabled(selectedNegativeIDs.isEmpty)
                .opacity(selectedNegativeIDs.isEmpty ? 0.3 : 1.0)
            }
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("NegativeColor"))
                .frame(width: titleWidth, height: 40)
            
            Text("Negative")
                .foregroundColor(.white)
                .bold()
        }
        .frame(maxWidth: .infinity)
        .alert("ネガティブ要素を追加", isPresented: $showingAddNegative) {
            TextField("要素名", text: $inputTitle)
            Button("追加") {
                if !inputTitle.isEmpty {
                    modelContext.insert(ElementItem(title: inputTitle, isPositive: false))
                    inputTitle = ""
                }
            }
            Button("キャンセル", role: .cancel) { inputTitle = "" }
        }
    }
    
    // 共通項目セル
    @ViewBuilder
    private func itemCell(item: ElementItem, isPositiveStyle: Bool, isSelected: Bool, onTap: @escaping () -> Void, onEdit: @escaping () -> Void) -> some View {
        HStack(spacing: 2) {
            Button(action: onTap) {
                Text(item.title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(isPositiveStyle ? Color("PositiveColor") : Color("NegativeColor"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(isSelected ? (isPositiveStyle ? Color("PositiveColor").opacity(0.15) : Color("NegativeColor").opacity(0.15)) : Color(.systemGray6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? (isPositiveStyle ? Color("PositiveColor") : Color("NegativeColor")) : Color.clear, lineWidth: 1.5)
        )
    }
    
    // MARK: - アクション処理
    
    private func applyPositiveIncreaseAction() {
        withAnimation {
            for id in selectedPositiveIDs {
                if let item = positiveItems.first(where: { $0.persistentModelID == id }) {
                    if positivePoints < maxPoints { positivePoints += 1 }
                    modelContext.insert(HistoryItem(title: item.title, isPositive: true))
                }
            }
            selectedPositiveIDs.removeAll()
        }
    }
    
    private func applyPositiveDecreaseAction() {
        withAnimation {
            for id in selectedPositiveIDs {
                if let item = positiveItems.first(where: { $0.persistentModelID == id }) {
                    if positivePoints > 0 { positivePoints -= 1 }
                }
            }
            selectedPositiveIDs.removeAll()
        }
    }
    
    private func applyNegativeDecreaseAction() {
        withAnimation {
            for id in selectedNegativeIDs {
                if let item = negativeItems.first(where: { $0.persistentModelID == id }) {
                    if positivePoints < maxPoints { positivePoints += 1 }
                    modelContext.insert(HistoryItem(title: item.title, isPositive: false))
                }
            }
            selectedNegativeIDs.removeAll()
        }
    }
    
    private func applyNegativeIncreaseAction() {
        withAnimation {
            for id in selectedNegativeIDs {
                if let item = negativeItems.first(where: { $0.persistentModelID == id }) {
                    if positivePoints > 0 { positivePoints -= 1 }
                }
            }
            selectedNegativeIDs.removeAll()
        }
    }
    
    private func setupInitialDataIfNeeded() {
        if positiveItems.isEmpty {
            let defaults = ["良質な睡眠", "高いスキル", "集中", "余白、スペース", "筋トレ", "メリハリ", "主体的", "投資", "リラックス", "柔らかさ", "スピード", "地の利", "ストレッチゾーン", "レバレッジ", "利他", "継続", "ミニマル", "人脈", "ワクワク", "仕組み", "不労", "汎用性", "問題解決", "時間(リソース)"]
            for title in defaults {
                modelContext.insert(ElementItem(title: title, isPositive: true))
            }
        }
        if negativeItems.isEmpty {
            let defaults = ["ノイズ", "短い睡眠", "反応的", "硬い", "時間がかかる", "コンフォートゾーン", "プロクラスティネーション", "モノが多い", "散漫", "利己", "頭でっかち", "退屈", "混雑"]
            for title in defaults {
                modelContext.insert(ElementItem(title: title, isPositive: false))
            }
        }
    }
}
