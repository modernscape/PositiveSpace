import SwiftUI
import SwiftData
import PhotosUI

// MARK: - SwiftData モデル定義（安全なマイグレーション対応版）

@Model
class ElementItem {
    var id: UUID
    var title: String
    var isPositive: Bool
    var count: Int = 0
    var imageData: Data? = nil
    
    init(title: String, isPositive: Bool, count: Int = 0, imageData: Data? = nil) {
        self.id = UUID()
        self.title = title
        self.isPositive = isPositive
        self.count = count
        self.imageData = imageData
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
    
    @Query(
        filter: #Predicate<ElementItem> { $0.isPositive == true },
        sort: [SortDescriptor(\ElementItem.count, order: .reverse)]
    )
    private var positiveItems: [ElementItem]
    
    @Query(
        filter: #Predicate<ElementItem> { $0.isPositive == false },
        sort: [SortDescriptor(\ElementItem.count, order: .reverse)]
    )
    private var negativeItems: [ElementItem]
    
    @Query(sort: \HistoryItem.date, order: .reverse)
    private var histories: [HistoryItem]
    
    // データ保存
    @AppStorage("targetGoal") private var targetGoal = "月収100万円"
    @AppStorage("targetDateString") private var targetDateString = "2026/11/03"
    @AppStorage("positivePoints") private var positivePoints: Int = 0
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    let maxPoints: Int = 200
    
    // 選択中のIDセット
    @State private var selectedPositiveIDs: Set<PersistentIdentifier> = []
    @State private var selectedNegativeIDs: Set<PersistentIdentifier> = []
    @State private var selectedOrderIDs: [PersistentIdentifier] = []
    @State private var cachedPreviewImageData: Data? = nil
    
    // 追加モーダル用
    @State private var showingAddPositive = false
    @State private var showingAddNegative = false
    @State private var editingItem: ElementItem? = nil
    @State private var inputTitle = ""
    
    // タイトルタップによる項目一覧モーダル用
    @State private var showingPositiveListModal = false
    @State private var showingNegativeListModal = false
    
    // 目標・期限の編集用
    @State private var showingEditGoal = false
    @State private var newGoalText = ""
    @State private var showingEditDate = false
    @State private var selectedDate = Date()
    
    // 履歴クリア確認アラート用
    @State private var showingClearPositiveAlert = false
    @State private var showingClearNegativeAlert = false
    
    // アニメーション用
    @State private var flyingItems: [FlyingItem] = []
    
    // チュートリアル表示フラグ
    @State private var showingTutorialOverlay = false
    
    var negativePoints: Int {
        max(0, maxPoints - positivePoints)
    }
    
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6)
        ]
    }
    
    // 最後に選択された項目の画像を維持するロジック
    private var activePreviewImageData: Data? {
        for id in selectedOrderIDs.reversed() {
            if let item = positiveItems.first(where: { $0.persistentModelID == id }), let data = item.imageData {
                return data
            }
            if let item = negativeItems.first(where: { $0.persistentModelID == id }), let data = item.imageData {
                return data
            }
        }
        
        if selectedOrderIDs.isEmpty {
            return nil
        }
        return cachedPreviewImageData
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { outerGeometry in
                let fullWidth = outerGeometry.size.width
                let fullHeight = outerGeometry.size.height
                let halfWidth = fullWidth * 0.45
                
                ZStack {
                    VStack(spacing: 12) {
                        // 1. 目標・期限ヘッダー（右上に "text.pad.header" アイコンのボタンを配置）
                        ZStack(alignment: .trailing) {
                            targetHeaderView
                                .frame(maxWidth: .infinity)
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingTutorialOverlay = true
                                }
                            }) {
                                Image(systemName: "document.circle.fill") //
                                    .font(.system(size: 22))
                                    .foregroundColor(.primary.opacity(0.7))
                                    .padding(.trailing, 4)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        
                        // 2. Positive ヘッダー
                        positiveHeaderView(titleWidth: halfWidth)
                            .padding(.horizontal)
                        
                        // 3. Positive 項目リスト
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(positiveItems) { item in
                                    itemCell(item: item, isPositiveStyle: true, isSelected: selectedPositiveIDs.contains(item.persistentModelID)) {
                                        togglePositiveSelection(id: item.persistentModelID)
                                    } onLongPress: {
                                        editingItem = item
                                        inputTitle = item.title
                                    }
                                }
                                
                                Button(action: { showingAddPositive = true }) {
                                    Image(systemName: "plus")
                                        .foregroundColor(Color("PositiveColor"))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                selectedPositiveIDs.removeAll()
                                selectedNegativeIDs.removeAll()
                                selectedOrderIDs.removeAll()
                                cachedPreviewImageData = nil
                            }
                        }
                        
                        // 4. 中央ゲージエリア
                        gaugeSectionView
                            .padding(.horizontal)
                        
                        // 5. Negative 項目リスト
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(negativeItems) { item in
                                    itemCell(item: item, isPositiveStyle: false, isSelected: selectedNegativeIDs.contains(item.persistentModelID)) {
                                        toggleNegativeSelection(id: item.persistentModelID)
                                    } onLongPress: {
                                        editingItem = item
                                        inputTitle = item.title
                                    }
                                }
                                
                                Button(action: { showingAddNegative = true }) {
                                    Image(systemName: "plus")
                                        .foregroundColor(Color("NegativeColor"))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                selectedPositiveIDs.removeAll()
                                selectedNegativeIDs.removeAll()
                                selectedOrderIDs.removeAll()
                                cachedPreviewImageData = nil
                            }
                        }
                        
                        // 6. Negative フッター
                        negativeFooterView(titleWidth: halfWidth)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                    
                    // ── 選択された項目の画像を画面左上に表示 ──
                    VStack {
                        HStack {
                            if let data = activePreviewImageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .clipped()
                                    .shadow(radius: 4)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Spacer()
                        }
                        .padding(.leading, 16)
                        .padding(.top, 4)
                        Spacer()
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activePreviewImageData != nil)
                    .allowsHitTesting(false)
                    
                    // アニメーション用フローティングレイヤー
                    IndependentFlyingAnimationOverlay(
                        flyingItems: flyingItems,
                        containerSize: CGSize(width: fullWidth, height: fullHeight)
                    )
                }
            }
            .overlay(
                Group {
                    if showingTutorialOverlay {
                        ZStack {
                            Color.black.opacity(0.5)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showingTutorialOverlay = false
                                    }
                                }
                            
                            TutorialCardView {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingTutorialOverlay = false
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .zIndex(999)
                    }
                }
            )
            .navigationBarHidden(true)
            .onAppear {
                setupInitialDataIfNeeded()
                if !hasSeenTutorial {
                    showingTutorialOverlay = true
                    hasSeenTutorial = true
                }
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
                    
                    DatePicker("期限", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ja_JP")) // ★ ここを追加して日本語に固定する
                    
                    Button("決定") {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy/MM/dd"
                        // ★ 実機の地域設定に依存しないよう、明示的にロケールとカレンダーを設定する
                        formatter.locale = Locale(identifier: "ja_JP")
                        formatter.calendar = Calendar(identifier: .gregorian)
                        
                        targetDateString = formatter.string(from: selectedDate)
                        showingEditDate = false
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingPositiveListModal) {
                ElementManagementView(isPositive: true)
            }
            .sheet(isPresented: $showingNegativeListModal) {
                ElementManagementView(isPositive: false)
            }
        }
    }
    
    // MARK: - 選択処理ヘルパー
    private func togglePositiveSelection(id: PersistentIdentifier) {
        if selectedPositiveIDs.contains(id) {
            selectedPositiveIDs.remove(id)
            selectedOrderIDs.removeAll(where: { $0 == id })
        } else {
            selectedPositiveIDs.insert(id)
            selectedOrderIDs.append(id)
            if let item = positiveItems.first(where: { $0.persistentModelID == id }), let data = item.imageData {
                cachedPreviewImageData = data
            }
        }
        if selectedPositiveIDs.isEmpty && selectedNegativeIDs.isEmpty {
            cachedPreviewImageData = nil
            selectedOrderIDs.removeAll()
        }
    }
    
    private func toggleNegativeSelection(id: PersistentIdentifier) {
        if selectedNegativeIDs.contains(id) {
            selectedNegativeIDs.remove(id)
            selectedOrderIDs.removeAll(where: { $0 == id })
        } else {
            selectedNegativeIDs.insert(id)
            selectedOrderIDs.append(id)
            if let item = negativeItems.first(where: { $0.persistentModelID == id }), let data = item.imageData {
                cachedPreviewImageData = data
            }
        }
        if selectedPositiveIDs.isEmpty && selectedNegativeIDs.isEmpty {
            cachedPreviewImageData = nil
            selectedOrderIDs.removeAll()
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
                    Text("(残り: \(remainingDateText))")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // 残り日数を「◯年◯月◯日」形式にし、0の項目は省略する
    private var remainingDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        
        guard let targetDate = formatter.date(from: targetDateString) else { return "0日" }
        
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date(), to: targetDate)
        let years = max(0, components.year ?? 0)
        let months = max(0, components.month ?? 0)
        let days = max(0, components.day ?? 0)
        
        var parts: [String] = []
        if years > 0 {
            parts.append("\(years)年")
        }
        if months > 0 {
            parts.append("\(months)ヶ月")
        }
        // 日数が 0 でも、年・月・日すべてが 0 の場合は「0日」と表示させるため parts.isEmpty を考慮
        if days > 0 || parts.isEmpty {
            parts.append("\(days)日")
        }
        
        return parts.joined()
    }
    
    private func positiveHeaderView(titleWidth: CGFloat) -> some View {
        ZStack {
            HStack {
                Button(action: { applyPositiveDecreaseAction() }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                .disabled(selectedPositiveIDs.isEmpty)
                .opacity(selectedPositiveIDs.isEmpty ? 0.3 : 1.0)
                
                Spacer()
                
                Button(action: { applyPositiveIncreaseAction() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 66))
                        .foregroundColor(Color("PositiveColor"))
                }
                .disabled(selectedPositiveIDs.isEmpty)
                .opacity(selectedPositiveIDs.isEmpty ? 0.3 : 1.0)
            }
            
            // 全体が確実にボタンとして反応するPositiveタイトルボタン
            Button(action: { showingPositiveListModal = true }) {
                Text("Positive")
                    .foregroundColor(Color("PositiveColor"))
                    .bold()
                    .frame(width: titleWidth, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color("PositiveColor"), lineWidth: 2)
                            )
                    )
            }
            .buttonStyle(.plain)
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
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color("PositiveColor"))
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(positiveHistoriesText)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                    .frame(width: max(0, positiveWidth - 2), height: 72)
                    .onLongPressGesture { showingClearPositiveAlert = true }
                    
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color("NegativeColor"))
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(negativeHistoriesText)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .topTrailing)
                        }
                    }
                    .frame(width: max(0, negativeWidth - 2), height: 72)
                    .onLongPressGesture { showingClearNegativeAlert = true }
                }
            }
            .frame(height: 72)
        }
    }
    
    private func negativeFooterView(titleWidth: CGFloat) -> some View {
        ZStack {
            HStack {
                Button(action: { applyNegativeDecreaseAction() }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 66))
                        .foregroundColor(Color("NegativeColor"))
                }
                .disabled(selectedNegativeIDs.isEmpty)
                .opacity(selectedNegativeIDs.isEmpty ? 0.3 : 1.0)
                
                Spacer()
                
                Button(action: { applyNegativeIncreaseAction() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                .disabled(selectedNegativeIDs.isEmpty)
                .opacity(selectedNegativeIDs.isEmpty ? 0.3 : 1.0)
            }
            
            // 全体が確実にボタンとして反応するNegativeタイトルボタン
            Button(action: { showingNegativeListModal = true }) {
                Text("Negative")
                    .foregroundColor(Color("NegativeColor"))
                    .bold()
                    .frame(width: titleWidth, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color("NegativeColor"), lineWidth: 2)
                            )
                    )
            }
            .buttonStyle(.plain)
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
            ZStack(alignment: .bottomTrailing) {
                if item.imageData != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "photo.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(3)
                            Spacer()
                        }
                    }
                }
                
                Text(item.title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1...2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(isPositiveStyle ? Color("PositiveColor") : Color("NegativeColor"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, 4)
                
                if item.count > 0 {
                    Text("\(item.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isPositiveStyle ? Color("PositiveColor").opacity(0.8) : Color("NegativeColor").opacity(0.8))
                        .padding(3)
                }
            }
            .frame(height: 42)
        }
        .buttonStyle(OriginalStyleHighlightableButtonStyle(isSelected: isSelected, isPositiveStyle: isPositiveStyle))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress()
                }
        )
    }
    
    private func applyPositiveIncreaseAction() {
        let targets = positiveItems.filter { selectedPositiveIDs.contains($0.persistentModelID) }
        let titlesToFly = targets.map { $0.title }
        let targetIDs = targets.map { $0.persistentModelID }
        
        withAnimation {
            selectedPositiveIDs.removeAll()
            selectedOrderIDs.removeAll()
            cachedPreviewImageData = nil
        }
        
        let totalDuration = Double(max(0, titlesToFly.count - 1)) * 0.12 + 0.45
        triggerSequentialFlyingAnimation(titles: titlesToFly, isPositive: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            withAnimation {
                for id in targetIDs {
                    if let item = positiveItems.first(where: { $0.persistentModelID == id }) {
                        if positivePoints < maxPoints { positivePoints += 1 }
                        item.count += 1
                        modelContext.insert(HistoryItem(title: item.title, isPositive: true))
                    }
                }
            }
        }
    }
    
    private func applyPositiveDecreaseAction() {
        withAnimation {
            for id in selectedPositiveIDs {
                if let item = positiveItems.first(where: { $0.persistentModelID == id }) {
                    if positivePoints > 0 { positivePoints -= 1 }
                    if item.count > 0 { item.count -= 1 }
                }
            }
            selectedPositiveIDs.removeAll()
            selectedOrderIDs.removeAll()
            if selectedNegativeIDs.isEmpty { cachedPreviewImageData = nil }
        }
    }
    
    private func applyNegativeDecreaseAction() {
        let targets = negativeItems.filter { selectedNegativeIDs.contains($0.persistentModelID) }
        let titlesToFly = targets.map { $0.title }
        let targetIDs = targets.map { $0.persistentModelID }
        
        withAnimation {
            selectedNegativeIDs.removeAll()
            selectedOrderIDs.removeAll()
            cachedPreviewImageData = nil
        }
        
        let totalDuration = Double(max(0, titlesToFly.count - 1)) * 0.12 + 0.45
        triggerSequentialFlyingAnimation(titles: titlesToFly, isPositive: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            withAnimation {
                for id in targetIDs {
                    if let item = negativeItems.first(where: { $0.persistentModelID == id }) {
                        if positivePoints < maxPoints { positivePoints += 1 }
                        item.count += 1
                        modelContext.insert(HistoryItem(title: item.title, isPositive: false))
                    }
                }
            }
        }
    }
    
    private func applyNegativeIncreaseAction() {
        withAnimation {
            for id in selectedNegativeIDs {
                if let item = negativeItems.first(where: { $0.persistentModelID == id }) {
                    if positivePoints > 0 { positivePoints -= 1 }
                    if item.count > 0 { item.count -= 1 }
                }
            }
            selectedNegativeIDs.removeAll()
            selectedOrderIDs.removeAll()
            if selectedPositiveIDs.isEmpty { cachedPreviewImageData = nil }
        }
    }
    
    private func triggerSequentialFlyingAnimation(titles: [String], isPositive: Bool) {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        
        for (index, title) in titles.enumerated() {
            let delay = Double(index) * 0.12
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                feedbackGenerator.impactOccurred()
                let flyingItem = FlyingItem(title: title, isPositive: isPositive)
                flyingItems.append(flyingItem)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if let idx = flyingItems.firstIndex(where: { $0.id == flyingItem.id }) {
                        flyingItems[idx].isAnimating = true
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    flyingItems.removeAll(where: { $0.id == flyingItem.id })
                }
            }
        }
    }
    
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

