import Foundation
import SwiftUI

enum FrogEvolutionStage: String, CaseIterable {
    case tadpole = "Tadpole 🫧"
    case froglet = "Curious Froglet 🌿"
    case ninjaFrog = "Focus Ninja 🥷"
    case zenMaster = "Zen Master 🧘‍♂️"
    
    var icon: String {
        switch self {
        case .tadpole: return "circle.dotted"
        case .froglet: return "leaf.fill"
        case .ninjaFrog: return "bolt.fill"
        case .zenMaster: return "crown.fill"
        }
    }
    
    var title: String { rawValue }
    
    var minimumSessions: Int {
        switch self {
        case .tadpole: return 0
        case .froglet: return 4
        case .ninjaFrog: return 12
        case .zenMaster: return 30
        }
    }
}

@MainActor
final class FocusGamificationManager: ObservableObject {
    static let shared = FocusGamificationManager()
    
    @Published var streakDays: Int = 1
    @Published var totalMinutesToday: Int = 0
    @Published var dailyGoalMinutes: Int = 120
    @Published var goldenFlies: Int = 5
    @Published var totalCompletedSessions: Int = 0
    
    private let streakKey = "frogdrop.streakDays"
    private let lastDateKey = "frogdrop.lastFocusDate"
    private let minutesTodayKey = "frogdrop.minutesToday"
    private let fliesKey = "frogdrop.goldenFlies"
    private let sessionsKey = "frogdrop.totalSessions"
    
    var currentStage: FrogEvolutionStage {
        if totalCompletedSessions >= FrogEvolutionStage.zenMaster.minimumSessions {
            return .zenMaster
        } else if totalCompletedSessions >= FrogEvolutionStage.ninjaFrog.minimumSessions {
            return .ninjaFrog
        } else if totalCompletedSessions >= FrogEvolutionStage.froglet.minimumSessions {
            return .froglet
        } else {
            return .tadpole
        }
    }
    
    var dailyProgress: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return min(1.0, Double(totalMinutesToday) / Double(dailyGoalMinutes))
    }
    
    private init() {
        loadData()
        checkNewDayReset()
    }
    
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func loadData() {
        let defaults = UserDefaults.standard
        streakDays = max(1, defaults.integer(forKey: streakKey))
        totalMinutesToday = defaults.integer(forKey: minutesTodayKey)
        goldenFlies = defaults.integer(forKey: fliesKey)
        totalCompletedSessions = defaults.integer(forKey: sessionsKey)
    }
    
    private func checkNewDayReset() {
        let defaults = UserDefaults.standard
        let lastDate = defaults.string(forKey: lastDateKey) ?? ""
        let today = todayString()
        
        if lastDate != today {
            // Check if streak was broken (missed more than 1 day)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let lastDateObj = formatter.date(from: lastDate) {
                let diffDays = Calendar.current.dateComponents([.day], from: lastDateObj, to: Date()).day ?? 0
                if diffDays > 1 {
                    streakDays = 1
                }
            }
            totalMinutesToday = 0
            defaults.set(0, forKey: minutesTodayKey)
            defaults.set(streakDays, forKey: streakKey)
            defaults.set(today, forKey: lastDateKey)
        }
    }
    
    func recordCompletedSession(minutes: Int) {
        checkNewDayReset()
        
        let defaults = UserDefaults.standard
        let lastDate = defaults.string(forKey: lastDateKey) ?? ""
        let today = todayString()
        
        if lastDate != today {
            streakDays += 1
            defaults.set(streakDays, forKey: streakKey)
            defaults.set(today, forKey: lastDateKey)
        }
        
        totalMinutesToday += minutes
        defaults.set(totalMinutesToday, forKey: minutesTodayKey)
        
        // Award 1 Golden Fly per 15 minutes of focus
        let fliesEarned = max(1, minutes / 15)
        goldenFlies += fliesEarned
        defaults.set(goldenFlies, forKey: fliesKey)
        
        totalCompletedSessions += 1
        defaults.set(totalCompletedSessions, forKey: sessionsKey)
        
        HapticManager.shared.success()
    }
}
