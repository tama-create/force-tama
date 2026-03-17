# CLAUDE.md

このファイルは、リポジトリで作業する際に Claude Code (claude.ai/code) へのガイダンスを提供します。

## プロジェクト概要

Salesforce の設定・カスタマイズをバージョン管理で管理する Salesforce DX (SFDX) プロジェクト。GitHub Actions のスケジュール実行により、Salesforce サンドボックスと Git 間のメタデータ変更が自動同期される。

- **Salesforce API バージョン:** 65.0
- **パッケージディレクトリ:** `force-app/main/default/`

## sf-tools との関係

`~/sf-tools/`（`C:\Users\tamas\sf-tools`）は、このプロジェクトと密接に連携する Bash スクリプト群のリポジトリ（GitHub: `tamashimon-create/sf-tools`）。force-tama の `sf-start.sh` / `sf-restart.sh` は sf-tools が自動生成したラッパースクリプトである。

### sf-tools の主要スクリプト

| スクリプト                    | 役割                                                                                                                           |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `sf-start.sh`                 | 開発環境の初期化（1日1回実行）。sf-tools 更新 → フック設置 → org 接続確認 → VS Code 起動                                       |
| `sf-restart.sh`               | 接続先 org の切り替え（設定ファイルをクリアして sf-start.sh を再実行）                                                         |
| `sf-release.sh`               | `deploy-target.txt` / `remove-target.txt` からマニフェストを生成してデプロイ。デフォルトはドライラン（`--release` で本番実行） |
| `sf-deploy.sh`                | `sf-release.sh --release --force` のショートカット（コンフリクト無視の強制デプロイ）                                           |
| `sf-metasync.sh`              | org からメタデータ取得 → Git コミット&プッシュ（GitHub Actions から呼び出し）                                                   |
| `sf-hook.sh` / `sf-unhook.sh` | pre-push フックの設置・解除                                                                                                    |
| `sf-install.sh`               | sf-tools 本体の更新とラッパースクリプトの再生成                                                                                |

### 開発フロー

```
[開発者] bash sf-start.sh
   └─> sf-install.sh (sf-tools 更新)
   └─> sf-hook.sh (pre-push フック設置)
   └─> release/<branch>/ ディレクトリ生成
   └─> org 認証 → VS Code 起動

[コンポーネント編集]
   └─> release/<branch>/deploy-target.txt に対象を記載

[git push]
   └─> .git/hooks/pre-push
       └─> sf-mergecheck.sh (main 同期チェック)
           ├─ 同期済み → push 続行
           └─ 未取込あり → push ブロック

[GitHub Actions]
   ├─> sf-metasync.yml  : org → Git 自動同期（平日 9〜19時 毎時）
   ├─> sf-release.yml   : PR マージ → 対応 org へ自動リリース + Slack 通知
   ├─> sf-propagate.yml : main への PR マージ → staging・develop へ直接伝播
   └─> sf-sequence.yml  : staging/main への PR 作成時にマージ順序を確認（Slack 通知付き・警告のみ）
```

### sf-tools が force-tama に生成するファイル

- `sf-start.sh`, `sf-restart.sh` — sf-install.sh が生成するラッパー
- `.git/hooks/pre-push` — `~/sf-tools/hooks/pre-push` を呼び出すラッパー
- `release/<branch>/deploy-target.txt` — デプロイ対象コンポーネントリスト
- `release/<branch>/remove-target.txt` — 削除対象コンポーネントリスト
- `logs/sf-*.log` — 各スクリプトの実行ログ

### deploy-target.txt の書き方

`[files]` / `[members]` の2セクション構成。

```
[files]
# ファイルパス（force-app/main/default/ からの相対パス）で指定
force-app/main/default/classes/MyClass.cls
force-app/main/default/lwc/myComponent
force-app/main/default/objects/MyObject__c
force-app/main/default/objects/MyObject__c/fields/MyField__c.field-meta.xml

[members]
# 1ファイルに複数メンバーが集約されているコンポーネントを部分指定
# 書き方: メタデータ種別名:メンバー名
CustomLabel:MyLabel
Profile:Admin
Translations:ja
```

