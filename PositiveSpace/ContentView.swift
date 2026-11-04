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

// 飛んでいくアニメーション用のデータ構造
struct FlyingItem: Identifiable {
    let id = UUID()
    let title: String
    let isPositive: Bool
    var isAnimating: Bool = false
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
    @AppStorage("targetDateString") private var targetDateString = "2026/12/31"
    @AppStorage("positivePoints") private var positivePoints: Int = 0
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    let maxPoints: Int = 200
    
    // 選択中のIDセット
    @State private var selectedPositiveIDs: Set<PersistentIdentifier> = []
    @State private var selectedNegativeIDs: Set<PersistentIdentifier> = []
    
    // 追加・編集モーダル用
    @State private var showingAddPositive = false
    @State private var showingAddNegative = false
    @State private var editingItem: ElementItem? = nil
    @State private var inputTitle = ""
    
    // 目標・期限の編集用アラート・シート状態
    @State private var showingEditGoal = false
    @State private var newGoalText = ""
    @State private var showingEditDate = false
    @State private var selectedDate = Date()
    
    // 履歴クリア確認アラート用
    @State private var showingClearPositiveAlert = false
    @State private var showingClearNegativeAlert = false
    
    // アニメーション用：飛んでいく項目のリスト
    @State private var flyingItems: [FlyingItem] = []
    
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
                let fullWidth = outerGeometry.size.width
                let fullHeight = outerGeometry.size.height
                let halfWidth = fullWidth * 0.45
                
