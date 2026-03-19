# force-tama

Salesforce の設定・カスタマイズをバージョン管理で管理する Salesforce DX (SFDX) プロジェクト。
GitHub Actions により、Salesforce 組織と Git 間のメタデータ変更が自動同期・自動リリースされる。

- **Salesforce API バージョン:** 65.0
- **パッケージディレクトリ:** `force-app/main/default/`

---

## ブランチ構成とリリース先

| ブランチ    | リリース先          | トリガー  |
| ----------- | ------------------- | --------- |
| `main`      | 本番組織            | PR マージ |
| `staging`   | Sandbox: staging    | PR マージ |
| `develop`   | Sandbox: develop    | PR マージ |

> **必須:** `main` / `staging` / `develop` の3ブランチは運用階層（1〜3層）に関わらず必ず作成すること。`sf-propagate.yml` が `develop` ブランチの存在を前提として動作するため。

> **注意:** `sf-metasync.sh` による直接 push ではリリースは実行されない。PR マージ（人間による意図的なリリース操作）時のみデプロイする。

---

## 開発フロー

```
[開発者] bash sf-start.sh
   └─> sf-install.sh (sf-tools 更新)
   └─> sf-hook.sh (pre-push フック設置)
   └─> release/<branch>/ ディレクトリ生成
   └─> org 認証 → VSCode 起動

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
   └─> sf-validate.yml  : PR 作成時にマージ順序チェック → Salesforce デプロイ前検証（2段階）
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

| ブランチ    | リリース先          | 使用シークレット     |
| ----------- | ------------------- | -------------------- |
| `main`      | 本番組織            | `SFDX_AUTH_URL_PROD` |
| `staging`   | Sandbox: staging    | `SFDX_AUTH_URL_STG`  |
| `develop`   | Sandbox: develop    | `SFDX_AUTH_URL_DEV`  |

`release/<branch>/deploy-target.txt` に記載されたコンポーネントをデプロイする。

### sf-propagate.yml — 変更伝播

`main` への PR マージをトリガーに、`staging` と `develop` へ直接変更を伝播する。
`sf-metasync.sh` による直接 push では発火しない（PR マージ時のみ）。失敗時は Slack に通知する。

| トリガー          | 伝播先                                  |
| ----------------- | --------------------------------------- |
| `main` へのマージ | main → staging（直接）、main → develop（直接） |

- **処理:** `git merge origin/main` を staging・develop それぞれに実行してプッシュ
- **使用権限:** `GITHUB_TOKEN`（contents: write）
- **注意:** `staging` へのマージでは発火しない。staging → develop への伝播は自動では行われない

---

### sf-validate.yml — マージ順序チェック + PR 検証（2段階）

PR 作成・更新をトリガーに、2段階のチェックを実行する。

**Job 1: マージ順序チェック**（`staging` / `main` への PR のみ）

| PR のマージ先 | 確認内容                               |
| ------------- | -------------------------------------- |
| `staging`     | フィーチャーブランチが `develop` にマージ済みか |
| `main`        | フィーチャーブランチが `staging` にマージ済みか |

- 順序が守られていない場合は PR の Annotations に**黄色いワーニングバナー**を表示し、Slack に通知する（マージはブロックしない）
- マージ元が `develop` / `staging` の場合は `::error::` でブロックし、Job 2 もスキップ

**Job 2: Salesforce デプロイ前検証**（Job 1 が失敗した場合はスキップ）

- **main 最新取込確認:** feature ブランチが `main` の最新を取り込み済みか確認。未取込の場合は検証を失敗させてマージをブロック
- **dry-run 検証:** `sf project deploy start --dry-run` を実行し、デプロイ可能かを確認

---

## deploy-target.txt の書き方

`release/<branch>/deploy-target.txt` は `[files]` / `[members]` の2セクション構成。

```
[files]
# ファイルパスで指定するコンポーネント（通常はこちら）
# force-app/main/default/ からの相対パスで記述する

# Apex クラス（.cls を指定するだけで -meta.xml も自動処理）
force-app/main/default/classes/MyClass.cls

# LWC（ディレクトリを指定）
force-app/main/default/lwc/myComponent