- `[files]` — パス指定（通常はこちら）
- `[members]` — カスタムラベル・プロファイル・翻訳など部分デプロイ時に使用
- 行頭 `#` はコメント、空行は無視される

### lib/common.sh（共有ライブラリ）

全スクリプトが利用する共通処理:

- `log LEVEL MESSAGE` — 画面（カラー）とログファイル（プレーン）への統一出力
- `run CMD [ARGS...]` — コマンド実行とエラー検出
- `die MESSAGE` — エラーログ出力して即座に終了
- 戻り値: `RET_OK`(0) / `RET_NG`(1) / `RET_NO_CHANGE`(2)

## 新規プロジェクトの作成手順

同種の `force-*` プロジェクトを新たに作成する場合の手順。

```bash
# 1. Salesforce DX プロジェクトを生成
sf project generate --name force-xxx
cd force-xxx

# 2. Git リポジトリを初期化して GitHub にプッシュ
git init
git add .
git commit -m "initial commit"
gh repo create force-xxx --private --source=. --push   # GitHub CLI 使用

# 3. ブランチを作成してプッシュ（main / staging / develop の3ブランチ必須）
#    ※ 運用上1〜2層しか使わない場合でも必ず3つ作成すること
#      （sf-propagate.yml が develop ブランチの存在を前提としているため）
git checkout -b staging && git push origin staging
git checkout -b develop && git push origin develop
git checkout main

# 4. sf-tools のラッパーを初回生成（sf-tools がインストール済みであること）
bash ~/sf-tools/sf-install.sh

# 5. 開発環境を起動（org 認証・フック設置・VS Code 起動）
bash sf-start.sh
```

### 初回セットアップ後に手動で追加が必要なもの

- `package.json` — force-tama のものをコピーして `"name"` を変更（Prettier・Husky 等の依存関係を含む）
- `.prettierrc` / `.prettierignore` — force-tama のものをそのままコピー
- `.github/workflows/sf-metasync.yml` — force-tama のものをコピーし、必要に応じて調整
- `.github/workflows/sf-release.yml` — force-tama のものをコピー（Slack通知含む）
- `.github/workflows/sf-propagate.yml` — force-tama のものをコピー
- `.github/workflows/sf-sequence.yml` — force-tama のものをコピー
- `.github/workflows/sf-validate.yml` — force-tama のものをコピー
- GitHub Secrets に以下を登録
  - `SFDX_AUTH_URL_PROD` — `sf org display --verbose --json | jq -r '.result.sfdxAuthUrl'`（本番org）
  - `SFDX_AUTH_URL_STG` — 同上（staging Sandbox）
  - `SFDX_AUTH_URL_DEV` — 同上（develop Sandbox）
  - `SLACK_BOT_TOKEN` — Slack App の Bot User OAuth Token（`xoxb-` で始まる文字列）
  - `SLACK_CHANNEL_ID` — 通知先 Slack チャンネル ID（`C` で始まる文字列）

`npm install` は `sf-start.sh` 経由で `sf-install.sh` が自動実行する。

## メタデータ構造

- `force-app/main/default/flexipages/` — Lightning アプリのユーティリティバー 12 件（例: `LightningSales_UtilityBar`）
- `force-app/main/default/layouts/` — Salesforce オブジェクトのページレイアウト 199 件以上
- `force-app/main/default/permissionsets/` — 権限セット 4 件（ProfileManager・DevOps・NamedCredentials・内部 SFDC Security）
- `release/main/` / `release/staging/` / `release/develop/` — ブランチごとの個別デプロイパッケージ定義

## CI/CD 同期フロー（GitHub Actions）