                ZStack {
                    VStack(spacing: 12) {
                        // 1. 【固定】目標・期限ヘッダー
                        targetHeaderView
                            .padding(.horizontal)
                            .padding(.top, 4)
                        
                        // 2. 【固定】Positive ヘッダー
                        positiveHeaderView(titleWidth: halfWidth)
                            .padding(.horizontal)
                        
                        // 3. 【スクロール可能】Positive 項目リスト
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(positiveItems) { item in
                                    itemCell(item: item, isPositiveStyle: true, isSelected: selectedPositiveIDs.contains(item.persistentModelID)) {
                                        if selectedPositiveIDs.contains(item.persistentModelID) {
                                            selectedPositiveIDs.remove(item.persistentModelID)
                                        } else {
                                            selectedPositiveIDs.insert(item.persistentModelID)
                                        }
                                    } onLongPress: {
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
                        
                        // 5. 【スクロール可能】Negative 項目リスト
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(negativeItems) { item in
                                    itemCell(item: item, isPositiveStyle: false, isSelected: selectedNegativeIDs.contains(item.persistentModelID)) {
                                        if selectedNegativeIDs.contains(item.persistentModelID) {
                                            selectedNegativeIDs.remove(item.persistentModelID)
                                        } else {
                                            selectedNegativeIDs.insert(item.persistentModelID)
                                        }
                                    } onLongPress: {
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
                        
                        // 6. 【固定】Negative フッター
                        negativeFooterView(titleWidth: halfWidth)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                    
                    // ── 飛んでいくテキストのアニメーション用オーバーレイ ──
                    ForEach(flyingItems) { item in
                        let startX: CGFloat = item.isPositive ? fullWidth * 0.5 : fullWidth * 0.25
                        let startY: CGFloat = item.isPositive ? fullHeight * 0.18 : fullHeight * 0.88
                        
                        let targetX: CGFloat = item.isPositive ? fullWidth * 0.25 : fullWidth * 0.75
                        let targetY: CGFloat = item.isPositive ? fullHeight * 0.35 : fullHeight * 0.45
                        
                        Text(item.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(item.isPositive ? Color("PositiveColor") : Color("NegativeColor"))
                            .cornerRadius(12)
                            .shadow(radius: 3)
                            .position(
                                x: item.isAnimating ? targetX : startX,
                                y: item.isAnimating ? targetY : startY
                            )
                            .scaleEffect(item.isAnimating ? 0.4 : 1.2)
                            .opacity(item.isAnimating ? 0.0 : 1.0)
                            .animation(.easeOut(duration: 0.45), value: item.isAnimating)
                    }
                    
                    // ── 初回起動時チュートリアル画像オーバーレイ ──
                    if !hasSeenTutorial {
                        ZStack {
                            Color.black.opacity(0.8)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation {
                                        hasSeenTutorial = true
                                    }
                                }
                            
                            VStack(spacing: 20) {
                                Text("「Positive Space」へようこそ！")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.white)
                                
                                Text("画面をタップしてスタート")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .zIndex(999)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupInitialDataIfNeeded()
            }
            // 各種アラート・シート
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
            .alert("目標を編集", isPresented: $showingEditGoal) {
                TextField("目標", text: $newGoalText)
                Button("保存") {
                    if !newGoalText.isEmpty {
                        targetGoal = newGoalText
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
            .alert("Positive履歴のクリア", isPresented: $showingClearPositiveAlert) {
                Button("クリアする", role: .destructive) {
                    clearHistories(isPositive: true)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("Positive側の履歴文字をすべてクリアしますか？")
            }
            .alert("Negative履歴のクリア", isPresented: $showingClearNegativeAlert) {
                Button("クリアする", role: .destructive) {
                    clearHistories(isPositive: false)
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("Negative側の履歴文字をすべてクリアしますか？")
            }
            .sheet(isPresented: $showingEditDate) {
                VStack(spacing: 20) {
                    Text("期限を選択")
                        .font(.headline)
                        .padding(.top)
                    
                    DatePicker("期限", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    
                    Button("決定") {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy/MM/dd"
                        targetDateString = formatter.string(from: selectedDate)
                        showingEditDate = false
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - 各パーツ
    
    private var targetHeaderView: some View {
        VStack(alignment: .center, spacing: 2) {
            Button(action: {
                newGoalText = targetGoal
                showingEditGoal = true
            }) {
                Text("目標 : \(targetGoal)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Button(action: {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy/MM/dd"
                selectedDate = formatter.date(from: targetDateString) ?? Date()
                showingEditDate = true
            }) {
                HStack(spacing: 12) {
                    Text("期限 : \(targetDateString)")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.primary)
                    Text("(残り : \(remainingDateText))")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var remainingDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        guard let targetDate = formatter.date(from: targetDateString) else { return "00/00/00" }
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date(), to: targetDate)
        return String(format: "%02d/%02d/%02d", max(0, components.year ?? 0), max(0, components.month ?? 0), max(0, components.day ?? 0))
    }
    
    // Positive ヘッダー
    private func positiveHeaderView(titleWidth: CGFloat) -> some View {
        ZStack {
            HStack {
                Button(action: {
                    applyPositiveDecreaseAction()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                .disabled(selectedPositiveIDs.isEmpty)
                .opacity(selectedPositiveIDs.isEmpty ? 0.3 : 1.0)
                
                Spacer()
                
                Button(action: {
                    applyPositiveIncreaseAction()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 66))
                        .foregroundColor(Color("PositiveColor"))
                }
                .disabled(selectedPositiveIDs.isEmpty)
                .opacity(selectedPositiveIDs.isEmpty ? 0.3 : 1.0)
            }
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .frame(width: titleWidth, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color("PositiveColor"), lineWidth: 2)
                )
            
            Text("Positive")
                .foregroundColor(Color("PositiveColor"))
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
    
    // ゲージエリア（文字サイズを 10 に変更）
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
                    // Positive側ゲージ
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color("PositiveColor"))
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(positiveHistoriesText)
                                .font(.system(size: 10)) // 文字サイズ10に変更
                                .foregroundColor(.white)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                    .frame(width: max(0, positiveWidth - 2), height: 72)
                    .onLongPressGesture {
                        showingClearPositiveAlert = true
                    }
                    
                    // Negative側ゲージ
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color("NegativeColor"))
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(negativeHistoriesText)
                                .font(.system(size: 10)) // 文字サイズ10に変更
                                .foregroundColor(.white)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .topTrailing)
                        }
                    }
                    .frame(width: max(0, negativeWidth - 2), height: 72)
                    .onLongPressGesture {
                        showingClearNegativeAlert = true
                    }
                }
            }
            .frame(height: 72)
        }
    }
    
    // Negative フッター
    private func negativeFooterView(titleWidth: CGFloat) -> some View {
        ZStack {
            HStack {
                Button(action: {
                    applyNegativeDecreaseAction()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 66))
                        .foregroundColor(Color("NegativeColor"))
                }
                .disabled(selectedNegativeIDs.isEmpty)
                .opacity(selectedNegativeIDs.isEmpty ? 0.3 : 1.0)
                
                Spacer()
                
                Button(action: {
                    applyNegativeIncreaseAction()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                .disabled(selectedNegativeIDs.isEmpty)
                .opacity(selectedNegativeIDs.isEmpty ? 0.3 : 1.0)
            }
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .frame(width: titleWidth, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color("NegativeColor"), lineWidth: 2)
                )
            
            Text("Negative")
                .foregroundColor(Color("NegativeColor"))
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
    private func itemCell(item: ElementItem, isPositiveStyle: Bool, isSelected: Bool, onTap: @escaping () -> Void, onLongPress: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(item.title)
                .font(.body)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(isPositiveStyle ? Color("PositiveColor") : Color("NegativeColor"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
        }
        .buttonStyle(OriginalStyleHighlightableButtonStyle(isSelected: isSelected, isPositiveStyle: isPositiveStyle))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress()
                }
        )
    }
    
    // MARK: - アクション処理（アニメーション付き）
    
    private func applyPositiveIncreaseAction() {
        let titlesToFly = positiveItems.filter { selectedPositiveIDs.contains($0.persistentModelID) }.map { $0.title }
        
        withAnimation {
            for id in selectedPositiveIDs {
                if let item = positiveItems.first(where: { $0.persistentModelID == id }) {
                    if positivePoints < maxPoints { positivePoints += 1 }
                    modelContext.insert(HistoryItem(title: item.title, isPositive: true))
                }
            }
            selectedPositiveIDs.removeAll()
        }
        
        triggerFlyingAnimation(titles: titlesToFly, isPositive: true)
    }
    
    private func applyPositiveDecreaseAction() {
        withAnimation {
            for id in selectedPositiveIDs {
                if let _ = positiveItems.first(where: { $0.persistentModelID == id }) {
                    if positivePoints > 0 { positivePoints -= 1 }
                }
            }
            selectedPositiveIDs.removeAll()
        }
    }
    
    private func applyNegativeDecreaseAction() {
        let titlesToFly = negativeItems.filter { selectedNegativeIDs.contains($0.persistentModelID) }.map { $0.title }
        
        withAnimation {
            for id in selectedNegativeIDs {
                if let item = negativeItems.first(where: { $0.persistentModelID == id }) {
                    if positivePoints < maxPoints { positivePoints += 1 }
                    modelContext.insert(HistoryItem(title: item.title, isPositive: false))
                }
            }
            selectedNegativeIDs.removeAll()
        }
        
        triggerFlyingAnimation(titles: titlesToFly, isPositive: false)
    }
    
    private func applyNegativeIncreaseAction() {
        withAnimation {
            for id in selectedNegativeIDs {
                // エラーの原因となっていた未使用の item 定義を解消
                if negativeItems.contains(where: { $0.persistentModelID == id }) {
                    if positivePoints > 0 { positivePoints -= 1 }
                }
            }
            selectedNegativeIDs.removeAll()
        }
    }
    
    // 飛ぶアニメーションの生成・消去
    private func triggerFlyingAnimation(titles: [String], isPositive: Bool) {
        for title in titles {
            let flyingItem = FlyingItem(title: title, isPositive: isPositive)
            flyingItems.append(flyingItem)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let index = flyingItems.firstIndex(where: { $0.id == flyingItem.id }) {
                    flyingItems[index].isAnimating = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                flyingItems.removeAll(where: { $0.id == flyingItem.id })
            }
        }
    }
    
    // 指定した側の履歴データを一括削除する
    private func clearHistories(isPositive: Bool) {
        withAnimation {
            for history in histories {
                if history.isPositive == isPositive {
                    modelContext.delete(history)
                }
            }
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

// MARK: - 選択時は従来の色、長押し（プレス）時のみ ActiveColor を使用するボタンスタイル
struct OriginalStyleHighlightableButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isPositiveStyle: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        let baseColor = isPositiveStyle ? Color("PositiveColor") : Color("NegativeColor")
        let activeColor = Color("ActiveColor")
        
        let backgroundColor: Color = {
            if configuration.isPressed {
                return activeColor.opacity(0.3) // 長押し/プレス時のみ ActiveColor
            } else if isSelected {
                return baseColor.opacity(0.15) // 選択時は従来の色
            } else {
                return Color(.systemGray6)
            }
        }()
        
        let strokeColor: Color = {
            if configuration.isPressed {
                return activeColor
            } else if isSelected {
                return baseColor
            } else {
                return Color.clear
            }
        }()
        
        return configuration.label
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(strokeColor, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
