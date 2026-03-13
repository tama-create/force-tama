# force-tama

Salesforce の設定・カスタマイズをバージョン管理で管理する Salesforce DX (SFDX) プロジェクト。
GitHub Actions により、Salesforce 組織と Git 間のメタデータ変更が自動同期・自動リリースされる。

- **Salesforce API バージョン:** 65.0
- **パッケージディレクトリ:** `force-app/main/default/`

---

## ブランチ構成とリリース先

| ブランチ      | リリース先   | トリガー      |
| ------------- | ------------ | ------------- |
| `main`        | 本番組織     | push / マージ |
| `staging`     | Sandbox: stg | push / マージ |
| `development` | Sandbox: dev | push / マージ |

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
   ├─> sf-sync.yml    : org → Git 自動同期（平日 9〜19時 毎時）
   └─> sf-release.yml : ブランチへのマージ → 対応 org へ自動リリース
```

---

## GitHub Actions ワークフロー

### sf-sync.yml — 自動同期

Salesforce 組織のメタデータを取得し、`main` ブランチへ自動コミット・プッシュする。

- **スケジュール:** 平日 月〜金 9:00〜19:00（JST）毎時実行
- **手動実行:** GitHub Actions 画面から `Run workflow` で任意実行可能
- **使用シークレット:** `SFDX_AUTH_URL`

### sf-release.yml — 自動リリース

ブランチへのプッシュ（マージ）をトリガーに、対応する Salesforce 組織へリリースを実行する。

| ブランチ      | リリース先   | 使用シークレット     |
| ------------- | ------------ | -------------------- |
| `main`        | 本番組織     | `SFDX_AUTH_URL_PROD` |
| `staging`     | Sandbox: stg | `SFDX_AUTH_URL_STG`  |
| `development` | Sandbox: dev | `SFDX_AUTH_URL_DEV`  |

`release/<branch>/deploy-target.txt` に記載されたコンポーネントをデプロイする。

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

| シークレット名       | 用途                                          | 取得コマンド                                                     |
| -------------------- | --------------------------------------------- | ---------------------------------------------------------------- |
| `SFDX_AUTH_URL`      | sf-sync.yml（自動同期）用                     | `sf org display --verbose --json \| jq -r '.result.sfdxAuthUrl'` |
| `SFDX_AUTH_URL_PROD` | 本番リリース（mainブランチ）用                | 同上（本番 org で実行）                                          |
| `SFDX_AUTH_URL_STG`  | stg Sandbox リリース（stagingブランチ）用     | 同上（stg org で実行）                                           |
| `SFDX_AUTH_URL_DEV`  | dev Sandbox リリース（developmentブランチ）用 | 同上（dev org で実行）                                           |

---

## 関連リポジトリ

- **sf-tools** (`tamashimon-create/sf-tools`) — このプロジェクトと連携する Bash スクリプト群。`sf-start.sh` / `sf-restart.sh` は sf-tools が自動生成したラッパー。
