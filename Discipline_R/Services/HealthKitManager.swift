import Foundation
import HealthKit
import Combine

// MARK: - 日次ヘルスメトリクス構造体（カレンダー・月間ヒートマップ・曜日対比用）
struct DailyHealthSummary {
    let dateString: String // "yyyy-MM-dd"
    var steps: Int = 0
    var activeBurned: Double = 0
    var basalBurned: Double = 0
    var intakeCalories: Double = 0
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    var weight: Double = 0
    var bodyFatPercentage: Double = 0 // % (例: 15.2)
    
    var totalBurned: Double { activeBurned + basalBurned }
    var netBalance: Double { intakeCalories - totalBurned }
}

final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized: Bool = false
    @Published var isLoading: Bool = true
    
    // 今日のリアルタイム集計値（Apple HealthKit 一本化）
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Double = 0.0
    @Published var todayBasalCalories: Double = 0.0
    @Published var todayIntakeCalories: Double = 0.0
    @Published var todayProtein: Double = 0.0
    @Published var todayFat: Double = 0.0
    @Published var todayCarbs: Double = 0.0
    @Published var latestWeight: Double = 0.0
    @Published var latestBodyFat: Double = 0.0
    
    // 過去60日分の日別サマリー辞書 ("yyyy-MM-dd" -> DailyHealthSummary)
    @Published var dailySummaries: [String: DailyHealthSummary] = [:]
    
    var todayTotalBurnedCalories: Double {
        return todayActiveCalories + todayBasalCalories
    }
    
    // 今日何かしらのヘルスケアデータが存在するかどうか（Empty State 判定用）
    var hasAnyHealthDataToday: Bool {
        return todaySteps > 0 ||
               todayActiveCalories > 0 ||
               todayBasalCalories > 0 ||
               todayIntakeCalories > 0 ||
               todayProtein > 0 ||
               todayFat > 0 ||
               todayCarbs > 0 ||
               latestWeight > 0
    }
    
    private init() {}
    
    func dateKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    
    func summary(for date: Date) -> DailyHealthSummary {
        let key = dateKey(for: date)
        if Calendar.current.isDateInToday(date) {
            return DailyHealthSummary(
                dateString: key,
                steps: todaySteps,
                activeBurned: todayActiveCalories,
                basalBurned: todayBasalCalories,
                intakeCalories: todayIntakeCalories,
                protein: todayProtein,
                fat: todayFat,
                carbs: todayCarbs,
                weight: latestWeight,
                bodyFatPercentage: latestBodyFat
            )
        }
        return dailySummaries[key] ?? DailyHealthSummary(dateString: key)
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.fetchAllTodayData()
                    self?.fetchHistoricalDailySummaries(days: 60)
                } else {
                    self?.isLoading = false
                }
            }
        }
    }
    
    func fetchAllTodayData() {
        DispatchQueue.main.async { self.isLoading = true }
        
        fetchTodaySum(for: .stepCount, unit: .count()) { [weak self] val in
            self?.todaySteps = Int(val)
            self?.syncWidget()
        }
        fetchTodaySum(for: .activeEnergyBurned, unit: .kilocalorie()) { [weak self] val in
            self?.todayActiveCalories = val
            self?.syncWidget()
        }
        fetchTodaySum(for: .basalEnergyBurned, unit: .kilocalorie()) { [weak self] val in
            self?.todayBasalCalories = val
            self?.syncWidget()
        }
        fetchTodaySum(for: .dietaryEnergyConsumed, unit: .kilocalorie()) { [weak self] val in
            self?.todayIntakeCalories = val
            self?.syncWidget()
        }
        fetchTodaySum(for: .dietaryProtein, unit: .gram()) { [weak self] val in
            self?.todayProtein = val
        }
        fetchTodaySum(for: .dietaryFatTotal, unit: .gram()) { [weak self] val in
            self?.todayFat = val
        }
        fetchTodaySum(for: .dietaryCarbohydrates, unit: .gram()) { [weak self] val in
            self?.todayCarbs = val
            self?.isLoading = false
        }
        fetchLatestSample(for: .bodyMass, unit: .gramUnit(with: .kilo)) { [weak self] val in
            if val > 0 { self?.latestWeight = val }
        }
        fetchLatestSample(for: .bodyFatPercentage, unit: .percent()) { [weak self] val in
            if val > 0 { self?.latestBodyFat = val * 100.0 }
        }
    }
    
    private func syncWidget() {
        WidgetDataSharer.shared.pushCurrentStateToWidget(
            healthKit: self,
            habitManager: HabitManager.shared
        )
    }
    
    // MARK: - 過去N日間の日別集計（カレンダー6大スタンプ・曜日別対比用）
    func fetchHistoricalDailySummaries(days: Int = 60) {
        let calendar = Calendar.current
        let now = Date()
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) else { return }
        
        fetchDailyCollection(for: .stepCount, unit: .count(), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.steps = Int(v)
                self.dailySummaries[k] = item
            }
        }
        fetchDailyCollection(for: .activeEnergyBurned, unit: .kilocalorie(), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.activeBurned = v
                self.dailySummaries[k] = item
            }
        }
        fetchDailyCollection(for: .basalEnergyBurned, unit: .kilocalorie(), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.basalBurned = v
                self.dailySummaries[k] = item
            }
        }
        fetchDailyCollection(for: .dietaryEnergyConsumed, unit: .kilocalorie(), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.intakeCalories = v
                self.dailySummaries[k] = item
            }
        }
        fetchDailyCollection(for: .dietaryProtein, unit: .gram(), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.protein = v
                self.dailySummaries[k] = item
            }
        }
        fetchDailyCollection(for: .dietaryFatTotal, unit: .gram(), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.fat = v
                self.dailySummaries[k] = item
            }
        }
        fetchDailyCollection(for: .dietaryCarbohydrates, unit: .gram(), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.carbs = v
                self.dailySummaries[k] = item
            }
        }
        fetchDailyDiscreteAverage(for: .bodyMass, unit: .gramUnit(with: .kilo), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.weight = v
                self.dailySummaries[k] = item
            }
        }
        fetchDailyDiscreteAverage(for: .bodyFatPercentage, unit: .percent(), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.bodyFatPercentage = v * 100.0
                self.dailySummaries[k] = item
            }
        }
    }
    
    private func fetchDailyCollection(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date, completion: @escaping ([String: Double]) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 1
        let anchorDate = calendar.startOfDay(for: start)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: anchorDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let statsCollection = results else { return }
            var output: [String: Double] = [:]
            statsCollection.enumerateStatistics(from: start, to: end) { stats, _ in
                let val = stats.sumQuantity()?.doubleValue(for: unit) ?? 0.0
                if val > 0 {
                    output[self.dateKey(for: stats.startDate)] = val
                }
            }
            DispatchQueue.main.async {
                completion(output)
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchDailyDiscreteAverage(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date, completion: @escaping ([String: Double]) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 1
        let anchorDate = calendar.startOfDay(for: start)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: nil,
            options: .discreteAverage,
            anchorDate: anchorDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { [weak self] _, results, _ in
            guard let self = self, let statsCollection = results else { return }
            var output: [String: Double] = [:]
            statsCollection.enumerateStatistics(from: start, to: end) { stats, _ in
                let val = stats.averageQuantity()?.doubleValue(for: unit) ?? 0.0
                if val > 0 {
                    output[self.dateKey(for: stats.startDate)] = val
                }
            }
            DispatchQueue.main.async {
                completion(output)
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchTodaySum(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(0.0)
            return
        }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let sum = result?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
            DispatchQueue.main.async {
                completion(sum)
            }
        }
        healthStore.execute(query)
    }
    
    private func fetchLatestSample(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double) -> Void) {
        guard let sampleType = HKSampleType.quantityType(forIdentifier: identifier) else {
            completion(0.0)
            return
        }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let val = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0.0
            DispatchQueue.main.async {
                completion(val)
            }
        }
        healthStore.execute(query)
    }
}

