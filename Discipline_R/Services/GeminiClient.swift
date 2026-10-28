import Foundation
import Combine

// MARK: - モデル疎通診断結果（models.list 動的チェック用）
struct GeminiDiagnosticsResult {
    let statusCode: Int
    let isKeyAQFormat: Bool
    let primaryModel: String
    let backupModel: String
    let selectedReserveModel: String
    let availableGenerateModels: [String]
    let checkedAt: Date
}

// MARK: - Gemini API 通信クライアント（BYOK・環境変数動的解決・models.list動的選定・多重フェールオーバー完全実装）
final class GeminiClient: ObservableObject {
    static let shared = GeminiClient()
    
    private let apiKeyStorageKey = "user_gemini_api_key"
    
    // 1. メインモデル: 環境変数 GEMINI_MODEL || "gemini-flash-lite-latest"
    var primaryModel: String {
        if let envModel = ProcessInfo.processInfo.environment["GEMINI_MODEL"] {
            let trimmed = envModel.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "gemini-flash-lite-latest"
    }
    
    // 2. サブバックアップモデル: 環境変数 GEMINI_BACKUP_MODEL || "gemini-flash-latest"
    var backupModel: String {
        if let envBackup = ProcessInfo.processInfo.environment["GEMINI_BACKUP_MODEL"] {
            let trimmed = envBackup.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "gemini-flash-latest"
    }
    
    @Published var isGenerating: Bool = false
    @Published var isDiagnosing: Bool = false
    @Published var currentActiveModel: String = ""
    
    // 3. 予備モデル（models.list から動的に選定された有効モデル群）
    @Published var dynamicReserveModels: [String] = []
    @Published var availableModels: [String] = []
    @Published var lastDiagnostics: GeminiDiagnosticsResult? = nil
    @Published var lastDiagnosticsError: String? = nil
    
    // 現在選定されている予備モデル名（UI表示用）
    var activeReserveModelName: String {
        if let firstReserve = dynamicReserveModels.first {
            return firstReserve
        }
        return "models.list から自動選定"
    }
    
    // 4. 最新APIキー仕様（AQ...形式等）に完全対応したサニタイズ・保存ロジック
    var apiKey: String {
        get {
            if let savedKey = UserDefaults.standard.string(forKey: apiKeyStorageKey) {
                let clean = Self.sanitizeAPIKey(savedKey)
                if !clean.isEmpty { return clean }
            }
            if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
                let clean = Self.sanitizeAPIKey(envKey)
                if !clean.isEmpty { return clean }
            }
            return ""
        }
        set {
            let clean = Self.sanitizeAPIKey(newValue)
            UserDefaults.standard.set(clean, forKey: apiKeyStorageKey)
            if clean.isEmpty {
                dynamicReserveModels = []
                availableModels = []
                lastDiagnostics = nil
                lastDiagnosticsError = nil
            }
            objectWillChange.send()
        }
    }
    
    var hasValidKey: Bool {
        return !apiKey.isEmpty
    }
    
    var isAQKeyFormat: Bool {
        return apiKey.hasPrefix("AQ.") || apiKey.hasPrefix("AQ")
    }
    
    // 空白・改行・不可視制御文字・引用符を安全に除去し、AQ...形式の記号（. - _）を完全に保持する
    static func sanitizeAPIKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let filteredScalars = trimmed.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filteredScalars))
    }
    
    // URLクエリパラメータ用の安全なパーセントエンコーディング
    private func buildEndpointURL(basePath: String, key: String) throws -> URL {
        guard var components = URLComponents(string: basePath) else {
            throw URLError(.badURL)
        }
        var allowedQueryChars = CharacterSet.urlQueryAllowed
        allowedQueryChars.remove(charactersIn: "&+=?#")
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowedQueryChars) ?? key
        components.percentEncodedQuery = "key=\(encodedKey)"
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }
    
    private init() {
        self.currentActiveModel = primaryModel
        // 起動時にAPIキーが登録済みであれば、裏で models.list から予備モデルを動的取得しておく
        if hasValidKey {
            Task {
                _ = try? await fetchAndSelectDynamicModels()
            }
        }
    }
    
    // MARK: - 3. 利用可能モデル一覧の動的チェック（models.list 疎通診断 & 予備モデル選定）
    @discardableResult
    func fetchAndSelectDynamicModels() async throws -> GeminiDiagnosticsResult {
        let cleanKey = apiKey
        guard !cleanKey.isEmpty else {
            throw NSError(domain: "GeminiClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "APIキーを設定してください。"])
        }
        
        await MainActor.run {
            self.isDiagnosing = true
            self.lastDiagnosticsError = nil
        }
        defer {
            Task { @MainActor in self.isDiagnosing = false }
        }
        
        let url = try buildEndpointURL(
            basePath: "https://generativelanguage.googleapis.com/v1beta/models",
            key: cleanKey
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cleanKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 20
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errBody = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            let errMsg = "モデル一覧の取得に失敗しました (HTTP \(httpResponse.statusCode)): \(errBody)"
            await MainActor.run { self.lastDiagnosticsError = errMsg }
            throw NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["models"] as? [[String: Any]] else {
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "models.list レスポンスの解析に失敗しました。"])
        }
        
        // generateContent に対応しているテキスト生成用 Gemini モデルを動的抽出
        var validCandidates: [String] = []
        for item in modelsArray {
            guard let fullName = item["name"] as? String else { continue }
            let shortName = fullName.replacingOccurrences(of: "models/", with: "")
            let methods = (item["supportedGenerationMethods"] as? [String]) ?? []
            
            guard methods.contains("generateContent") else { continue }
            
            // テキスト対話に適さない特殊用途モデル（embedding / imagen / veo / tts / audio / robotics / computer-use等）を除外
            let lower = shortName.lowercased()
            let excludedKeywords = [
                "embedding", "imagen", "veo", "tts", "audio", "whisper",
                "aqa", "bisheng", "robotics", "computer-use", "customtools", "image"
            ]
            if lower.hasPrefix("gemini-") && !excludedKeywords.contains(where: { lower.contains($0) }) {
                validCandidates.append(shortName)
            }
        }
        
        // メイン・サブ以外の有効モデルを優先度順（latest系・flash系・pro系）に整列して予備モデルチェーンを構築
        let primary = self.primaryModel
        let backup = self.backupModel
        let reserves = validCandidates
            .filter { $0 != primary && $0 != backup }
            .sorted { a, b in
                let aScore = Self.modelPriorityScore(a)
                let bScore = Self.modelPriorityScore(b)
                if aScore != bScore { return aScore > bScore }
                return a > b
            }
        
        let selectedReserve = reserves.first ?? validCandidates.first ?? backup
        let result = GeminiDiagnosticsResult(
            statusCode: httpResponse.statusCode,
            isKeyAQFormat: self.isAQKeyFormat,
            primaryModel: primary,
            backupModel: backup,
            selectedReserveModel: selectedReserve,
            availableGenerateModels: validCandidates,
            checkedAt: Date()
        )
        
        await MainActor.run {
            self.availableModels = validCandidates
            self.dynamicReserveModels = reserves
            self.lastDiagnostics = result
            self.lastDiagnosticsError = nil
        }
        
        return result
    }
    
    // models.list から取得したモデル名の動的優先度スコアリング（特定世代名のハードコードなし）
    private static func modelPriorityScore(_ name: String) -> Int {
        var score = 0
        let lower = name.lowercased()
        if lower.contains("latest") { score += 50 }
        if lower.contains("flash") { score += 30 }
        if lower.contains("pro") { score += 20 }
        if !lower.contains("preview") && !lower.contains("exp") { score += 15 }
        return score
    }
    
    // MARK: - 2. 多重モデル自動フォールバック（メイン ➔ サブ ➔ models.list動的予備モデル群）
    func generateCoachingAdvice(systemPrompt: String, userContext: String) async throws -> String {
        guard hasValidKey else {
            throw NSError(domain: "GeminiClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "APIキーを設定してください。（SETTINGSタブよりご自身のGemini APIキーを入力してください）"])
        }
        
        await MainActor.run { self.isGenerating = true }
        defer { Task { @MainActor in self.isGenerating = false } }
        
        // まだ models.list から予備モデルを取得していない場合は、事前に取得を試みる
        if dynamicReserveModels.isEmpty {
            _ = try? await fetchAndSelectDynamicModels()
        }
        
        // 重複を除いた優先試行チェーン: [メイン] ➔ [サブ] ➔ [models.listから選定した予備モデル群]
        var chain: [String] = []
        for candidate in ([primaryModel, backupModel] + Array(dynamicReserveModels.prefix(4))) {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !chain.contains(trimmed) {
                chain.append(trimmed)
            }
        }
        
        var lastError: Error?
        var index = 0
        var didRefreshDynamicListOnFailure = false
        
        while index < chain.count {
            let model = chain[index]
            index += 1
            
            do {
                await MainActor.run { self.currentActiveModel = model }
                let responseText = try await callGeminiAPI(model: model, systemPrompt: systemPrompt, userMessage: userContext)
                return responseText
            } catch let error as NSError {
                lastError = error
                let statusCode = error.code
                let errText = error.localizedDescription
                
                // APIキー自体が無効（API_KEY_INVALID）な場合は無駄なリトライを行わず即座にエラー通知
                if (statusCode == 400 || statusCode == 401 || statusCode == 403) &&
                   (errText.contains("API_KEY_INVALID") || errText.contains("API key not valid")) {
                    throw NSError(
                        domain: "GeminiAPI",
                        code: statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "入力されたAPIキーが無効です。SETTINGS画面で正しいGemini APIキーを設定してください。"]
                    )
                }
                
                // HTTP 404 (モデル廃止/未存在), 429 (RESOURCE_EXHAUSTED/クォータ制限), 500/503 (サーバー過負荷) 等の場合：
                // まだ models.list を最新化していなければその場で動的取得してチェーン末尾に追加
                if !didRefreshDynamicListOnFailure {
                    didRefreshDynamicListOnFailure = true
                    if let diag = try? await fetchAndSelectDynamicModels() {
                        for dynamicModel in diag.availableGenerateModels.prefix(5) {
                            if !chain.contains(dynamicModel) {
                                chain.append(dynamicModel)
                            }
                        }
                    }
                }
                
                print("⚠️ [\(model)] エラー (code: \(statusCode))。自動的に次のモデルへフェールオーバーします。")
                continue
            }
        }
        
        throw lastError ?? NSError(
            domain: "GeminiClient",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "すべてのモデル（メイン・サブ・予備）での応答生成に失敗しました。しばらく待ってから再度お試しいただくか、APIキーの設定をご確認ください。"]
        )
    }
    
    private func callGeminiAPI(model: String, systemPrompt: String, userMessage: String) async throws -> String {
        let cleanKey = apiKey
        guard !cleanKey.isEmpty else {
            throw NSError(domain: "GeminiClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "APIキーを設定してください。"])
        }
        
        let safeModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        let url = try buildEndpointURL(
            basePath: "https://generativelanguage.googleapis.com/v1beta/models/\(safeModel):generateContent",
            key: cleanKey
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(cleanKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 30
        
        let payload: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": userMessage]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.4,
                "maxOutputTokens": 1200
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "GeminiAPI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorBody)"]
            )
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "レスポンスの解析に失敗しました。"])
        }
        
        return text
    }
}
