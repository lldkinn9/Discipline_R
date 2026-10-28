# Discipline (Release Edition) - プロジェクトステータス管理

## 現在のバージョン
- **Version:** `v1.0.10`
- **Last Updated:** `2026-10-28`
- **Phase:** 収益化機能（画面下部バナー広告 ＆ ¥500 Pro版買い切りアップデート）実装完了

---

## 1. プロダクト概要・デザインコンセプト
- **アプリ名:** Discipline (Project: `Discipline_R`)
- **ターゲットOS:** iOS 16.0以上 (SwiftUI / Xcode 16)
- **デザインコンセプト:** "Liquid Noir"
  - 完全な漆黒（`#000000`）背景と純白（`#FFFFFF`）・グレースケールのみで構成されたストイックなラグジュアリーUI。
  - タブバーは物理挙動（拡大・縮小・ハイライト連動）を伴う「リキッドグラス・カプセルバー（水滴スライド式）」を採用。
  - 全ボタン・トグル・タブ移動に `HapticManager` による触覚フィードバック（Haptics）を実装。

---

## 2. 識別子・ターゲット構成（個人版との実機共存仕様）
- **Main App Bundle ID:** `com.lldkinn9.Discipline-R` (`com.lldkinn9.DisciplineApp` 互換)
- **Widget Bundle ID:** `com.lldkinn9.Discipline-R.Widget` (`com.lldkinn9.DisciplineApp.Widget` 互換)
- **App Group ID:** `group.com.lldkinn9.Discipline-R`（`group.com.lldkinn9.DisciplineApp` とも互換同期）

---

## 3. ディレクトリ・ファイル構成 (`Discipline_R/` & `DisciplineWidget/`)
- `Discipline_R/App/`
  - `DisciplineApp.swift`: エントリポイント、初回起動時の医療免責事項同意モーダル、5タブ管理（DASHBOARD / HABITS / CALENDAR / AI ADVISOR / SETTINGS）、ドラッグ＆タップ対応リキッドグラスTabBar
- `Discipline_R/Models/`
  - `ActivityRecord.swift`: 日次アクティビティモデル
  - `HabitItem.swift`: 個別習慣モデル
- `Discipline_R/Services/`
  - `HealthKitManager.swift`: Apple HealthKit 一本化による歩数・消費カロリー（活動＋基礎代謝）・摂取カロリー・PFC実量・体重・体脂肪率の取得＆過去60日分の日次コレクション集計
  - `HabitManager.swift`: 習慣データの永続化、上下並び替え、30種類の背景画像プリセット、曜日・時刻指定ローカル通知スケジューリング
  - `GeminiClient.swift`: BYOK対応 Gemini API クライアント（環境変数 `GEMINI_MODEL` 動的解決＆マルチモデル自動フォールバック）
  - `HapticManager.swift`: アプリ全体の触覚フィードバック管理
  - `WidgetDataSharer.swift`: 本体アプリから App Group 経由で Widget へ最新データを即時同期
- `Discipline_R/Views/`
  - `Main/MainDashboardView.swift`: カロリー収支、月〜日の曜日別対比バーチャート、一般バランス栄養基準（P 13-20%, F 20-30%, C 50-65%）のPFCバランス、Empty State 案内バナー
  - `Main/HabitTrackerSection.swift`: 21:9 背景画像付き習慣カード、上下並び替えボタン、3ステップ習慣作成ウィザード
  - `Habit/HabitTabView.swift`: HABITS専用タブ、5週間ヒートマップ、直近7日間の習慣別達成マトリクス
  - `Calendar/CalendarView.swift`: 6大規律スタンプ付き月間カレンダー、選択日の詳細レポート＆過去日の習慣記録修正機能
  - `Calendar/DisciplineHeatmapView.swift`: 過去35日間の習慣達成度ヒートマップ
  - `AICoach/AICoachView.swift`: AI ADVISOR 画面（BYOKオーバーレイ、時間帯別ペース評価による1日の振り返り、自由入力への直接回答）
  - `AICoach/KnowledgeBase.swift`: 厚生労働省・WHO等の一般栄養基準に基づくシステムプロンプト（医療用語排除・時間帯別ペース評価・直接回答分岐）
  - `Settings/SettingsView.swift`: BYOK Gemini APIキー設定、1日の規律目標スライダー、医療免責事項表示
  - `Common/SkeletonView.swift`: データ読み込み時のスケルトンアニメーションView
- `Discipline_R/Assets.xcassets/`
  - `AppIcon.appiconset/`: 1024×1024px 完全漆黒（`#000000`）背景＋純白（`#FFFFFF`）幾何学ミニマルシンボルのAppIcon（RGB・透過なし）
  - `Gemini_Generated_Image_*.imageset/`: 全30種類の21:9習慣カード背景画像アセット
- `DisciplineWidget/`
  - `DisciplineWidget.swift`: ホーム画面用 WidgetKit Extension（Small / Medium 両サイズ対応）

---

