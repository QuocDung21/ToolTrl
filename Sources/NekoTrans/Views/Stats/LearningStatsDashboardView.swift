import SwiftUI
import Charts
#if canImport(AppKit)
import AppKit
#endif

public enum StatsTimeRange: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    case year = 12

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .week: return "7 ngày"
        case .month: return "30 ngày"
        case .year: return "12 tháng"
        }
    }
}

public enum ChartPresentationStyle: String, CaseIterable, Identifiable {
    case bar = "Cột"
    case area = "Xu hướng"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .bar: return "chart.bar.fill"
        case .area: return "chart.line.uptrend.xyaxis"
        }
    }
}

public struct LearningStatsDashboardView: View {
    @ObservedObject var statsService = LookupStatsService.shared
    @ObservedObject var vocabService = VocabularyService.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var timeRange: StatsTimeRange = .week
    @State private var chartStyle: ChartPresentationStyle = .bar
    @State private var hoveredDateLabel: String? = nil
    @State private var hoveredItemIndex: Int? = nil
    @State private var justSavedWords: Set<String> = []
    
    // Smooth Animation & Interactive Hover States
    @State private var animateChart: Bool = false
    @State private var selectedDateLabel: String? = nil
    @State private var selectedGenre: ItemThematicGenre? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Pinned Header & Scope Controls (Never scrolls into window toolbar)
            responsiveHeaderToolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(VisualEffectBackground(material: .headerView, blendingMode: .withinWindow))

            Divider()

            // Scrollable Metrics & Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 2. Responsive Summary Metric Grid (Adapts 4-col -> 2x2 -> 1-col)
                    responsiveSummaryGrid

                    // 3. Primary Activity Chart Box (macOS Screen Time / Battery style)
                    primaryChartGroupBox

                    // 4. Dual Section: Daily Targets & Thematic Distribution (Adaptive 2-col / Stack)
                    responsiveMiddleSection