// MARK: - チュートリアルカードビュー
struct TutorialCardView: View {
    var onClose: () -> Void
    
    var body: some View {
        ZStack {
            Image("Tutorial Image")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("「Positive Space」へようこそ！")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                
                Text("画面をタップして閉じる")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(radius: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            onClose()
        }
    }
}

// MARK: - 項目一覧・管理画面（元に戻した安定版）
struct ElementManagementView: View {
    let isPositive: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var items: [ElementItem]
    
    @State private var showingAddAlert = false
    @State private var newTitle = ""
    @State private var editingItem: ElementItem? = nil
    @State private var editTitle = ""
    
    private var filteredItems: [ElementItem] {
        items.filter { $0.isPositive == isPositive }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(filteredItems) { item in
                        ZStack(alignment: .bottom) {
                            if let data = item.imageData, let uiImage = UIImage(data: data) {
                                GeometryReader { geometry in
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(
                                            width: geometry.size.width,
                                            height: 90
                                        )
                                        .clipped()
                                        .cornerRadius(12)
                                }
                                .frame(height: 90)
         
                                
//                                Image(uiImage: uiImage)
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(width: 50, height: 50)
//                                    .clipped()
//                                    .shadow(radius: 4)
//                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 90)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            Text(item.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1...2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.6))
                                .cornerRadius(6)
                                .padding(4)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingItem = item
                            editTitle = item.title
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(isPositive ? "Positive 項目一覧" : "Negative 項目一覧")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddAlert = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .alert("項目を追加", isPresented: $showingAddAlert) {
                TextField("項目名", text: $newTitle)
                Button("追加") {
                    if !newTitle.isEmpty {
                        modelContext.insert(ElementItem(title: newTitle, isPositive: isPositive))
                        newTitle = ""
                    }
                }
                Button("キャンセル", role: .cancel) { newTitle = "" }
            }
            .sheet(item: $editingItem) { item in
                ElementDetailEditView(item: item)
            }
        }
    }
}

// MARK: - 項目個別の詳細編集画面
struct ElementDetailEditView: View {
    @Bindable var item: ElementItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section("項目名") {
                    TextField("項目名", text: $item.title)
                }
                
                Section("イメージ画像") {
                    HStack {
                        Spacer()
                        if let data = item.imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .cornerRadius(10)
                        } else {
                            Text("画像が設定されていません")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("画像を選択・変更", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: selectedPhotoItem) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                item.imageData = data
                            }
                        }
                    }
                    
                    if item.imageData != nil {
                        Button("画像を削除", role: .destructive) {
                            item.imageData = nil
                        }
                    }
                }
                
