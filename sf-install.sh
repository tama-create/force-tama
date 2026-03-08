#!/bin/bash

# ==============================================================================
# プログラム名: sf-install.sh
# 概要: ホームディレクトリ(~)配下に sf-tools をクローン、または最新化する
# ==============================================================================

# ------------------------------------------------------------------------------
# 0. 共通の初期処理
# ------------------------------------------------------------------------------
# カラー定義
if [ -t 1 ]; then
    readonly CLR_INFO='\033[36m'
    readonly CLR_SUCCESS='\033[32m'
    readonly CLR_ERR='\033[31m'
    readonly CLR_PROMPT='\033[33m'
    readonly CLR_RESET='\033[0m'
else
    readonly CLR_INFO=''; readonly CLR_SUCCESS=''; readonly CLR_ERR=''; readonly CLR_PROMPT=''; readonly CLR_RESET=''
fi

echo "======================================================="
echo -e "${CLR_INFO}⚙️  共通ツールのインストール・更新を開始します...${CLR_RESET}"
echo "======================================================="

# 実行ディレクトリのバリデーション
CURRENT_DIR_NAME=$(basename "$PWD")
if [[ ! "$CURRENT_DIR_NAME" =~ ^force- ]]; then
    echo -e "${CLR_ERR}❌ エラー: このスクリプトは 'force-*' ディレクトリ内でのみ実行可能です。${CLR_RESET}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. 設定項目
# ------------------------------------------------------------------------------
# ターゲットディレクトリ（ホームディレクトリ直下）
readonly TARGET_DIR="$HOME/sf-tools"

# リポジトリのURL
readonly REPO_URL="https://github.com/tamashimon-create/sf-tools.git"

# 新規クローン時のデフォルトブランチ
readonly DEFAULT_BRANCH="main"

# ------------------------------------------------------------------------------
# 2. 共通エンジン
# ------------------------------------------------------------------------------
log() {
    local level=$1 stage=$2 message=$3
    case "$level" in
        "INFO")    echo -e "${CLR_INFO}▶️  [$stage]${CLR_RESET} $message" ;;
        "SUCCESS") echo -e "${CLR_SUCCESS}✅ [$stage]${CLR_RESET} $message" ;;
        "ERROR")   echo -e "${CLR_ERR}❌ [$stage]${CLR_RESET} $message" >&2 ;;
        "CMD")     echo -e "${CLR_CMD}   > Command:${CLR_RESET} $message" ;;
    esac
}

exec_wrapper() {
    local stage=$1; shift
    local cmd=("$@")
    log "CMD" "$stage" "${cmd[*]}"
    "${cmd[@]}"
    return $?
}

# ------------------------------------------------------------------------------
# 3. メインフロー
# ------------------------------------------------------------------------------
echo "-------------------------------------------------------"
log "INFO" "INIT" "sf-tools のセットアップを開始します"

if [ -d "$TARGET_DIR" ]; then
    # ディレクトリが存在する場合：最新化
    log "INFO" "UPDATE" "既存のディレクトリを検知しました。最新化を実行します。"
    cd "$TARGET_DIR" || { log "ERROR" "UPDATE" "移動失敗"; exit 1; }

    exec_wrapper "UPDATE" git fetch origin
    CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git branch --show-current)
    
    if [ -n "$CURRENT_BRANCH" ]; then
        log "INFO" "UPDATE" "ブランチ (${CURRENT_BRANCH}) を Pull します。"
        if exec_wrapper "UPDATE" git pull origin "$CURRENT_BRANCH"; then
            log "SUCCESS" "UPDATE" "最新化完了"
        else
            log "ERROR" "UPDATE" "最新化に失敗しました"
            exit 1
        fi
    fi
else
    # ディレクトリが存在しない場合：クローン
    log "INFO" "CLONE" "ディレクトリが存在しません。新規クローンを実行します。"
    cd "$HOME" || { log "ERROR" "CLONE" "ホーム移動失敗"; exit 1; }

    if exec_wrapper "CLONE" git clone -b "$DEFAULT_BRANCH" "$REPO_URL" sf-tools; then
        log "SUCCESS" "CLONE" "クローン完了"
    else
        log "ERROR" "CLONE" "クローン失敗"
        exit 1
    fi
fi

echo "-------------------------------------------------------"
log "SUCCESS" "FINISH" "すべてのセットアップ工程が完了しました。"
exit 0