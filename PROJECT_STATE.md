# Discipline (Release Edition) - プロジェクトステータス管理

## 現在のバージョン
- **Version:** `v1.0.13`
- **Last Updated:** `2026-10-29`
- **Phase:** HABITS画面の個人版UI刷新 ＆ SETTINGS画面の目標設定撤去・iOSヘルスケア連携セクション新設完了

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
  - `HabitManager.swift`: 習慣データの永続化、上下並び替え、重複を厳密排除した26種類の固有背景画像プリセット、曜日・時刻（任意）指定ローカル通知スケジューリング
  - `GeminiClient.swift`: BYOK対応 Gemini API クライアント（環境変数 `GEMINI_MODEL` 動的解決＆マルチモデル自動フォールバック）
  - `HapticManager.swift`: アプリ全体の触覚フィードバック管理
  - `WidgetDataSharer.swift`: 本体アプリから App Group 経由で Widget へ最新データを即時同期
- `Discipline_R/Views/`
  - `Main/MainDashboardView.swift`: カロリー収支、月〜日の曜日別対比バーチャート、一般バランス栄養基準（P 13-20%, F 20-30%, C 50-65%）のPFCバランス、Empty State 案内バナー
  - `Main/HabitTrackerSection.swift`: 21:9 フルブリード習慣カード（完了時暗転＆28日ミニヒートマップ表示）、編集モード（削除・上下並び替え）、3ステップ習慣作成ウィザード
  - `Habit/HabitTabView.swift`: HABITS専用タブ（`HABIT & DISCIPLINE` ヘッダー、28日コンパクトヒートマップ、21:9 習慣トラッカー）
  - `Calendar/CalendarView.swift`: 6大規律スタンプ付き月間カレンダー、選択日の詳細レポート＆過去日の習慣記録修正機能
  - `Calendar/DisciplineHeatmapView.swift`: 過去28日間（4週×7日）のコンパクト習慣達成度ヒートマップ
  - `AICoach/AICoachView.swift`: AI ADVISOR 画面（BYOKオーバーレイ、時間帯別ペース評価による1日の振り返り、自由入力への直接回答）
  - `AICoach/KnowledgeBase.swift`: 厚生労働省・WHO等の一般栄養基準に基づくシステムプロンプト（医療用語排除・時間帯別ペース評価・直接回答分岐）
  - `Settings/SettingsView.swift`: Pro版アップデート、BYOK Gemini APIキー設定、iOSヘルスケア（HealthKit）連携ステータス＆リアルタイムプレビュー＆手動更新＆権限確認、医療免責事項、プライバシーポリシー表示
  - `Common/SkeletonView.swift`: データ読み込み時のスケルトンアニメーションView
- `Discipline_R/Assets.xcassets/`
  - `AppIcon.appiconset/`: 1024×1024px 完全漆黒（`#000000`）背景＋純白（`#FFFFFF`）幾何学ミニマルシンボルのAppIcon（RGB・透過なし）
  - `Gemini_Generated_Image_*.imageset/`: 全30種類の21:9習慣カード背景画像アセット
- `DisciplineWidget/`
  - `DisciplineWidget.swift`: ホーム画面用 WidgetKit Extension（Small / Medium 両サイズ対応）

---

## 4. 更新履歴 (Changelog)
### `v1.0.13` (2026-10-29)
- **HABITS タブの UI 刷新（個人版アプリ準拠） ＆ SETTINGS タブの目標設定削除・iOSヘルスケア連携セクション新設:**
  - **HABITS 画面の個人版UI完全再現 (`HabitTabView.swift` / `DisciplineHeatmapView.swift` / `HabitTrackerSection.swift` / `HabitManager.swift` / `HabitItem.swift`):**
    1. ヘッダーを個人版準拠の `HABIT & DISCIPLINE` / `CONSISTENCY & STREAK TRACKING` へ刷新し、下部の7日間マトリクス表を撤去。
    2. `DisciplineHeatmapView` を `DISCIPLINE HEATMAP (HABIT)`（4週×7日＝28日間のコンパクト正方形グリッド）へ刷新。
    3. `HabitTrackerSection` に `HABIT TRACKER` ヘッダー（`＋` 追加ボタン ＆ `編集 / 完了` モード切替ボタン）を実装。各習慣カードを `21:9` フルブリード表示＋右下モノスペースタイトル配置とし、タップ完了時に暗転（`0.75`）して左側に28日間の個別達成ミニヒートマップ（`RECORD (28D) X/28`）が浮かび上がるUIを再現。編集モードでの削除時にローカル通知も自動解除される `updateAllHabits` を実装。
  - **SETTINGS 画面の改修 ＆ 不要な目標設定の完全撤去 (`SettingsView.swift` / `HealthKitManager.swift` / `MainDashboardView.swift` / `AICoachView.swift` / `KnowledgeBase.swift` / `CalendarView.swift`):**
    1. `SETTINGS` から不要な目標設定項目（`DAILY DISCIPLINE TARGETS`：目標摂取カロリー・目標歩数・目標体重・目標体脂肪率）を完全削除し、ダッシュボード・AIアドバイザー・カレンダースタンプからも固定目標値への依存を排除。
    2. `SETTINGS` に **`APPLE HEALTH (iOS ヘルスケア連携)`** セクションを新設し、連携ステータスバッジ（`連携中` / `未連携` / `同期中...`＋最終更新時刻）、4指標リアルタイムプレビュー（摂取エネルギー・消費エネルギー・PFC実量・歩数）、**「最新データ更新」**ボタン、および**「iOS設定を開いてアクセス権限を確認」**ボタンを実装。