                Section {
                    Button("この項目を削除", role: .destructive) {
                        modelContext.delete(item)
                        dismiss()
                    }
                }
            }
            .navigationTitle("項目詳細・編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}

// MARK: - フローティングレイヤー
struct IndependentFlyingAnimationOverlay: View {
    let flyingItems: [FlyingItem]
    let containerSize: CGSize
    
    var body: some View {
        ZStack {
            ForEach(flyingItems) { item in
                let startX: CGFloat = containerSize.width * 0.5
                let startY: CGFloat = item.isPositive ? containerSize.height * 0.16 : containerSize.height * 0.84
                let targetX: CGFloat = containerSize.width * 0.5
                let targetY: CGFloat = item.isPositive ? containerSize.height * 0.42 : containerSize.height * 0.52
                
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
                    .scaleEffect(item.isAnimating ? 0.35 : 1.1)
                    .opacity(item.isAnimating ? 0.0 : 1.0)
                    .animation(.easeInOut(duration: 0.45), value: item.isAnimating)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - ボタンスタイル
struct OriginalStyleHighlightableButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isPositiveStyle: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        let baseColor = isPositiveStyle ? Color("PositiveColor") : Color("NegativeColor")
        let activeColor = Color("ActiveColor")
        
        let backgroundColor: Color = {
            if configuration.isPressed {
                return activeColor.opacity(0.3)
            } else if isSelected {
                return baseColor.opacity(0.15)
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