## 4. 更新履歴 (Changelog)
### `v1.0.10` (2026-10-28)
- **収益化機能（画面下部バナー広告 ＆ 設定画面からの ¥500 Pro版アップデート）の実装:**
  - `StoreManager.swift`: StoreKit 2 による非消耗型（買い切り）App内課金 `com.lldkinn9.DisciplineR.pro`（¥500）の購入・権利確認・トランザクション監視・購入復元（`restorePurchases()` / Guideline 3.1.1 必須要件）を実装。
  - `AdBannerView.swift` & `DisciplineApp.swift`: 画面下部（リキッドカプセルTabBarの直上）に 50pt バナー広告枠（`AdBannerContainerView`：GoogleMobileAds SDK 自動連携 ＆ 内蔵フォールバックバナー対応）を配置し、Pro版購入時は即座に非表示化＆レイアウト余白を自動調整する仕組みを実装。
  - `SettingsView.swift`: 設定画面最上部に `DISCIPLINE PRO (AD-FREE UPGRADE)` セクション（¥500 アップデートボタン、「購入を復元」ボタン、Pro有効バッジ、DEBUGテスト購入機能）を追加。
  - `DisciplineStore.storekit`: Xcode ローカル課金テスト用の StoreKit 2 設定ファイルを追加。

### `v1.0.9` (2026-10-28)
- **Gemini API 多重フェールオーバー・`models.list` 動的選定＆モデル診断の完全実装:**
  - `GeminiClient.swift`:
    1. メインモデル（`GEMINI_MODEL` || `"gemini-flash-lite-latest"`）➔ サブモデル（`GEMINI_BACKUP_MODEL` || `"gemini-flash-latest"`）➔ 予備モデル（`models.list` から `generateContent` 対応の有効モデルを動的抽出・優先度ソートして自動選定）の3段階＋動的予備チェーンを構築。
    2. `HTTP 404`（モデル廃止/未存在）、`HTTP 429`（`RESOURCE_EXHAUSTED` / クォータ上限）、`HTTP 500/503`（サーバー過負荷）発生時にエラーを画面に出さず即座に裏で次モデル（および `models.list` からリアルタイム再取得した有効モデル群）へ自動フェールオーバーするリトライループを実装。
    3. `AQ...` から始まる最新APIキー仕様に完全対応するサニタイズ処理（空白・改行・制御文字・引用符の除去と `.` `-` `_` の保持）およびパーセントエンコーディング処理を実装。
  - `SettingsView.swift`:
    - APIキー保存時および「診断」ボタン押下時に `models.list` (`https://generativelanguage.googleapis.com/v1beta/models`) へ疎通確認を行い、`HTTP 200 OK` ステータス・利用可能モデル数・動的選定された予備モデル名を画面上にリアルタイム表示する診断パネルを追加。

### `v1.0.8` (2026-10-28)
- **週間カロリー収支ウィジェット（Medium横長専用・日曜〜土曜 7カラムUI）の完全再現:**
  - `DisciplineWidget.swift` を Medium サイズ（`.systemMedium`）専用に統一し、上部に `DISCIPLINE / WEEKLY CALORIES` と週間合計ピル（`IN / OUT / NET`）、下部に日曜（`SUN`）〜土曜（`SAT`）の7カラムカード（当日白反転バッジ、摂取・消費2本棒グラフ、摂取・消費・収支の3段数値表示）を実装。
  - `WidgetDataSharer.swift` および `HealthKitManager.swift` を拡張し、日曜〜土曜の7日間カロリーデータを App Group 経由でウィジェットへ自動同期する処理を実装（変更ファイル: `DisciplineWidget/DisciplineWidget.swift`, `Discipline_R/Services/WidgetDataSharer.swift`, `Discipline_R/Services/HealthKitManager.swift`）。

### `v1.0.7` (2026-10-28)
- **正式アプリアイコン（案B: Minimal Monolith "D"）の適用:**
  - `Discipline_R/Assets.xcassets/AppIcon.appiconset/AppIcon.png` に、完全漆黒（`#000000`）背景＋純白（`#FFFFFF`）の幾何学モノグラム「Minimal Monolith "D"」（1024×1024px・24bit RGB・透過なし）を正式適用。

### `v1.0.6` (2026-10-28)
- **Widget Extension (`DisciplineWidgetExtension`) の Xcode プロジェクト統合 & AppIcon 刷新:**
  - `Discipline_R.xcodeproj/project.pbxproj` に WidgetKit 拡張ターゲット `DisciplineWidgetExtension` (`com.lldkinn9.Discipline-R.Widget`) を追加し、`group.com.lldkinn9.Discipline-R` の App Group エンタイトルメント（`DisciplineWidgetConfig/DisciplineWidget.entitlements`）および `DisciplineWidgetConfig/Info.plist` を構成。
  - `DisciplineWidget/DisciplineWidget.swift` に iOS 16 / iOS 17+ 両対応の漆黒背景ヘルパー `.widgetBlackBackground()` を追加。
  - `AppIcon.png` を5つのデザイン案（案A〜案E）から選択可能に整備（初期値として案Aの完全漆黒フルブリード版 Liquid Noir Droplet を設定）。

