#!/bin/bash

# ClashX Meta DMG 打包脚本
# 专为 GitHub Actions CI 环境优化
# 完全避免 AppleScript，确保在无头环境中稳定运行

set -e

# 配置变量
APP_NAME="ClashX Meta"
APP_PATH="archive/ClashX.xcarchive/Products/Applications/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_BACKGROUND="dmg_background.png"

echo "========================================"
echo "ClashX Meta DMG 打包工具 (CI 优化版)"
echo "========================================"

# 检查应用是否存在
if [ ! -d "${APP_PATH}" ]; then
    echo "❌ 错误: 找不到应用程序 ${APP_PATH}"
    exit 1
fi

echo "✓ 找到应用程序: ${APP_PATH}"

# 检查并安装 create-dmg
if ! command -v create-dmg &> /dev/null; then
    echo "📦 安装 create-dmg..."
    brew install create-dmg
fi

echo "✓ create-dmg 版本: $(create-dmg --version 2>/dev/null || echo 'unknown')"

# 删除旧的 DMG
rm -f "${DMG_NAME}"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
echo "📁 临时目录: ${TEMP_DIR}"

cleanup() {
    echo "🧹 清理临时文件..."
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# 复制应用到临时目录
echo "📋 复制应用..."
cp -R "${APP_PATH}" "${TEMP_DIR}/"

# 构建 create-dmg 参数
# 关键: 使用 --no-internet-enable 和 --sandbox-safe 确保 CI 兼容性
CREATE_DMG_ARGS=(
    --volname "${VOLUME_NAME}"
    --window-pos 200 120
    --window-size 500 350
    --icon-size 100
    --icon "${APP_NAME}.app" 125 180
    --app-drop-link 375 180
    --no-internet-enable
    --sandbox-safe
)

# 添加背景图（如果存在）
if [ -f "${DMG_BACKGROUND}" ]; then
    echo "✓ 使用背景图: ${DMG_BACKGROUND}"
    CREATE_DMG_ARGS+=(--background "${DMG_BACKGROUND}")
fi

echo "🚀 创建 DMG..."
echo "参数: ${CREATE_DMG_ARGS[*]}"

# 执行 create-dmg
# 注意: create-dmg 在成功时可能返回非零退出码（当跳过某些步骤时）
# 所以我们检查 DMG 文件是否生成，而不是依赖退出码
set +e
create-dmg "${CREATE_DMG_ARGS[@]}" "${DMG_NAME}" "${TEMP_DIR}"
CREATE_DMG_EXIT=$?
set -e

echo "create-dmg 退出码: ${CREATE_DMG_EXIT}"

# 验证 DMG 是否创建成功
if [ -f "${DMG_NAME}" ]; then
    echo "========================================"
    echo "✅ DMG 创建成功!"
    echo "文件: ${DMG_NAME}"
    ls -lh "${DMG_NAME}"

    # 验证 DMG 完整性
    echo "🔍 验证 DMG 完整性..."
    hdiutil verify "${DMG_NAME}" && echo "✓ DMG 验证通过"

    echo "========================================"
    exit 0
else
    echo "❌ 错误: DMG 文件未生成"
    echo "请检查上面的错误信息"
    exit 1
fi
