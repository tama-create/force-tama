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
| `sf-metasync.sh`              | org からメタデータ取得 → Prettier フォーマット → Git コミット&プッシュ（GitHub Actions から呼び出し）                          |
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
       └─> sf-release.sh (ドライラン検証)
           ├─ OK → push 続行
           └─ NG → push ブロック

[GitHub Actions / sf-metasync.yml]
   └─> sf-metasync.sh (org → Git 自動同期)
```

### sf-tools が force-tama に生成するファイル

- `sf-start.sh`, `sf-restart.sh` — sf-install.sh が生成するラッパー
- `.git/hooks/pre-push` — `~/sf-tools/hooks/pre-push` を呼び出すラッパー
- `release/<branch>/deploy-target.txt` — デプロイ対象コンポーネントリスト
- `release/<branch>/remove-target.txt` — 削除対象コンポーネントリスト
- `logs/sf-*.log` — 各スクリプトの実行ログ

### deploy-target.txt の書き方

```
# コメント行・空行は無視される
# Apex クラス
force-app/main/default/classes/MyClass.cls

# LWC
force-app/main/default/lwc/myComponent

# カスタムオブジェクト・項目
force-app/main/default/objects/MyObject__c
force-app/main/default/objects/MyObject__c/fields/MyField__c.field-meta.xml
```

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

# 3. ブランチを作成してプッシュ（main / staging / development の3ブランチ必須）
#    ※ 運用上1〜2層しか使わない場合でも必ず3つ作成すること
#      （sf-propagate.yml が development ブランチの存在を前提としているため）
git checkout -b staging && git push origin staging
git checkout -b development && git push origin development
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
- GitHub Secrets に以下を登録（`sf org display --verbose --json | jq -r '.result.sfdxAuthUrl'` で取得）
  - `SFDX_AUTH_URL_PROD` — sf-metasync.yml（自動同期）用 兼 本番リリース用（mainブランチ）
  - `SFDX_AUTH_URL_STG` — stg Sandbox リリース用（stagingブランチ）
  - `SFDX_AUTH_URL_DEV` — dev Sandbox リリース用（developmentブランチ）

`npm install` は `sf-start.sh` 経由で `sf-install.sh` が自動実行する（Prettier 含む）。

## メタデータ構造

- `force-app/main/default/flexipages/` — Lightning アプリのユーティリティバー 12 件（例: `LightningSales_UtilityBar`）
- `force-app/main/default/layouts/` — Salesforce オブジェクトのページレイアウト 199 件以上
- `force-app/main/default/permissionsets/` — 権限セット 4 件（ProfileManager・DevOps・NamedCredentials・内部 SFDC Security）
- `release/main/` / `release/staging/` / `release/development/` — ブランチごとの個別デプロイパッケージ定義

## CI/CD 同期フロー（GitHub Actions）

1. `.github/workflows/sf-metasync.yml` が平日 9〜19時（JST）に毎時実行、または手動トリガー
2. `SFDX_AUTH_URL_PROD` シークレットで Salesforce 認証
3. `sfdx-git-delta`（Java 17 必須）でコミット間のメタデータ差分を抽出
4. `sf-metasync.sh` が org からメタデータ取得 → Prettier フォーマット → Git に自動コミット

## CI/CD リリースフロー（GitHub Actions）

`.github/workflows/sf-release.yml` がブランチへのプッシュ（マージ）をトリガーに、対応する Salesforce 組織へ自動リリースする。

| ブランチ      | リリース先   | 使用シークレット     |
| ------------- | ------------ | -------------------- |
| `main`        | 本番組織     | `SFDX_AUTH_URL_PROD` |
| `staging`     | Sandbox: stg | `SFDX_AUTH_URL_STG`  |
| `development` | Sandbox: dev | `SFDX_AUTH_URL_DEV`  |

- `release/<branch>/deploy-target.txt` に記載されたコンポーネントをデプロイする
- 各 Sandbox の認証 URL は `sf org display --verbose --json | jq -r '.result.sfdxAuthUrl'` で取得し、GitHub Secrets に登録する
