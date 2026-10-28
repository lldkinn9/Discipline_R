import Foundation
import Combine

// MARK: - Gemini API 通信クライアント（BYOK対応・環境変数動的解決 & フォールバック実装）
final class GeminiClient: ObservableObject {
    static let shared = GeminiClient()
    
    // BYOK: ユーザーが設定画面から入力したAPIキーを保存するキー名
    private let apiKeyStorageKey = "user_gemini_api_key"
    
    // モデル名の環境変数による動的解決（ハードコード防止ポリシー準拠）
    var primaryModel: String {
        if let envModel = ProcessInfo.processInfo.environment["GEMINI_MODEL"],
           !envModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envModel.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "gemini-flash-lite-latest"
    }
    
    var backupModel: String {
        if let envBackup = ProcessInfo.processInfo.environment["GEMINI_BACKUP_MODEL"],
           !envBackup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envBackup.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "gemini-flash-latest"
    }
    
    var reserveModel: String {
        if let envReserve = ProcessInfo.processInfo.environment["GEMINI_RESERVE_MODEL"],
           !envReserve.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envReserve.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "gemini-pro-latest"
    }
    
    @Published var isGenerating: Bool = false
    @Published var currentActiveModel: String = ""
    
    var apiKey: String {
        get {
            // 1. ユーザーが設定画面から登録したキーを最優先
            if let savedKey = UserDefaults.standard.string(forKey: apiKeyStorageKey),
               !savedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return savedKey.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            // 2. 環境変数に指定があれば使用
            if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
               !envKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return envKey.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: apiKeyStorageKey)
            objectWillChange.send()
        }
    }
    
    var hasValidKey: Bool {
        return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private init() {
        self.currentActiveModel = primaryModel
    }
    
    // MARK: - AIアドバイザー用プロンプト送信（自動フォールバック付き）
    func generateCoachingAdvice(systemPrompt: String, userContext: String) async throws -> String {
        guard hasValidKey else {
            throw NSError(domain: "GeminiClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini APIキーが設定されていません。SETTINGS画面よりご自身のAPIキーを設定してください。"])
        }
        
        await MainActor.run { self.isGenerating = true }
        defer { Task { @MainActor in self.isGenerating = false } }
        
        let modelsToTry = [primaryModel, backupModel, reserveModel]
        var lastError: Error?
        
        for model in modelsToTry {
            do {
                await MainActor.run { self.currentActiveModel = model }
                let responseText = try await callGeminiAPI(model: model, systemPrompt: systemPrompt, userMessage: userContext)
                return responseText
            } catch {
                print("⚠️ [\(model)] での生成に失敗しました。次のバックアップモデルへフォールバックします: \(error.localizedDescription)")
                lastError = error
                continue
            }
        }
        
        throw lastError ?? NSError(domain: "GeminiClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "すべてのAIモデルとの通信に失敗しました。APIキーまたは通信環境をご確認ください。"])
    }
    
    private func callGeminiAPI(model: String, systemPrompt: String, userMessage: String) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")
        components?.queryItems = [URLQueryItem(name: "key", value: trimmedKey)]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(trimmedKey, forHTTPHeaderField: "x-goog-api-key")
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
            throw NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorBody)"])
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

