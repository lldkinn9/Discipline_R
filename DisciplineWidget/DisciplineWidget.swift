import WidgetKit
import SwiftUI

// MARK: - App Group 共有データ構造体
struct DisciplineWidgetData {
    let streakDays: Int
    let calorieBalance: Int
    let intakeCalories: Int
    let burnedCalories: Int
    let habitProgressPercent: Int
    
    static let appGroupIDs = [
        "group.com.lldkinn9.DisciplineApp",
        "group.com.lldkinn9.Discipline-R"
    ]
    
    static func loadFromSharedDefaults() -> DisciplineWidgetData {
        for groupID in appGroupIDs {
            if let defaults = UserDefaults(suiteName: groupID),
               defaults.object(forKey: "widget_intake_calories") != nil || defaults.object(forKey: "widget_habit_progress") != nil {
                let streak = defaults.integer(forKey: "widget_streak_days")
                let balance = defaults.integer(forKey: "widget_calorie_balance")
                let intake = defaults.integer(forKey: "widget_intake_calories")
                let burned = defaults.integer(forKey: "widget_burned_calories")
                let habitPct = defaults.integer(forKey: "widget_habit_progress")
                
                return DisciplineWidgetData(
                    streakDays: streak,
                    calorieBalance: balance,
                    intakeCalories: intake,
                    burnedCalories: burned,
                    habitProgressPercent: habitPct
                )
            }
        }
        return DisciplineWidgetData(
            streakDays: 0,
            calorieBalance: 0,
            intakeCalories: 0,
            burnedCalories: 0,
            habitProgressPercent: 0
        )
    }
}

struct DisciplineEntry: TimelineEntry {
    let date: Date
    let data: DisciplineWidgetData
}

struct DisciplineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DisciplineEntry {
        DisciplineEntry(
            date: Date(),
            data: DisciplineWidgetData(streakDays: 14, calorieBalance: -320, intakeCalories: 1850, burnedCalories: 2170, habitProgressPercent: 80)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DisciplineEntry) -> ()) {
        let entry = DisciplineEntry(date: Date(), data: DisciplineWidgetData.loadFromSharedDefaults())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentData = DisciplineWidgetData.loadFromSharedDefaults()
        let entry = DisciplineEntry(date: Date(), data: currentData)
        // 15分ごとに自動更新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View (Small & Medium 両対応・漆黒Liquid Noirデザイン)
struct DisciplineWidgetEntryView : View {
    var entry: DisciplineProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .systemMedium {
            mediumView
        } else {
            smallView
        }
    }
    
    // MARK: - Small Widget
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DISCIPLINE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(white: 0.5))
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // カロリー収支メイン表示
            VStack(alignment: .leading, spacing: 2) {
                Text("NET BALANCE")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(Color(white: 0.45))
                
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(entry.data.calorieBalance > 0 ? "+\(entry.data.calorieBalance)" : "\(entry.data.calorieBalance)")
                        .font(.system(size: 24, weight: .light, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("kcal")
                        .font(.system(size: 9))
                        .foregroundColor(Color(white: 0.5))
                }
            }
            
            Spacer()
            
            // 下段：習慣達成率バー & ストリーク
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("HABITS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(white: 0.5))
                    Spacer()
                    Text("\(entry.data.habitProgressPercent)%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(white: 0.18))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * CGFloat(min(max(entry.data.habitProgressPercent, 0), 100)) / 100.0, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(14)
        .containerBackground(Color.black, for: .widget)
    }
    
    // MARK: - Medium Widget
    private var mediumView: some View {
        HStack(spacing: 16) {
            // 左半分：カロリー収支とIN/OUT内訳
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    Text("DISCIPLINE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("CALORIE BALANCE")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(Color(white: 0.45))
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(entry.data.calorieBalance > 0 ? "+\(entry.data.calorieBalance)" : "\(entry.data.calorieBalance)")
                        .font(.system(size: 30, weight: .light, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("kcal")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.5))
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("IN")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color(white: 0.4))
                        Text("\(entry.data.intakeCalories)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.85))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("OUT")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color(white: 0.4))
                        Text("\(entry.data.burnedCalories)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.85))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Rectangle()
                .fill(Color(white: 0.18))
                .frame(width: 1)
                .padding(.vertical, 4)
            
            // 右半分：習慣達成率リング ＆ 連続日数
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("STREAK")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(Color(white: 0.45))
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(entry.data.streakDays)")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("DAYS")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(Color(white: 0.5))
                        }
                    }
                    Spacer()
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("TODAY'S HABITS")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundColor(Color(white: 0.45))
                        Spacer()
                        Text("\(entry.data.habitProgressPercent)%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(white: 0.18))
                                .frame(height: 6)
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width * CGFloat(min(max(entry.data.habitProgressPercent, 0), 100)) / 100.0, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .containerBackground(Color.black, for: .widget)
    }
}

@main
struct DisciplineWidget: Widget {
    let kind: String = "DisciplineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DisciplineProvider()) { entry in
            DisciplineWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Discipline Status")
        .description("本日のカロリー収支と習慣達成率を漆黒のミニマルデザインで表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