### `v1.0.12` (2026-10-29)
- **習慣追加・登録フローのUI/UX刷新 ＆ 曜日・実行時刻・通知の完全任意化:**
  - **STEP 1 ビジュアル選択の改善 (`HabitTrackerSection.swift` / `HabitManager.swift`):**
    1. 各ビジュアルカード左下のラベル文字列（`Habit 01` 等）を削除し、選択中カードの右下チェックマークのみを表示するクリーンなUIへ変更。
    2. 全30種のアセットを目視・バイナリ照合し、重複していた4種（`z1x4n5...`＝サッカー重複、`z7x6b9...`＝テニス重複、`f0z04f...`＝キッチン掃除重複、`trcb2k...`＝デスク筆記重複）を選択候補から除外し、かぶりのない26種（2列×13段）へ整理（既存保存データの互換維持のため `Assets.xcassets` 内の画像ファイル自体は保持）。
  - **STEP 2 習慣名入力のシンプル化 (`HabitTrackerSection.swift`):**
    - `QUICK PRESETS (タップで自動入力)` セクションを撤去。
  - **STEP 3 曜日・実行時刻・通知設定の任意化 ＆ 他機能への影響防止 (`HabitItem.swift` / `HabitManager.swift` / `HabitTrackerSection.swift` / `DisciplineHeatmapView.swift`):**
    1. 曜日を1つも選択しない状態（`targetDaysOfWeek = []`）でもそのまま登録できるよう変更。曜日未指定の習慣も `HABITS` タブ達成率・ヒートマップ・`CALENDAR` スタンプ＆過去日記録修正・`AI ADVISOR`・Widget に整合して反映。
    2. `HabitItem` の `targetHour` / `targetMinute` をオプショナル化し（既存の保存済みJSONデータとも完全後方互換）、「実行時刻を設定する」トグルにより時刻を設定せずに登録可能へ変更（時刻未設定時は習慣カード上の時計バッジも非表示化）。
    3. リマインド通知の標準表示（初期値）を「通知オフ」に変更し、通知時刻を選んだ際の自動時刻有効化および曜日未指定時の毎日定刻通知（`_daily`）に対応。

### `v1.0.11` (2026-10-28)
- **Google AdMob SDK (`GoogleMobileAds`) ＆ 本番アプリID・広告ユニットIDの完全統合:**
  - `Discipline_R.xcodeproj/project.pbxproj`: Swift Package Manager 経由で `swift-package-manager-google-mobile-ads` (`GoogleMobileAds`) を自動解決・リンクする設定および `-ObjC` リンカフラグを追加。
  - `DisciplineWidgetConfig/Discipline_R_Info.plist`: AdMob アプリID（`ca-app-pub-1148610655574304~6864807071`）、バナー広告ユニットID（`ca-app-pub-1148610655574304/3245126264`）、および Google 公式 `SKAdNetworkItems`（49件）を設定。
  - `DisciplineApp.swift` & `AdBannerView.swift`: 起動時の `GADMobileAds.sharedInstance().start()` 初期化、Guideline 5.1.3(ii) 準拠の非パーソナライズド広告（`npa=1`）リクエスト、DEBUG時の公式テストバナー表示＆Releaseビルド時の本番ユニットID自動切り替えを実装。

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