### `v1.0.5` (2026-10-28)
- **App Store 審査提出に向けたプロジェクト全体総点検・コンプライアンス強化:**
  - **Guideline 1.4.1（医学・栄養根拠の出典リンク明示）:** `AICoachView.swift` および `SettingsView.swift` に、厚生労働省「日本人の食事摂取基準」および WHO（世界保健機関）Healthy Diet の公式Webサイトへの直接参照リンク（`Link`）を設置。
  - **Guideline 5.1.1 / 5.1.2（AIデータ送信の透明性＆端末内データ初期化機能）:** AIアドバイザー利用時に当日の集計値が Google Gemini API へ送信される旨を明記し、`SettingsView.swift` に端末内の保存データ（習慣・APIキー・目標値）をワンタップで全消去できる初期化機能を実装。
  - **暗号化輸出規制（Export Compliance）自動免除設定:** `project.pbxproj` に `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` を追加し、App Store Connect アップロード時の暗号化確認ダイアログを自動スキップ化。
  - **コンソールフォーマット警告の解消:** `MainDashboardView.swift` のPFC比率表示を `Text(verbatim:)` に修正。

### `v1.0.4` (2026-10-28)
- **設定画面（`SettingsView.swift`）へのプライバシーポリシー＆サポート導線追加 (Guideline 5.1.1 & 5.1.3 対応):**
  - `SETTINGS` 画面下部に `PRIVACY POLICY & SUPPORT` セクションを新設。
  - アプリ内モーダル（`PrivacyPolicySheetView`）によるプライバシーポリシー全文表示、および GitHub Pages で公開した Web版プライバシーポリシー（`https://lldkinn9.github.io/Discipline_R/privacy.html`）・サポートページ（`https://lldkinn9.github.io/Discipline_R/`）への直接リンクを実装（変更ファイル: `Discipline_R/Views/Settings/SettingsView.swift`）。

### `v1.0.3` (2026-10-28)
- **Xcode プロジェクト設定（`project.pbxproj`）のリリース向け最適化:**
  - ホーム画面およびヘルスケア権限ダイアログの表示名（`CFBundleDisplayName`）を `Discipline_R` から `Discipline` に確定。
  - アプリカテゴリ（`LSApplicationCategoryType`）を `Healthcare & Fitness` に設定。
  - iPhoneの画面向きを縦画面固定（`UIInterfaceOrientationPortrait`）に設定し、横回転によるレイアウト崩れを防止（変更ファイル: `Discipline_R.xcodeproj/project.pbxproj`）。

### `v1.0.2` (2026-10-28)
- **Xcode 16 ビルド修正 (`UIKit` 明示インポート追加):**
  - `HabitManager.swift` 等において `UIImpactFeedbackGenerator.FeedbackStyle` (`.light`) および `UINotificationFeedbackGenerator.FeedbackType` (`.success`) を参照する際の `import UIKit` 欠落を修正（変更ファイル: `HabitManager.swift`, `DisciplineApp.swift`, `MainDashboardView.swift`, `HabitTrackerSection.swift`, `CalendarView.swift`, `AICoachView.swift`, `SettingsView.swift`）。

### `v1.0.1` (2026-10-28)
- **App Store 審査基準（Guideline 1.4.1, 2.1, 3.1.1, 5.1.3）適合リファクタリング & 公開版構築:**
  1. **健康アプローチの一般化 (Guideline 1.4.1):** ケトジェニック・分子栄養学ルールを撤廃し、厚生労働省・WHO推奨の一般バランス栄養（P 13〜20%, F 20〜30%, C 50〜65%）によるセルフモニタリングへ刷新。
  2. **AI ADVISOR 改称・直接回答化・時間帯ペース評価・BYOK対応 (Guideline 2.1 & 3.1.1):** 「AI COACH」を「AI ADVISOR」へ改称、医療用語を全廃、自由入力時の直接回答プロンプト分岐、現在時刻に応じた進捗ペース評価、外部課金リンクのないオプショナルBYOK UIを実装。Geminiモデル名を環境変数（`GEMINI_MODEL`）と公式最新エイリアス（`gemini-flash-lite-latest`）による動的解決へ更新。
  3. **Apple HealthKit 一本化 & Empty State 対応:** 外部API（My Trainer）連携を完全撤去し、全指標を HealthKit に一本化。データ0件時の親切な案内バナーを追加。
  4. **医療免責事項の設置 (Guideline 1.4.1):** 初回起動時の同意モーダルおよび SETTINGS 画面に免責事項を設置。
  5. **AppIcon & 全30種 Habit 画像アセットカタログの構築:** アルファなし1024×1024px `#000000` × `#FFFFFF` 幾何学ミニマルAppIconおよび全30枚の習慣背景画像アセットを `Discipline_R/Assets.xcassets` に統合。

