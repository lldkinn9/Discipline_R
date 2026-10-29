import Foundation
import HealthKit
import Combine

// MARK: - 日次ヘルスメトリクス構造体（カレンダー・月間ヒートマップ・曜日対比・AI総合分析用）
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
    var distanceKm: Double = 0        // 歩行＋ランニング距離 (km)
    var exerciseMinutes: Double = 0   // エクササイズ時間 (分)
    var sleepHours: Double = 0        // 睡眠時間 (時間)
    var restingHeartRate: Double = 0  // 安静時心拍数 (bpm)
    
    var totalBurned: Double { activeBurned + basalBurned }
    var netBalance: Double { intakeCalories - totalBurned }
}

// MARK: - ワークアウト（運動）履歴構造体（AI総合分析・プレビュー用）
struct WorkoutRecord: Identifiable {
    let id = UUID()
    let dateString: String      // "yyyy-MM-dd"
    let startTimeString: String // "HH:mm"
    let activityName: String    // 種目名（日本語）
    let durationMinutes: Int    // 運動時間（分）
    let energyBurnedKcal: Int   // アクティブ消費カロリー（kcal）
}

final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized: Bool = false
    @Published var isLoading: Bool = true
    @Published var lastSyncedAt: Date? = nil
    
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // 今日のリアルタイム集計値（Apple HealthKit 一本化）
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Double = 0.0
    @Published var todayBasalCalories: Double = 0.0
    @Published var todayIntakeCalories: Double = 0.0
    @Published var todayProtein: Double = 0.0
    @Published var todayFat: Double = 0.0
    @Published var todayCarbs: Double = 0.0
    @Published var todayDistanceKm: Double = 0.0
    @Published var todayExerciseMinutes: Double = 0.0
    @Published var lastNightSleepHours: Double = 0.0
    @Published var latestWeight: Double = 0.0
    @Published var latestBodyFat: Double = 0.0
    @Published var latestRestingHeartRate: Double = 0.0
    
    // 過去60日分の日別サマリー辞書 ("yyyy-MM-dd" -> DailyHealthSummary)
    @Published var dailySummaries: [String: DailyHealthSummary] = [:]
    
    // 直近30日間のワークアウト履歴（新しい順）
    @Published var recentWorkouts: [WorkoutRecord] = []
    
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
               lastNightSleepHours > 0 ||
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
            let historicalToday = dailySummaries[key]
            return DailyHealthSummary(
                dateString: key,
                steps: todaySteps,
                activeBurned: todayActiveCalories,
                basalBurned: todayBasalCalories,
                intakeCalories: todayIntakeCalories,
                protein: todayProtein,
                fat: todayFat,
                carbs: todayCarbs,
                weight: latestWeight > 0 ? latestWeight : (historicalToday?.weight ?? 0),
                bodyFatPercentage: latestBodyFat > 0 ? latestBodyFat : (historicalToday?.bodyFatPercentage ?? 0),
                distanceKm: todayDistanceKm,
                exerciseMinutes: todayExerciseMinutes,
                sleepHours: lastNightSleepHours > 0 ? lastNightSleepHours : (historicalToday?.sleepHours ?? 0),
                restingHeartRate: latestRestingHeartRate > 0 ? latestRestingHeartRate : (historicalToday?.restingHeartRate ?? 0)
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
        
        var readTypes: Set<HKObjectType> = [
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
        
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleepType)
        }
        if let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            readTypes.insert(distanceType)
        }
        if let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            readTypes.insert(exerciseType)
        }
        if let restingHRType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            readTypes.insert(restingHRType)
        }
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, _ in
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
            self?.lastSyncedAt = Date()
            self?.isLoading = false
        }
        fetchTodaySum(for: .distanceWalkingRunning, unit: .meterUnit(with: .kilo)) { [weak self] val in
            self?.todayDistanceKm = val
        }
        fetchTodaySum(for: .appleExerciseTime, unit: .minute()) { [weak self] val in
            self?.todayExerciseMinutes = val
        }
        fetchLatestSample(for: .bodyMass, unit: .gramUnit(with: .kilo)) { [weak self] val in
            if val > 0 { self?.latestWeight = val }
        }
        fetchLatestSample(for: .bodyFatPercentage, unit: .percent()) { [weak self] val in
            if val > 0 { self?.latestBodyFat = val * 100.0 }
        }
        fetchLatestSample(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute())) { [weak self] val in
            if val > 0 { self?.latestRestingHeartRate = val }
        }
    }
    
    // 設定画面「最新データ更新」ボタン等からの手動フル同期
    func refreshAllData(completion: (() -> Void)? = nil) {
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async {
                self.isLoading = false
                completion?()
            }
            return
        }
        requestAuthorization()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.lastSyncedAt = Date()
            completion?()
        }
    }
    
    private func syncWidget() {
        WidgetDataSharer.shared.pushCurrentStateToWidget(
            healthKit: self,
            habitManager: HabitManager.shared
        )
    }
    
    // MARK: - 過去N日間の日別集計（カレンダー・AI総合アドバイザー用）
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
            self.syncWidget()
        }
        fetchDailyCollection(for: .basalEnergyBurned, unit: .kilocalorie(), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.basalBurned = v
                self.dailySummaries[k] = item
            }
            self.syncWidget()
        }
        fetchDailyCollection(for: .dietaryEnergyConsumed, unit: .kilocalorie(), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.intakeCalories = v
                self.dailySummaries[k] = item
            }
            self.syncWidget()
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
        fetchDailyCollection(for: .distanceWalkingRunning, unit: .meterUnit(with: .kilo), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.distanceKm = v
                self.dailySummaries[k] = item
            }
        }
        fetchDailyCollection(for: .appleExerciseTime, unit: .minute(), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.exerciseMinutes = v
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
        fetchDailyDiscreteAverage(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: startDate, end: endOfToday) { [weak self] dict in
            guard let self = self else { return }
            for (k, v) in dict {
                var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                item.restingHeartRate = v
                self.dailySummaries[k] = item
            }
        }
        
        // 睡眠履歴およびワークアウト履歴の取得
        fetchSleepHistory(days: days)
        fetchRecentWorkouts(days: 30)
    }
    
    // MARK: - 睡眠データの重複排除集計（起床日ベースで1日ごとの睡眠時間を算出）
    private func fetchSleepHistory(days: Int) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let self = self, let categorySamples = samples as? [HKCategorySample] else { return }
            
            let asleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]
            let inBedValue = HKCategoryValueSleepAnalysis.inBed.rawValue
            
            var asleepIntervalsByDay: [String: [(Date, Date)]] = [:]
            var inBedIntervalsByDay: [String: [(Date, Date)]] = [:]
            
            for sample in categorySamples {
                guard sample.endDate > sample.startDate else { continue }
                // 起床時刻（endDate）が属する日付をその日の睡眠として紐付け
                let dayKey = self.dateKey(for: sample.endDate)
                if asleepValues.contains(sample.value) {
                    asleepIntervalsByDay[dayKey, default: []].append((sample.startDate, sample.endDate))
                } else if sample.value == inBedValue {
                    inBedIntervalsByDay[dayKey, default: []].append((sample.startDate, sample.endDate))
                }
            }
            
            var allKeys = Set(asleepIntervalsByDay.keys).union(inBedIntervalsByDay.keys)
            var sleepHoursByDay: [String: Double] = [:]
            
            for key in allKeys {
                // 実睡眠ステージ（asleep*）があればそれを優先し、ない場合のみ inBed を使用（Apple Watch と iPhone の二重計上防止）
                let intervals = asleepIntervalsByDay[key]?.isEmpty == false
                    ? asleepIntervalsByDay[key]!
                    : (inBedIntervalsByDay[key] ?? [])
                let mergedSeconds = Self.mergedDurationSeconds(intervals: intervals)
                if mergedSeconds > 0 {
                    sleepHoursByDay[key] = mergedSeconds / 3600.0
                }
            }
            
            DispatchQueue.main.async {
                let todayKey = self.dateKey(for: Date())
                for (k, hours) in sleepHoursByDay {
                    var item = self.dailySummaries[k] ?? DailyHealthSummary(dateString: k)
                    item.sleepHours = hours
                    self.dailySummaries[k] = item
                }
                if let todaySleep = sleepHoursByDay[todayKey], todaySleep > 0 {
                    self.lastNightSleepHours = todaySleep
                } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
                          let yesterdaySleep = sleepHoursByDay[self.dateKey(for: yesterday)],
                          Calendar.current.component(.hour, from: Date()) < 10 {
                    // 早朝でまだ今日の睡眠サンプルが確定していない場合のフォールバック
                    self.lastNightSleepHours = yesterdaySleep
                }
            }
        }
        healthStore.execute(query)
    }
    
    // 重複する時間区間をマージして合計秒数を返すヘルパー
    private static func mergedDurationSeconds(intervals: [(Date, Date)]) -> TimeInterval {
        guard !intervals.isEmpty else { return 0 }
        let sorted = intervals.sorted { $0.0 < $1.0 }
        var merged: [(Date, Date)] = [sorted[0]]
        
        for current in sorted.dropFirst() {
            let last = merged[merged.count - 1]
            if current.0 <= last.1 {
                merged[merged.count - 1] = (last.0, max(last.1, current.1))
            } else {
                merged.append(current)
            }
        }
        return merged.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
    }
    
    // MARK: - 直近N日間のワークアウト（運動）履歴取得
    private func fetchRecentWorkouts(days: Int = 30) {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 30, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let self = self, let workouts = samples as? [HKWorkout] else { return }
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
            
            let records: [WorkoutRecord] = workouts.map { workout in
                let kcal: Double
                if let energyType = energyType,
                   let sum = workout.statistics(for: energyType)?.sumQuantity() {
                    kcal = sum.doubleValue(for: .kilocalorie())
                } else {
                    kcal = 0
                }
                let mins = max(1, Int((workout.duration / 60.0).rounded()))
                return WorkoutRecord(
                    dateString: self.dateKey(for: workout.startDate),
                    startTimeString: timeFormatter.string(from: workout.startDate),
                    activityName: Self.japaneseWorkoutName(for: workout.workoutActivityType),
                    durationMinutes: mins,
                    energyBurnedKcal: Int(kcal.rounded())
                )
            }
            
            DispatchQueue.main.async {
                self.recentWorkouts = records
            }
        }
        healthStore.execute(query)
    }
    
    private static func japaneseWorkoutName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "ランニング"
        case .walking: return "ウォーキング"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "筋力トレーニング"
        case .coreTraining: return "コアトレーニング"
        case .highIntensityIntervalTraining: return "HIIT"
        case .cycling: return "サイクリング"
        case .yoga: return "ヨガ"
        case .pilates: return "ピラティス"
        case .flexibility, .cooldown, .preparationAndRecovery, .mindAndBody: return "ストレッチ・リカバリー"
        case .swimming: return "水泳"
        case .soccer: return "サッカー"
        case .tennis: return "テニス"
        case .basketball: return "バスケットボール"
        case .boxing, .kickboxing, .martialArts: return "ボクシング・格闘技"
        case .jumpRope: return "縄跳び"
        case .hiking: return "ハイキング"
        case .rowing: return "ローイング"
        case .elliptical: return "エリプティカル"
        case .stairClimbing: return "ステアクライミング"
        case .dance, .cardioDance: return "ダンス"
        default: return "ワークアウト"
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