1. `.github/workflows/sf-metasync.yml` が平日 9〜19時（JST）に毎時実行、または手動トリガー
2. `SFDX_AUTH_URL_PROD` シークレットで Salesforce 認証
3. `sfdx-git-delta`（Java 17 必須）でコミット間のメタデータ差分を抽出
4. `sf-metasync.sh` が org からメタデータ取得 → Git に自動コミット

## CI/CD リリースフロー（GitHub Actions）

`.github/workflows/sf-release.yml` がPR マージをトリガーに、対応する Salesforce 組織へ自動リリースする。
`sf-metasync.sh` による直接 push では発火しない（PR マージ時のみ）。

| ブランチ    | リリース先          | 使用シークレット     |
| ----------- | ------------------- | -------------------- |
| `main`      | 本番組織            | `SFDX_AUTH_URL_PROD` |
| `staging`   | Sandbox: staging    | `SFDX_AUTH_URL_STG`  |
| `develop`   | Sandbox: develop    | `SFDX_AUTH_URL_DEV`  |

- `release/<branch>/deploy-target.txt` に記載されたコンポーネントをデプロイする
- 各 Sandbox の認証 URL は `sf org display --verbose --json | jq -r '.result.sfdxAuthUrl'` で取得し、GitHub Secrets に登録する
- リリース結果は Slack（`SLACK_BOT_TOKEN` + `SLACK_CHANNEL_ID`）に通知する
- 同一フィーチャーブランチの dev → stg → main 通知は GitHub Actions キャッシュで `thread_ts` を引き継ぎ、1つのスレッドにまとまる

## CI/CD PR 検証フロー（GitHub Actions）

`.github/workflows/sf-validate.yml` が PR 作成・更新をトリガーに dry-run 検証を実行する。

- **main 最新取込確認:** feature ブランチが `main` の最新を取り込み済みか確認。未取込の場合は検証を失敗させてマージをブロック
- **dry-run 検証:** `sf project deploy start --dry-run` を実行し、デプロイ可能かを確認

## CI/CD プロモーション確認（GitHub Actions）

`.github/workflows/sf-sequence.yml` が `staging` / `main` への PR 作成時に実行される。

| PR のマージ先 | 確認内容                                  |
| ------------- | ----------------------------------------- |
| `staging`     | フィーチャーブランチが `develop` にマージ済みか |
| `main`        | フィーチャーブランチが `staging` にマージ済みか  |

- 順序が守られていない場合は PR の Annotations に**黄色いワーニング**を表示し、Slack に通知するが、マージはブロックしない
- マージ元が `develop` / `staging` ブランチそのものの場合は `::error::` でブロック

## CI/CD 変更伝播フロー（GitHub Actions）

`.github/workflows/sf-propagate.yml` が `main` への PR マージをトリガーに、下位ブランチへ直接変更を伝播する。

| トリガー          | 伝播先                                          |
| ----------------- | ----------------------------------------------- |
| `main` へのマージ | main → staging（直接）、main → develop（直接） |

- `git merge origin/main` を staging・develop それぞれに実行してプッシュ
- `staging` へのマージでは発火しない（staging → develop の自動伝播なし）
- `sf-metasync.sh` による直接 push では発火しない（PR マージ時のみ）

### フィーチャーブランチの運用ルール（プロモーション型）

複数フィーチャーの並走を安全に行うため、**プロモーション型**を採用する。

```
DEV001 ──→ develop にPR・マージ      → develop Sandbox にデプロイ
DEV001 ──→ staging にPR・マージ      → staging Sandbox にデプロイ
DEV001 ──→ main にPR・マージ         → 本番組織にデプロイ
```

- フィーチャーブランチは `develop → staging → main` の順ではなく、**各環境ブランチに直接 PR する**
- `release/DEV001/deploy-target.txt` を一度作成すれば、3環境すべてに使い回せる
- `release/branch_name.txt` は git 管理外（`.gitignore`）。sf-release.yml がマージ時に PR のマージ元ブランチ名（`github.event.pull_request.head.ref`）を動的に書き込む
