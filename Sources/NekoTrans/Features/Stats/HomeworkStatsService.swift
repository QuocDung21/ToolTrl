import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

public struct HomeworkRecord: Identifiable, Codable, Sendable {
    public var id: UUID
    public let timestamp: Date
    public let notes: String
    public let hasImage: Bool
    public var imageFileName: String?
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), notes: String = "", hasImage: Bool = false, imageFileName: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.notes = notes
        self.hasImage = hasImage
        self.imageFileName = imageFileName
    }
}

@MainActor
public final class HomeworkStatsService: ObservableObject {
    public static let shared = HomeworkStatsService()
    
    // Keys and the App Support folder are frozen on purpose: they hold the user's
    // live homework records. Renaming them without a migration would silently reset
    // their statistics, so the ToolTrL prefix stays part of the persisted contract.
    private let storageKey = "tooltrl_homework_records_v1"
    private let goalKey = "tooltrl_daily_homework_goal"
    
    @Published public private(set) var records: [HomeworkRecord] = []
    @Published public var dailyGoal: Int {
        didSet {
            UserDefaults.standard.set(dailyGoal, forKey: goalKey)
        }
    }
    
    private let calendar = Calendar.current
    private let saveQueue = DispatchQueue(label: "com.nekotrans.mac.homeworkstats.io", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?
    
    private var statsFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = appSupport.appendingPathComponent("ToolTrL", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("homework_stats.json")
    }
    
    private var homeworkImagesDir: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = appSupport.appendingPathComponent("ToolTrL/HomeworkImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    
    private init() {
        let savedGoal = UserDefaults.standard.integer(forKey: goalKey)
        self.dailyGoal = savedGoal > 0 ? savedGoal : 5
        loadRecords()
    }
    
    // MARK: - Record Submission
    #if canImport(AppKit)
    public func recordSubmission(notes: String, image: NSImage?) {
        let now = Date()
        var savedFileName: String? = nil
        
        if let image = image,
           let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]),
           let imgDir = homeworkImagesDir {
            let fileName = "hw_\(Int(now.timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).png"
            let fileURL = imgDir.appendingPathComponent(fileName)
            try? pngData.write(to: fileURL)
            savedFileName = fileName
        }
        
        let record = HomeworkRecord(
            id: UUID(),
            timestamp: now,
            notes: notes,
            hasImage: image != nil,
            imageFileName: savedFileName
        )
        
        records.insert(record, at: 0)
        
        // Keep max 1,000 records
        if records.count > 1000 {
            records = Array(records.prefix(800))
        }
        
        scheduleSave()
    }
    #endif
    
    // MARK: - Computed Analytics
    
    /// Total homework exercises completed today
    public var completedToday: Int {
        let startOfDay = calendar.startOfDay(for: Date())
        return records.filter { $0.timestamp >= startOfDay }.count
    }
    
    /// Total homework exercises completed all time
    public var totalCompleted: Int {
        return records.count
    }
    
    /// Daily goal progress percentage
    public var todayGoalProgress: Double {
        guard dailyGoal > 0 else { return 1.0 }
        return min(Double(completedToday) / Double(dailyGoal), 1.0)
    }
    
    /// Current streak in days of doing homework
    public var homeworkStreak: Int {
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
    
    /// Last N days homework stats
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
            let count = dayRecords.count
            
            let dateStr = dateFormatter.string(from: targetDate)
            let dayStr = i == 0 ? "H.nay" : dayFormatter.string(from: targetDate).capitalized
            result.append(DayStat(date: targetDate, dateString: dateStr, dayOfWeek: dayStr, count: count, totalHits: count))
        }
        return result
    }
    
    /// Last N months homework stats
    public func lastNMonthsStats(months: Int = 12) -> [MonthStat] {
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
            
            let count = monthRecords.count
            let key = monthKeyFormatter.string(from: targetMonth)
            let name = "Th.\(targetComponents.month ?? 1)"
            result.append(MonthStat(monthDate: targetMonth, monthString: key, monthName: name, count: count, totalHits: count))
        }
        return result
    }
    
    #if canImport(AppKit)
    public func getSavedImage(for record: HomeworkRecord) -> NSImage? {
        guard let fileName = record.imageFileName,
              let imgDir = homeworkImagesDir else { return nil }
        let fileURL = imgDir.appendingPathComponent(fileName)
        return NSImage(contentsOf: fileURL)
    }
    #endif
    
    // MARK: - Persistence
    private func loadRecords() {
        if let url = statsFileURL,
           FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([HomeworkRecord].self, from: data) {
            self.records = decoded
            return
        }
        
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([HomeworkRecord].self, from: data) {
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
}
