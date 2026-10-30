# 開発ルール (Discipline App - Release Edition)

## バージョン・ステータス管理ルール
1. **ファイル更新の徹底**
   - 機能追加・バグ修正・仕様変更を行った際は、必ず `PROJECT_STATE.md` を最新状態に更新すること。
2. **App Store Connect とのバージョン同期管理**
   - バージョン番号（`MARKETING_VERSION` / `PROJECT_STATE.md` の Version）は **App Store Connect 上の公開バージョンと完全同期** させること（初回リリースは `v1.0` / Build `1`）。
   - 同一ストアバージョン内での修正・再アーカイブ時はビルド番号（`CURRENT_PROJECT_VERSION`：例 `Build 1` -> `Build 2`）を上げ、ストアアップデート時は App Store Connect の次期バージョン（例: `v1.1` や `v1.0.1`）に合わせて更新し、更新履歴（Changelog）に日付・変更内容・変更ファイルを記録すること。
3. **作業開始時の確認**
   - 新しいタスクに着手する際は、まず `PROJECT_STATE.md` を読み込み、現在の実装状況とディレクトリ構成を把握してから作業に入ること。
4. **App Store 審査ガイドライン & セキュリティ準拠**
   - APIキーや認証情報をソースコード内にハードコードしないこと（BYOK方式または環境変数を使用）。
   - Gemini API のモデル名は特定世代（`gemini-1.5-*`, `gemini-2.0-*`, `gemini-2.5-*` 等）をハードコードせず、環境変数（`GEMINI_MODEL`）および最新エイリアス（`gemini-flash-lite-latest` 等）で動的に解決すること。

