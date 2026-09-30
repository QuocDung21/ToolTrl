import Foundation
import SwiftUI

public struct DayStat: Identifiable, Sendable {
    public var id: String { dateString }
    public let date: Date
    public let dateString: String
    public let dayOfWeek: String
    public let count: Int // Unique words looked up on this day
    public let totalHits: Int // Total lookups including repeats
    
    public init(date: Date, dateString: String, dayOfWeek: String, count: Int, totalHits: Int = 0) {
        self.date = date
        self.dateString = dateString
        self.dayOfWeek = dayOfWeek
        self.count = count
        self.totalHits = totalHits
    }
}

public struct MonthStat: Identifiable, Sendable {
    public var id: String { monthString }
    public let monthDate: Date
    public let monthString: String
    public let monthName: String
    public let count: Int // Unique words in this month
    public let totalHits: Int
    
    public init(monthDate: Date, monthString: String, monthName: String, count: Int, totalHits: Int = 0) {
        self.monthDate = monthDate
        self.monthString = monthString
        self.monthName = monthName
        self.count = count
        self.totalHits = totalHits
    }
}

public struct RepeatedWordItem: Identifiable, Sendable {
    public var id: String { word }
    public let word: String
    public let count: Int
    public let lastLookedUp: Date
    public let isSaved: Bool
    
    public init(word: String, count: Int, lastLookedUp: Date, isSaved: Bool) {
        self.word = word
        self.count = count
        self.lastLookedUp = lastLookedUp
        self.isSaved = isSaved
    }
}

public struct LookupRecord: Identifiable, Codable, Sendable {
    public var id: UUID = UUID()
    public let term: String
    public let timestamp: Date
    
    public init(id: UUID = UUID(), term: String, timestamp: Date = Date()) {
        self.id = id
        self.term = term
        self.timestamp = timestamp
    }
}

@MainActor
public final class LookupStatsService: ObservableObject {
    public static let shared = LookupStatsService()
    
    // Frozen on purpose: these keys hold the user's live lookup history and daily
    // goal. Renaming them without a migration would silently reset their statistics.
    private let storageKey = "tooltrl_lookup_records_v2"
    private let goalKey = "tooltrl_daily_lookup_goal"
    
    @Published public private(set) var records: [LookupRecord] = []
    @Published public var dailyGoal: Int {
        didSet {
            UserDefaults.standard.set(dailyGoal, forKey: goalKey)
        }
    }
    
