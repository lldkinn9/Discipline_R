import Foundation

struct ActivityRecord: Codable, Identifiable {
    var id: String { dateString }
    let dateString: String // "yyyy-MM-dd"
    
    // カレンダー専用 6大スタンプ項目（Habitとは完全別管理）
    var hasWorkout: Bool
    var hasRunning: Bool
    var hasReading: Bool
    var hasStudy: Bool
    var hasHealth: Bool
    var hasDiscipline: Bool
    
    var note: String?
    
    var isWorkoutCompleted: Bool {
        get { hasWorkout }
        set { hasWorkout = newValue }
    }
    var isRunningCompleted: Bool {
        get { hasRunning }
        set { hasRunning = newValue }
    }
    var isReadingCompleted: Bool {
        get { hasReading }
        set { hasReading = newValue }
    }
    var isStudyCompleted: Bool {
        get { hasStudy }
        set { hasStudy = newValue }
    }
    var isHealthCompleted: Bool {
        get { hasHealth }
        set { hasHealth = newValue }
    }
    var isDisciplineCompleted: Bool {
        get { hasDiscipline }
        set { hasDiscipline = newValue }
    }
    
    init(
        dateString: String,
        hasWorkout: Bool = false,
        hasRunning: Bool = false,
        hasReading: Bool = false,
        hasStudy: Bool = false,
        hasHealth: Bool = false,
        hasDiscipline: Bool = false,
        note: String? = nil
    ) {
        self.dateString = dateString
        self.hasWorkout = hasWorkout
        self.hasRunning = hasRunning
        self.hasReading = hasReading
        self.hasStudy = hasStudy
        self.hasHealth = hasHealth
        self.hasDiscipline = hasDiscipline
        self.note = note
    }
    
    enum CodingKeys: String, CodingKey {
        case dateString
        case hasWorkout
        case hasStrengthTraining
        case hasRunning
        case hasReading
        case hasStudy
        case hasHealth
        case hasDiscipline
        case note
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateString = try container.decode(String.self, forKey: .dateString)
        
        if let workout = try? container.decode(Bool.self, forKey: .hasWorkout) {
            hasWorkout = workout
        } else if let oldWorkout = try? container.decode(Bool.self, forKey: .hasStrengthTraining) {
            hasWorkout = oldWorkout
        } else {
            hasWorkout = false
        }
        
        hasRunning = (try? container.decode(Bool.self, forKey: .hasRunning)) ?? false
        hasReading = (try? container.decode(Bool.self, forKey: .hasReading)) ?? false
        hasStudy = (try? container.decode(Bool.self, forKey: .hasStudy)) ?? false
        hasHealth = (try? container.decode(Bool.self, forKey: .hasHealth)) ?? false
        hasDiscipline = (try? container.decode(Bool.self, forKey: .hasDiscipline)) ?? false
        note = try? container.decode(String.self, forKey: .note)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dateString, forKey: .dateString)
        try container.encode(hasWorkout, forKey: .hasWorkout)
        try container.encode(hasRunning, forKey: .hasRunning)
        try container.encode(hasReading, forKey: .hasReading)
        try container.encode(hasStudy, forKey: .hasStudy)
        try container.encode(hasHealth, forKey: .hasHealth)
        try container.encode(hasDiscipline, forKey: .hasDiscipline)
        try container.encodeIfPresent(note, forKey: .note)
    }
}
