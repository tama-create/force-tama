#!/bin/bash

# ==============================================================================
# sf-install.sh - sf-tools をホームディレクトリにインストール（または最新化）する
# ==============================================================================

if [[ ! "$(basename "$PWD")" =~ ^force- ]]; then
    echo "[ERROR] このスクリプトは 'force-*' ディレクトリ内で実行してください。" >&2
    exit 1
fi

readonly TARGET_DIR="$HOME/sf-tools"
readonly REPO_URL="https://github.com/tamashimon-create/sf-tools.git"

echo "sf-tools のセットアップを開始します..."

if [ -d "$TARGET_DIR" ]; then
    echo "既存のディレクトリを最新化します..."
    cd "$TARGET_DIR" || exit 1
    BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
    git pull origin "$BRANCH" || { echo "[ERROR] 最新化に失敗しました。" >&2; exit 1; }
else
    echo "sf-tools をクローンします..."
    git clone -b main "$REPO_URL" "$TARGET_DIR" || { echo "[ERROR] クローンに失敗しました。" >&2; exit 1; }
fi

echo "完了しました。"