    private let calendar = Calendar.current
    private let saveQueue = DispatchQueue(label: "com.nekotrans.mac.lookupstats.io", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?
    
    private var statsFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = appSupport.appendingPathComponent("ToolTrL", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("lookup_stats_v2.json")
    }
    
    private init() {
        let savedGoal = UserDefaults.standard.integer(forKey: goalKey)
        self.dailyGoal = savedGoal > 0 ? savedGoal : 20
        loadRecords()
    }
    
    // MARK: - Smart Deduplication Record Tracking
    public func recordLookup(term: String) {
        let clean = term.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !clean.isEmpty && clean.count >= 2 else { return }
        
        let normalized = clean.lowercased()
        let now = Date()
        
        // Intelligent Deduplication:
        // If the exact same word was looked up within the last 15 minutes, update timestamp rather than duplicate
        if let recentIndex = records.firstIndex(where: {
            $0.term.lowercased() == normalized && now.timeIntervalSince($0.timestamp) < 900 // 15 mins
        }) {
            // Refresh timestamp of the existing lookup
            records[recentIndex] = LookupRecord(id: records[recentIndex].id, term: clean, timestamp: now)
            scheduleSave()
            return
        }
        
        let record = LookupRecord(term: clean, timestamp: now)
        records.insert(record, at: 0)
        
        // Keep max 5,000 records
        if records.count > 5000 {
            records = Array(records.prefix(4000))
        }
        
        scheduleSave()
    }
    
    // MARK: - Computed Analytics (Unique Words Based)
    
    /// Total UNIQUE words looked up today
    public var uniqueLookupsToday: Int {
        let startOfDay = calendar.startOfDay(for: Date())
        let todayRecords = records.filter { $0.timestamp >= startOfDay }
        let uniqueSet = Set(todayRecords.map { $0.term.lowercased() })
        return uniqueSet.count
    }
    
    /// Alias for backwards compatibility
    public var lookupsToday: Int {
        return uniqueLookupsToday
    }
    
    /// Total raw lookup count today (hits)
    public var totalHitsToday: Int {
        let startOfDay = calendar.startOfDay(for: Date())
        return records.filter { $0.timestamp >= startOfDay }.count
    }
    
    /// Total unique words across all time
    public var totalUniqueWords: Int {
        return Set(records.map { $0.term.lowercased() }).count
    }
    
    /// Total historical lookup entries
    public var totalRecordsCount: Int {
        return records.count
    }
    
    /// Today's goal progress percentage (based on unique words)
    public var todayGoalProgress: Double {
        guard dailyGoal > 0 else { return 1.0 }
        return min(Double(uniqueLookupsToday) / Double(dailyGoal), 1.0)
    }
    
    /// Current learning streak in days
    public var currentStreak: Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        
        let hasToday = records.contains { calendar.isDate($0.timestamp, inSameDayAs: checkDate) }
        if hasToday {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        } else {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            let hasYesterday = records.contains { calendar.isDate($0.timestamp, inSameDayAs: yesterday) }
            if !hasYesterday {
                return 0
            }
            checkDate = yesterday
        }
        
        while true {
            let hasRecord = records.contains { calendar.isDate($0.timestamp, inSameDayAs: checkDate) }
            if hasRecord {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }
    
    /// Last N days stats (counts unique words per day to prevent artificial inflation)
    public func lastNDaysStats(days: Int = 7) -> [DayStat] {
        var result: [DayStat] = []
        let today = calendar.startOfDay(for: Date())
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM"
        
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "vi_VN")
        dayFormatter.dateFormat = "EE"
        
        for i in (0..<days).reversed() {
            guard let targetDate = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let dayRecords = records.filter { calendar.isDate($0.timestamp, inSameDayAs: targetDate) }
            let uniqueCount = Set(dayRecords.map { $0.term.lowercased() }).count
            let totalHits = dayRecords.count
            
            let dateStr = dateFormatter.string(from: targetDate)
            let dayStr = i == 0 ? "H.nay" : dayFormatter.string(from: targetDate).capitalized
            result.append(DayStat(date: targetDate, dateString: dateStr, dayOfWeek: dayStr, count: uniqueCount, totalHits: totalHits))
        }
        return result
    }
    
    /// Last N months stats (unique words per month)
    public func lastNMonthsStats(months: Int = 6) -> [MonthStat] {
        var result: [MonthStat] = []
        let today = Date()
        
        let monthKeyFormatter = DateFormatter()
        monthKeyFormatter.dateFormat = "yyyy-MM"
        
        for i in (0..<months).reversed() {
            guard let targetMonth = calendar.date(byAdding: .month, value: -i, to: today) else { continue }
            let targetComponents = calendar.dateComponents([.year, .month], from: targetMonth)
            
            let monthRecords = records.filter {
                let recComp = calendar.dateComponents([.year, .month], from: $0.timestamp)
                return recComp.year == targetComponents.year && recComp.month == targetComponents.month
            }
            
            let uniqueCount = Set(monthRecords.map { $0.term.lowercased() }).count
            let key = monthKeyFormatter.string(from: targetMonth)
            let name = "Th.\(targetComponents.month ?? 1)"
            result.append(MonthStat(monthDate: targetMonth, monthString: key, monthName: name, count: uniqueCount, totalHits: monthRecords.count))
        }
        return result
    }
    
    /// Words looked up repeatedly (frequently re-checked words indicating review needed)
    public func repeatedWords(minRepeats: Int = 2, limit: Int = 10) -> [RepeatedWordItem] {
        var counts: [String: (display: String, count: Int, lastDate: Date)] = [:]
        
        for r in records {
            let key = r.term.lowercased()
            if let existing = counts[key] {
                let newestDate = max(existing.lastDate, r.timestamp)
                counts[key] = (existing.display, existing.count + 1, newestDate)
            } else {
                counts[key] = (r.term.capitalized, 1, r.timestamp)
            }
        }
        
        let filtered = counts.values.filter { $0.count >= minRepeats }
        let sorted = filtered.sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.lastDate > $1.lastDate
        }
        
        let savedWords = VocabularyService.shared.savedWords
        return Array(sorted.prefix(limit)).map { item in
            let isSaved = savedWords.contains { $0.word.lowercased() == item.display.lowercased() }
            return RepeatedWordItem(word: item.display, count: item.count, lastLookedUp: item.lastDate, isSaved: isSaved)
        }
    }
    
    // MARK: - Persistence
    private func loadRecords() {
        if let url = statsFileURL,
           FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([LookupRecord].self, from: data) {
            self.records = decoded
            return
        }
        
        // Check legacy file or UserDefaults
        if let legacyData = UserDefaults.standard.data(forKey: "tooltrl_lookup_records_v1"),
           let decoded = try? JSONDecoder().decode([LookupRecord].self, from: legacyData) {
            self.records = decoded
            scheduleSave()
        }
    }
    
    private func scheduleSave() {
        let snapshot = self.records
        saveWorkItem?.cancel()
        
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if let encoded = try? JSONEncoder().encode(snapshot) {
                if let url = self.statsFileURL {
                    try? encoded.write(to: url, options: .atomic)
                }
                UserDefaults.standard.set(encoded, forKey: self.storageKey)
            }
        }
        saveWorkItem = item
        saveQueue.asyncAfter(deadline: .now() + 1.0, execute: item)
    }
    
    /// Xóa toàn bộ lịch sử tra cứu trên máy (dùng khi đăng xuất tài khoản)
    public func clearAllRecords() {
        saveWorkItem?.cancel()
        self.records = []
        if let url = statsFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: "tooltrl_lookup_records_v1")
    }
}
