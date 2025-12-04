#!/bin/bash

# ClashX Meta DMG 打包脚本
# 使用 create-dmg 工具 (https://github.com/create-dmg/create-dmg)
# 用法: ./create_dmg.sh

set -e

# 配置变量
APP_NAME="ClashX Meta"
APP_PATH="archive/ClashX.xcarchive/Products/Applications/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_BACKGROUND="dmg_background.png"

echo "========================================"
echo "ClashX Meta DMG 打包工具"
echo "========================================"

# 检查应用是否存在
if [ ! -d "${APP_PATH}" ]; then
    echo "❌ 错误: 找不到应用程序 ${APP_PATH}"
    exit 1
fi

echo "✓ 找到应用程序: ${APP_PATH}"

# 检查并安装 create-dmg
if ! command -v create-dmg &> /dev/null; then
    echo "📦 create-dmg 未安装,正在通过 Homebrew 安装..."
    if command -v brew &> /dev/null; then
        brew install create-dmg
    else
        echo "❌ 错误: 未找到 Homebrew,请先安装 create-dmg"
        echo "安装方法: brew install create-dmg"
        echo "或访问: https://github.com/create-dmg/create-dmg"
        exit 1
    fi
fi

echo "✓ create-dmg 工具已就绪"

# 删除旧的 DMG(如果存在)
if [ -f "${DMG_NAME}" ]; then
    echo "🗑️  删除旧的 DMG 文件..."
    rm -f "${DMG_NAME}"
fi

# 构建 create-dmg 参数
echo "🔨 开始创建 DMG..."

CREATE_DMG_OPTIONS=(
    --volname "${VOLUME_NAME}"
    --window-pos 200 120
    --window-size 500 350
    --icon-size 100
    --icon "${APP_NAME}.app" 125 180
    --app-drop-link 375 180
)

# 如果背景图存在,添加背景图参数
if [ -f "${DMG_BACKGROUND}" ]; then
    echo "✓ 找到背景图: ${DMG_BACKGROUND}"
    CREATE_DMG_OPTIONS+=(--background "${DMG_BACKGROUND}")
else
    echo "⚠️  未找到背景图,将使用默认样式"
fi

# 在 CI 环境中跳过 AppleScript 美化
if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
    echo "🤖 检测到 CI 环境,跳过 AppleScript 窗口美化"
    CREATE_DMG_OPTIONS+=(--skip-jenkins)
fi

# 创建临时目录用于打包
TEMP_DIR=$(mktemp -d)
echo "📁 创建临时目录: ${TEMP_DIR}"

# 清理函数
cleanup() {
    echo "🧹 清理临时文件..."
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# 复制应用到临时目录
echo "📋 复制应用到临时目录..."
cp -R "${APP_PATH}" "${TEMP_DIR}/"

# 执行 create-dmg
echo "🚀 执行 create-dmg..."
create-dmg \
    "${CREATE_DMG_OPTIONS[@]}" \
    "${DMG_NAME}" \
    "${TEMP_DIR}" || {
    echo "❌ create-dmg 执行失败"
    exit 1
}

# 验证 DMG 是否创建成功
if [ ! -f "${DMG_NAME}" ]; then
    echo "❌ 错误: DMG 文件未生成"
    exit 1
fi

echo "========================================"
echo "✅ DMG 创建成功!"
echo "文件: ${DMG_NAME}"
ls -lh "${DMG_NAME}"
echo "========================================"
