# force-tama

Salesforce の設定・カスタマイズをバージョン管理で管理する Salesforce DX (SFDX) プロジェクト。
GitHub Actions により、Salesforce 組織と Git 間のメタデータ変更が自動同期・自動リリースされる。

- **Salesforce API バージョン:** 65.0
- **パッケージディレクトリ:** `force-app/main/default/`

---

## ブランチ構成とリリース先

| ブランチ      | リリース先   | トリガー  |
| ------------- | ------------ | --------- |
| `main`        | 本番組織     | PR マージ |
| `staging`     | Sandbox: stg | PR マージ |
| `development` | Sandbox: dev | PR マージ |

> **必須:** `main` / `staging` / `development` の3ブランチは運用階層（1〜3層）に関わらず必ず作成すること。`sf-propagate.yml` が `development` ブランチの存在を前提として動作するため。

> **注意:** `sf-metasync.sh` による直接 push ではリリースは実行されない。PR マージ（人間による意図的なリリース操作）時のみデプロイする。

---

## 開発フロー

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

[GitHub Actions]
   ├─> sf-metasync.yml      : org → Git 自動同期（平日 9〜19時 毎時）
   ├─> sf-release.yml   : PR マージ → 対応 org へ自動リリース
   └─> sf-propagate.yml : main への PR マージ → staging → development へ変更を伝播
```

---

## GitHub Actions ワークフロー

### sf-metasync.yml — メタデータ自動同期

Salesforce 組織のメタデータを取得し、`main` ブランチへ自動コミット・プッシュする。

- **スケジュール:** 平日 月〜金 9:00〜19:00（JST）毎時実行
- **手動実行:** GitHub Actions 画面から `Run workflow` で任意実行可能
- **使用シークレット:** `SFDX_AUTH_URL_PROD`

### sf-release.yml — 自動リリース

PR のマージをトリガーに、対応する Salesforce 組織へリリースを実行する。
`sf-metasync.sh` による直接 push では発火しない（PR マージ時のみ）。

| ブランチ      | リリース先   | 使用シークレット     |
| ------------- | ------------ | -------------------- |
| `main`        | 本番組織     | `SFDX_AUTH_URL_PROD` |
| `staging`     | Sandbox: stg | `SFDX_AUTH_URL_STG`  |
| `development` | Sandbox: dev | `SFDX_AUTH_URL_DEV`  |

`release/<branch>/deploy-target.txt` に記載されたコンポーネントをデプロイする。

### sf-propagate.yml — 変更伝播

PR マージをトリガーに、下位ブランチへ変更を自動伝播する。
`sf-metasync.sh` による直接 push では発火しない（PR マージ時のみ）。

| マージ先  | 伝播                         |
| --------- | ---------------------------- |
| `main`    | main → staging → development |
| `staging` | staging → development        |

- **処理:** `git merge` で各ブランチへ順次マージ＆プッシュ
- **使用権限:** `GITHUB_TOKEN`（contents: write）

---

## deploy-target.txt の書き方

`release/<branch>/deploy-target.txt` にデプロイ対象のパスを1行ずつ記載する。

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

---

## GitHub Secrets の登録

| シークレット名       | 用途                                                            | 取得コマンド                                                     |
| -------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------- |
| `SFDX_AUTH_URL_PROD` | sf-metasync.yml（自動同期）用 兼 本番リリース（mainブランチ）用 | `sf org display --verbose --json \| jq -r '.result.sfdxAuthUrl'` |
| `SFDX_AUTH_URL_STG`  | stg Sandbox リリース（stagingブランチ）用                       | 同上（stg org で実行）                                           |
| `SFDX_AUTH_URL_DEV`  | dev Sandbox リリース（developmentブランチ）用                   | 同上（dev org で実行）                                           |

---

## GitHub リポジトリの設定

### 1. GitHub Secrets の登録

`Settings` → `Secrets and variables` → `Actions` → `New repository secret` で以下を登録する。

| シークレット名       | 値の取得方法                                                                 |
| -------------------- | ---------------------------------------------------------------------------- |
| `SFDX_AUTH_URL_PROD` | 本番 org に接続した状態で `sf org display --verbose --json \| jq -r '.result.sfdxAuthUrl'` |
| `SFDX_AUTH_URL_STG`  | stg Sandbox に接続した状態で同上                                             |
| `SFDX_AUTH_URL_DEV`  | dev Sandbox に接続した状態で同上                                             |
| `SLACK_BOT_TOKEN`    | Slack App の Bot User OAuth Token（`xoxb-` で始まる文字列）                 |
| `SLACK_CHANNEL_ID`   | 通知先 Slack チャンネルの ID（`C` で始まる文字列）                           |

**Slack Bot Token の取得手順:**

1. [api.slack.com/apps](https://api.slack.com/apps) → 「Create New App」→「From scratch」
2. アプリ名・ワークスペースを設定して作成
3. 「OAuth & Permissions」→「Bot Token Scopes」に `chat:write` と `chat:write.public` を追加
4. 「Install to Workspace」でインストール
5. 表示される「Bot User OAuth Token」（`xoxb-...`）をコピーして `SLACK_BOT_TOKEN` に登録
6. 通知先チャンネルを右クリック →「チャンネル詳細」→ チャンネル ID（`C` で始まる文字列）を `SLACK_CHANNEL_ID` に登録
7. 通知先チャンネルで `/invite @<アプリ名>` を実行してボットを招待

> **スレッド通知の仕組み:** dev → stg → main の順にリリースされると、同一フィーチャーブランチの通知がひとつのスレッドにまとまる。GitHub Actions キャッシュで `thread_ts` を引き継ぐことで実現。

### 2. Branch Protection Rules の設定

`Settings` → `Branches` → `Add branch ruleset` で `main` と `staging` それぞれに設定する。

**推奨設定:**

| 設定項目 | 値 |
|---|---|
| Require a pull request before merging | ✓ |
| Require status checks to pass | ✓ |
| → Status check | `check-promotion-order` |

> `check-promotion-order` を Required Status Check に追加することで、プロモーション順序（development → staging → main）を守らない PR のマージをブロックできる。

### 3. フィーチャーブランチの運用（プロモーション型）

複数フィーチャーの並走を安全に行うため、**各環境ブランチに直接 PR する**。

```
DEV001 ──→ development にPR・マージ  → dev Sandbox にデプロイ
DEV001 ──→ staging にPR・マージ      → stg Sandbox にデプロイ
DEV001 ──→ main にPR・マージ         → 本番組織にデプロイ
```

- `release/DEV001/deploy-target.txt` を一度作成すれば3環境すべてに使い回せる
- `release/branch_name.txt` は git 管理外（`.gitignore`）。sf-release.yml がマージ時に自動生成する

---

## 関連リポジトリ

- **sf-tools** (`tamashimon-create/sf-tools`) — このプロジェクトと連携する Bash スクリプト群。`sf-start.sh` / `sf-restart.sh` は sf-tools が自動生成したラッパー。