                    // 5. Words Needing Review (Repeated Lookups)
                    wordsNeedingReviewGroupBox
                }
                .padding(16)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.35))
        .onAppear {
            triggerChartAnimation()
        }
        .onChange(of: timeRange) { _, _ in
            selectedDateLabel = nil
            triggerChartAnimation()
        }
        .onChange(of: chartStyle) { _, _ in
            triggerChartAnimation()
        }
    }
    
    private func triggerChartAnimation() {
        animateChart = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                animateChart = true
            }
        }
    }

    // MARK: - 1. Responsive Header Toolbar
    private var responsiveHeaderToolbar: some View {
        HStack(alignment: .center, spacing: 12) {
            headerTitleView
            Spacer(minLength: 16)
            rangeSegmentedPicker
        }
    }

    private var headerTitleView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Thống Kê Hoạt Động")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)

            Text("Dữ liệu tra cứu và tiến độ học từ vựng theo thời gian thực")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
        }
    }

    private var rangeSegmentedPicker: some View {
        Picker("", selection: $timeRange) {
            ForEach(StatsTimeRange.allCases) { r in
                Text(r.label).tag(r)
            }
        }
        .pickerStyle(.segmented)
        .frame(minWidth: 180, maxWidth: 200)
    }

    // MARK: - 2. Responsive Summary Grid (Adaptive Columns)
    private var responsiveSummaryGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            // Tile 1: Words Today
            metricTile(
                title: "Từ mới hôm nay",
                value: "\(statsService.uniqueLookupsToday)",
                subtext: "Mục tiêu: \(statsService.dailyGoal) từ",
                badge: "\(Int(statsService.todayGoalProgress * 100))%",
                badgeColor: statsService.todayGoalProgress >= 1.0 ? .green : .blue,
                symbol: "character.book.closed"
            )

            // Tile 2: Mastered Words
            let mastered = vocabService.savedWords.filter { $0.isMastered }.count
            metricTile(
                title: "Từ đã ghi nhớ",
                value: "\(mastered)",
                subtext: "Đã đánh dấu thuộc",
                badge: "✨ Thành tích",
                badgeColor: .purple,
                symbol: "checkmark.seal.fill"
            )

            // Tile 3: Streak
            let streak = statsService.currentStreak
            metricTile(
                title: "Chuỗi học tập",
                value: "\(streak) ngày",
                subtext: streak > 0 ? "Đang duy trì đều" : "Bắt đầu hôm nay",
                badge: streak > 0 ? "🔥 Duy trì" : "—",
                badgeColor: .orange,
                symbol: "flame"
            )

            // Tile 4: Notebook Total
            let totalSaved = vocabService.savedWords.count
            metricTile(
                title: "Sổ tay từ vựng",
                value: "\(totalSaved)",
                subtext: "Đã thuộc: \(mastered) từ",
                badge: totalSaved > 0 ? "\(Int(Double(mastered) / Double(totalSaved) * 100))% thuộc" : "0%",
                badgeColor: .green,
                symbol: "books.vertical"
            )
        }
    }

    private func metricTile(
        title: String,
        value: String,
        subtext: String,
        badge: String,
        badgeColor: Color,
        symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text(badge)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.12))
                    .foregroundColor(badgeColor)
                    .clipShape(Capsule())
            }

            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.45))
            }

            Text(subtext)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.8)
        )
    }

    // MARK: - 3. Primary Activity Chart (Clean Native macOS HIG)
    private var primaryChartGroupBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                // Top Header Inside Chart Box
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Số lượng từ vựng tra cứu")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)

                        let subtitle = timeRange == .year ? "Dữ liệu tra cứu qua từng tháng" : "Đã lọc trùng lặp trong ngày"
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Chart Style Segmented Switcher (Bar vs Smooth Area)
                    Picker("", selection: $chartStyle) {
                        ForEach(ChartPresentationStyle.allCases) { style in
                            Label(style.rawValue, systemImage: style.icon).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)

                    // Target indicator
                    let goalVal = statsService.dailyGoal
                    if timeRange != .year {
                        HStack(spacing: 5) {
                            Rectangle()
                                .fill(Color.orange)
                                .frame(width: 12, height: 2)
                                .cornerRadius(1)
                            Text("Chỉ tiêu: \(goalVal) từ/ngày")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(4)
                    }
                }

                // Quick KPI Metric Strip
                chartKPIStrip

                Divider().opacity(0.3)

                // Ultra-Smooth Chart Rendering via ApexCharts
                primaryActivityApexChart
            }
            .padding(8)
        } label: {
            EmptyView()
        }
    }

    // MARK: - KPI Metric Strip
    private var chartKPIStrip: some View {
        HStack(spacing: 10) {
            if timeRange == .year {
                let kpi = monthlyWordsKPIs()
                kpiItem(title: "Tổng tra cứu", value: "\(kpi.total) từ", icon: "book.closed.fill", color: .blue)
                kpiItem(title: "Trung bình", value: "\(String(format: "%.1f", kpi.avg)) từ/tháng", icon: "chart.line.uptrend.xyaxis", color: .purple)
                kpiItem(title: "Đỉnh điểm", value: "\(kpi.peak) từ (\(kpi.peakMonth))", icon: "flame.fill", color: .orange)
            } else {
                let kpi = wordsKPIs(days: timeRange.rawValue)
                kpiItem(title: "Tổng kỳ", value: "\(kpi.total) từ", icon: "book.closed.fill", color: .blue)
                kpiItem(title: "Trung bình", value: "\(String(format: "%.1f", kpi.avg)) từ/ngày", icon: "chart.line.uptrend.xyaxis", color: .purple)
                kpiItem(title: "Đỉnh điểm", value: "\(kpi.peak) từ (\(kpi.peakDay))", icon: "flame.fill", color: .orange)
                let pct = kpi.totalDays > 0 ? Int((Double(kpi.goalDaysCount) / Double(kpi.totalDays)) * 100) : 0
                kpiItem(title: "Đạt chỉ tiêu", value: "\(pct)% (\(kpi.goalDaysCount)/\(kpi.totalDays) ngày)", icon: "target", color: pct >= 70 ? .green : .accentColor)
            }
            Spacer()
        }
    }

    private func kpiItem(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10.5))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }

    private func wordsKPIs(days: Int) -> (total: Int, avg: Double, peak: Int, peakDay: String, goalDaysCount: Int, totalDays: Int) {
        let data = statsService.lastNDaysStats(days: days)
        let total = data.reduce(0) { $0 + $1.count }
        let avg = data.isEmpty ? 0 : Double(total) / Double(data.count)
        let peakItem = data.max(by: { $0.count < $1.count })
        let peak = peakItem?.count ?? 0
        let peakDay = peakItem?.dayOfWeek ?? "—"
        let goal = statsService.dailyGoal
        let goalDaysCount = data.filter { $0.count >= goal }.count
        return (total, avg, peak, peakDay, goalDaysCount, data.count)
    }

    private func monthlyWordsKPIs() -> (total: Int, avg: Double, peak: Int, peakMonth: String) {
        let data = statsService.lastNMonthsStats(months: 12)
        let total = data.reduce(0) { $0 + $1.count }
        let avg = data.isEmpty ? 0 : Double(total) / Double(max(1, data.count))
        let peakItem = data.max(by: { $0.count < $1.count })
        let peak = peakItem?.count ?? 0
        let peakMonth = peakItem?.monthName ?? "—"
        return (total, avg, peak, peakMonth)
    }

    // MARK: - Primary Activity ApexChart (Buttery Smooth 120fps via WebKit)
    private var primaryActivityApexChart: some View {
        let isYear = (timeRange == .year)
        let categories: [String]
        let values: [Double]
        let goal: Double?
        let title = "Từ vựng"
        
        if isYear {
            let data = statsService.lastNMonthsStats(months: 12)
            categories = data.map(\.monthName)
            values = data.map { Double($0.count) }
            goal = nil
        } else {
            let data = statsService.lastNDaysStats(days: timeRange.rawValue)
            categories = data.map { (timeRange == .week ? "\($0.dayOfWeek) \($0.dateString)" : $0.dateString) }
            values = data.map { Double($0.count) }
            goal = Double(statsService.dailyGoal)
        }
        
        return ApexChartView(
            chartStyle: chartStyle == .bar ? .bar : .area,
            categories: categories,
            values: values,
            goalValue: goal,
            yTitle: title,
            isDarkMode: colorScheme == .dark
        )
        .frame(height: 205)
    }

    // MARK: - 4. Responsive Middle Section (Side-by-side)
    private var responsiveMiddleSection: some View {
        HStack(alignment: .top, spacing: 14) {
            dailyGoalsGroupBox
            topicDistributionGroupBox
        }
    }

    // MARK: - Daily Goals Inset GroupBox
    private var dailyGoalsGroupBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Mục tiêu hằng ngày")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Tiến độ hôm nay")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Divider().opacity(0.3)

                // Goal 1: Vocabulary
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Chỉ tiêu từ vựng:")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(verbatim: "\(statsService.dailyGoal) từ/ngày")
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    }

                    Slider(value: Binding(
                        get: { Double(statsService.dailyGoal) },
                        set: { statsService.dailyGoal = Int($0) }
                    ), in: 5...60, step: 5)

                    HStack {
                        Text(
                            verbatim:  "Đã tra: \(statsService.uniqueLookupsToday)/\(statsService.dailyGoal) từ"
                        )
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(
                            verbatim: "\(Int(statsService.todayGoalProgress * 100))%"
                        )
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(statsService.todayGoalProgress >= 1.0 ? .green : .blue)
                    }

                    ProgressView(value: animateChart ? statsService.todayGoalProgress : 0)
                        .tint(statsService.todayGoalProgress >= 1.0 ? Color.green : Color.accentColor)
                        .animation(.easeInOut(duration: 0.8), value: animateChart)
                }

                // Encouragement tip to balance height with donut chart
                HStack(spacing: 8) {
                    Image(systemName: statsService.todayGoalProgress >= 1.0 ? "checkmark.seal.fill" : "sparkles")
                        .foregroundColor(statsService.todayGoalProgress >= 1.0 ? .green : .orange)
                        .font(.system(size: 12))
                    Text(statsService.todayGoalProgress >= 1.0 
                         ? "Xuất sắc! Bạn đã hoàn thành chỉ tiêu ngày." 
                         : "Hãy duy trì tra cứu để đạt chỉ tiêu mỗi ngày nhé!")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(8)
        } label: {
            EmptyView()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Topic Distribution Inset GroupBox (Donut Chart)
    private struct GenreStatItem: Identifiable {
        let id = UUID()
        let genre: ItemThematicGenre
        let count: Int
        let color: Color
    }

    private var topicDistributionGroupBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Phân loại từ vựng")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Text("Theo chủ đề")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Divider().opacity(0.3)

                let palette: [Color] = [.blue, .purple, .teal, .orange, .pink, .indigo, .green, .cyan]
                let allGenres: [GenreStatItem] = ItemThematicGenre.allCases.enumerated().compactMap { index, g in
                    let count = vocabService.savedWords.filter { $0.aiThematicGenre == g }.count
                    guard count > 0 else { return nil }
                    return GenreStatItem(genre: g, count: count, color: palette[index % palette.count])
                }

                if allGenres.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.secondary.opacity(0.35))
                        Text("Chưa có dữ liệu phân loại chủ đề.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 130)
                } else {
                    HStack(spacing: 14) {
                        let paletteHex = ["#007AFF", "#AF52DE", "#30B0C7", "#FF9500", "#FF2D55", "#5856D6", "#34C759", "#32ADE6"]
                        let donutItems = allGenres.enumerated().map { idx, g in
                            ApexChartSeriesItem(name: g.genre.rawValue, value: Double(g.count), colorHex: paletteHex[idx % paletteHex.count])
                        }

                        // ApexCharts Donut Chart with Smooth 120fps Animations & Hover Pop-out
                        ApexChartView(
                            chartStyle: .donut,
                            donutItems: donutItems,
                            isDarkMode: colorScheme == .dark
                        )
                        .frame(width: 155, height: 155)

                        // Legend with Percentages
                        VStack(alignment: .leading, spacing: 4) {
                            let total = max(1, vocabService.savedWords.count)
                            ForEach(allGenres.prefix(5)) { item in
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: 6.5, height: 6.5)

                                    Text(item.genre.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.primary)

                                    Spacer()

                                    let pct = Int((Double(item.count) / Double(total)) * 100)
                                    Text(verbatim:"\(item.count) (\(pct)%)")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2.5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(8)
        } label: {
            EmptyView()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 5. Words Needing Review (Repeated Lookups)
    private var wordsNeedingReviewGroupBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Từ tra lặp lại nhiều lần")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Text("Nên lưu vào Sổ tay để ghi nhớ")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Divider().opacity(0.4)

                let repeated = statsService.repeatedWords(minRepeats: 2, limit: 5)
                if repeated.isEmpty {
                    VStack(spacing: 4) {
                        Text("Chưa có từ nào bị tra cứu lặp lại nhiều lần.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                } else {
                    VStack(spacing: 5) {
                        ForEach(repeated) { item in
                            HStack(spacing: 8) {
                                Text(item.word)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)

                                Spacer()

                                Text(verbatim: "\(item.count) lần")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundColor(.secondary)

                                if item.isSaved || justSavedWords.contains(item.word.lowercased()) {
                                    Text("Đã lưu")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                } else {
                                    Button("Lưu sổ") {
                                        Task {
                                            let translation = await TranslationService.shared.translate(text: item.word, from: "auto", to: "vi") ?? ""
                                            vocabService.addWord(word: item.word, translation: translation)
                                            justSavedWords.insert(item.word.lowercased())
                                        }
                                    }
                                    .controlSize(.small)
                                }
                            }
                            .padding(.vertical, 1.5)
                        }
                    }
                }
            }
            .padding(8)
        } label: {
            EmptyView()
        }
    }
}

#if DEBUG
#Preview("Thống Kê Hoạt Động (Light Mode)") {
    LearningStatsDashboardView()
        .frame(width: 860, height: 680)
        .preferredColorScheme(.light)
}

#Preview("Thống Kê Hoạt Động (Dark Mode)") {
    LearningStatsDashboardView()
        .frame(width: 860, height: 680)
        .preferredColorScheme(.dark)
}
#endif
