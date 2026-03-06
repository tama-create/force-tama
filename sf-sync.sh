#!/bin/bash

# ==============================================================================
# プログラム名: sf-sync.sh
# 概要: Salesforceの変更をGitへ自動保存するツール
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 設定項目
# ------------------------------------------------------------------------------
readonly TARGET_ORG="tama"
readonly BRANCH_NAME=$(git symbolic-ref --short HEAD)
readonly COMMIT_MSG="定期更新 (Salesforceの変更を自動反映)"
readonly DELTA_DIR="./temp_delta"
readonly LOG_FILE="./sfsync_latest.log"

# 取得対象のデータ種別
readonly METADATA_TYPES=(
    ApexClass
    ApexPage
    LightningComponentBundle
    CustomObject
    CustomField
    Layout
    FlexiPage
    Flow
    PermissionSet
    CustomLabels
)

# 表示色
readonly CLR_INFO='\033[36m'
readonly CLR_SUCCESS='\033[32m'
readonly CLR_ERR='\033[31m'
readonly CLR_CMD='\033[34m'
readonly CLR_RESET='\033[0m'

# ------------------------------------------------------------------------------
# 2. 共通エンジン（ログと実行制御）
# ------------------------------------------------------------------------------

# ログの上書き初期化
: > "$LOG_FILE"

# 画面とファイルへの進捗出力
log() {
    local level=$1 stage=$2 message=$3
    local ts=$(date +'%Y-%m-%d %H:%M:%S')

    printf "[%s] [%s] [%s] %s\n" "$ts" "$level" "$stage" "$message" >> "$LOG_FILE"

    case "$level" in
        "INFO")    echo -e "${CLR_INFO}▶️  [$stage]${CLR_RESET} $message" ;;
        "SUCCESS") echo -e "${CLR_SUCCESS}✅ [$stage]${CLR_RESET} $message" ;;
        "ERROR")   echo -e "${CLR_ERR}❌ [$stage]${CLR_RESET} $message" ;;
        "CMD")     echo -e "${CLR_CMD}   > Command:${CLR_RESET} $message" ;;
    esac
}

# 全コマンドの実行管理
exec_wrapper() {
    local stage=$1; shift
    local cmd=("$@")
    local tmp_out="./cmd_output.tmp"

    [[ "${cmd[0]}" == "sf" ]] && cmd+=("--json")
    log "CMD" "$stage" "${cmd[*]}"

    "${cmd[@]}" > "$tmp_out" 2>&1
    local status=$?

    # 成功判定
    if [ $status -eq 0 ] || \
       grep -qE "nothing to commit|Already up to date|No local changes|\"status\": 0" "$tmp_out"; then
        echo "Command executed successfully. (Output suppressed)" >> "$LOG_FILE"
        rm -f "$tmp_out"
        return 0
    fi

    cat "$tmp_out" >> "$LOG_FILE"
    rm -f "$tmp_out"
    return 1
}

# ------------------------------------------------------------------------------
# 3. 作業フェーズ定義
# ------------------------------------------------------------------------------

# フェーズ1: Git環境の整理
phase_git_update() {
    [ -d "$DELTA_DIR" ] && exec_wrapper "GIT" rm -rf "$DELTA_DIR"
    exec_wrapper "GIT" git stash
    exec_wrapper "GIT" git fetch origin
    exec_wrapper "GIT" git pull origin "$BRANCH_NAME" --rebase
}

# フェーズ2: 変更箇所の分析
phase_analyze_delta() {
    exec_wrapper "DELTA" mkdir -p "$DELTA_DIR"
    exec_wrapper "DELTA" sf sgd source delta --from "origin/$BRANCH_NAME" --to HEAD --output-dir "$DELTA_DIR"
}

# フェーズ3: データのダウンロード
phase_retrieve_metadata() {
    if [ -f "$DELTA_DIR/package/package.xml" ]; then
        if ! exec_wrapper "RETRIEVE" sf project retrieve start --manifest "$DELTA_DIR/package/package.xml" --target-org "$TARGET_ORG" --ignore-conflicts; then
            return 1
        fi
    fi

    exec_wrapper "RETRIEVE" sf project retrieve start --metadata "${METADATA_TYPES[@]}" --target-org "$TARGET_ORG" --ignore-conflicts
}

# フェーズ4: 一時フォルダの削除
phase_cleanup_temp() {
    exec_wrapper "CLEAN" rm -rf "$DELTA_DIR"
}

# フェーズ5: Gitリポジトリへ反映
phase_git_sync() {
    if ! exec_wrapper "SYNC" git add -A; then
        return 1
    fi

    if exec_wrapper "SYNC" git diff-index --quiet HEAD --; then
        return 2
    fi

    if ! exec_wrapper "SYNC" git commit -m "$COMMIT_MSG"; then
        return 1
    fi

    if ! exec_wrapper "SYNC" git push origin "$BRANCH_NAME"; then
        if ! exec_wrapper "SYNC" git pull origin "$BRANCH_NAME" --rebase; then
            return 1
        fi
        exec_wrapper "SYNC" git push origin "$BRANCH_NAME"
    fi
}

# ------------------------------------------------------------------------------
# 4. メインフロー
# ------------------------------------------------------------------------------
echo "-------------------------------------------------------"
log "INFO" "INIT" "同期開始 (Branch: $BRANCH_NAME)"

# Step 1: Git更新
log "INFO" "GIT" "環境を最新化中..."
if ! phase_git_update; then
    log "ERROR" "GIT" "失敗"
    exit 1
fi
log "SUCCESS" "GIT" "完了"

# Step 2: 差分分析
log "INFO" "DELTA" "変更箇所を特定中..."
if ! phase_analyze_delta; then
    log "ERROR" "DELTA" "失敗"
    exit 1
fi
log "SUCCESS" "DELTA" "完了"

# Step 3: ダウンロード
log "INFO" "RETRIEVE" "リソースを取得中..."
if ! phase_retrieve_metadata; then
    log "ERROR" "RETRIEVE" "失敗"
    exit 1
fi
log "SUCCESS" "RETRIEVE" "完了"

# Step 4: 後片付け
log "INFO" "CLEAN" "作業ディレクトリを削除中..."
if ! phase_cleanup_temp; then
    log "ERROR" "CLEAN" "失敗"
    exit 1
fi
log "SUCCESS" "CLEAN" "完了"

# Step 5: Git同期
log "INFO" "SYNC" "Gitリポジトリを更新中..."
phase_git_sync
RES=$?

if [ $RES -eq 0 ]; then
    log "SUCCESS" "SYNC" "完了"
elif [ $RES -eq 2 ]; then
    log "INFO" "SYNC" "変更はありませんでした"
    log "SUCCESS" "SYNC" "完了"
else
    log "ERROR" "SYNC" "失敗"
    exit 1
fi

log "SUCCESS" "FINISH" "すべての工程が完了しました"
echo "-------------------------------------------------------"
exit 0