# Discipline (Release Edition) - プロジェクトステータス管理

## 現在のバージョン
- **Version:** `v1.0.2`
- **Last Updated:** `2026-10-28`
- **Phase:** App Store 公開版（Release版）リファクタリング・アセット構築完了 & Xcodeビルド検証済み

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