# カスタムオブジェクト（ディレクトリ指定で項目・ルール等すべて含む）
force-app/main/default/objects/MyObject__c

# カスタム項目（フィールド単位で指定）
force-app/main/default/objects/MyObject__c/fields/MyField__c.field-meta.xml

[members]
# 1ファイルに複数メンバーが集約されているコンポーネントを部分指定する場合
# 書き方: メタデータ種別名:メンバー名

# カスタムラベル（特定ラベルのみ）
CustomLabel:MyLabel

# プロファイル
Profile:Admin
```

- `[files]` — パス指定（通常はこちらを使う）
- `[members]` — カスタムラベル・プロファイル・翻訳など、1ファイルに複数メンバーが集約されているものを部分的にデプロイする場合に使用
- 行頭 `#` はコメント、空行は無視される

---

## GitHub Secrets の登録

| シークレット名       | 用途                                                            | 取得コマンド                                                     |
| -------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------- |
| `SFDX_AUTH_URL_PROD` | sf-metasync.yml（自動同期）用 兼 本番リリース（mainブランチ）用       | `sf org display --verbose --json \| jq -r '.result.sfdxAuthUrl'` |
| `SFDX_AUTH_URL_STG`  | staging Sandbox リリース（stagingブランチ）用                         | 同上（staging org で実行）                                       |
| `SFDX_AUTH_URL_DEV`  | develop Sandbox リリース（developブランチ）用                         | 同上（develop org で実行）                                       |
| `SLACK_BOT_TOKEN`    | Slack リリース通知用 Bot Token（`xoxb-` で始まる文字列）        | [api.slack.com/apps](https://api.slack.com/apps) で取得          |
| `SLACK_CHANNEL_ID`   | 通知先 Slack チャンネル ID（`C` で始まる文字列）                | チャンネル詳細から確認                                           |

---

## GitHub リポジトリの設定

### 1. GitHub Secrets の登録

`Settings` → `Secrets and variables` → `Actions` → `New repository secret` で以下を登録する。

| シークレット名       | 値の取得方法                                                                 |
| -------------------- | ---------------------------------------------------------------------------- |
| `SFDX_AUTH_URL_PROD` | 本番 org に接続した状態で `sf org display --verbose --json \| jq -r '.result.sfdxAuthUrl'` |
| `SFDX_AUTH_URL_STG`  | staging Sandbox に接続した状態で同上                                         |
| `SFDX_AUTH_URL_DEV`  | develop Sandbox に接続した状態で同上                                         |
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

`Settings` → `Rules` → `Rulesets` → `New ruleset` → `New branch ruleset` で設定する。

**`protect-main`（mainブランチ用）推奨設定:**

| 設定項目                              | 値  |
| ------------------------------------- | --- |
| Restrict deletions                    | ✓   |
| Require a pull request before merging | ✓ (Required approvals: 1) |
| Block force pushes                    | ✓   |

**`protect-staging`（stagingブランチ用）任意設定:**

`main` と同様の設定を `staging` にも適用することを推奨。

> **注意:** `sf-validate` の Job 1（マージ順序チェック）は**警告のみ・マージはブロックしない**。PR の Annotations に警告バナーが表示された場合はレビュアーが確認して判断する。ただし直接ブランチ（`develop` / `staging`）からの PR は `::error::` でブロックされる。

### 3. フィーチャーブランチの運用（プロモーション型）

複数フィーチャーの並走を安全に行うため、**各環境ブランチに直接 PR する**。

```
DEV001 ──→ develop にPR・マージ      → develop Sandbox にデプロイ
DEV001 ──→ staging にPR・マージ      → staging Sandbox にデプロイ
DEV001 ──→ main にPR・マージ         → 本番組織にデプロイ
```

- `release/DEV001/deploy-target.txt` を一度作成すれば3環境すべてに使い回せる
- `release/branch_name.txt` は git 管理外（`.gitignore`）。sf-release.yml がマージ時に自動生成する

---

## 関連リポジトリ

- **sf-tools** (`tamashimon-create/sf-tools`) — このプロジェクトと連携する Bash スクリプト群。`sf-start.sh` / `sf-restart.sh` は sf-tools が自動生成したラッパー。
