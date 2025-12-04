#!/bin/bash

# ClashX Meta DMG 打包脚本
# 移植自 Stats 项目的打包方案 (https://github.com/exelban/stats)
# 使用 create-dmg 工具创建精美的 DMG 安装包

set -e

# 配置变量 (与 Stats 保持一致的设计)
APP_NAME="ClashX Meta"
APP_PATH="archive/ClashX.xcarchive/Products/Applications/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_BACKGROUND="dmg_background.png"

echo "========================================"
echo "ClashX Meta DMG 打包工具"
echo "基于 Stats 项目的打包方案"
echo "========================================"

# 检查应用是否存在
if [ ! -d "${APP_PATH}" ]; then
    echo "❌ 错误: 找不到应用程序 ${APP_PATH}"
    exit 1
fi

echo "✓ 找到应用程序: ${APP_PATH}"

# 检查背景图
if [ ! -f "${DMG_BACKGROUND}" ]; then
    echo "⚠️  警告: 未找到背景图 ${DMG_BACKGROUND}"
    echo "将使用无背景模式"
    DMG_BACKGROUND=""
else
    echo "✓ 找到背景图: ${DMG_BACKGROUND}"
fi

# 克隆 create-dmg 工具 (与 Stats 完全一致的方式)
if [ ! -d $(PWD)/create-dmg ]; then
    echo "📦 克隆 create-dmg 工具..."
    git clone https://github.com/create-dmg/create-dmg
fi

echo "✓ create-dmg 工具已就绪"

# 删除旧的 DMG
rm -f "${DMG_NAME}"

# 使用 Stats 的参数配置创建 DMG
echo "🚀 创建 DMG..."
echo ""
echo "📐 窗口配置:"
echo "  - 尺寸: 500x320"
echo "  - 位置: 200,120"
echo "  - 图标大小: 80"
echo "  - 应用图标位置: 125,175"
echo "  - Applications 链接位置: 375,175"
echo ""

# 构建参数数组
CREATE_DMG_ARGS=(
    --volname "${VOLUME_NAME}"
    --window-pos 200 120
    --window-size 500 320
    --icon-size 80
    --icon "${APP_NAME}.app" 125 175
    --hide-extension "${APP_NAME}.app"
    --app-drop-link 375 175
    --no-internet-enable
)

# 添加背景图参数 (如果存在)
if [ -n "${DMG_BACKGROUND}" ]; then
    CREATE_DMG_ARGS+=(--background "${DMG_BACKGROUND}")
fi

# 执行 create-dmg
# 注意: create-dmg 可能会返回非零退出码,但只要 DMG 生成就算成功
set +e
./create-dmg/create-dmg \
    "${CREATE_DMG_ARGS[@]}" \
    "${DMG_NAME}" \
    "${APP_PATH}"
CREATE_DMG_EXIT=$?
set -e

echo ""
echo "create-dmg 退出码: ${CREATE_DMG_EXIT}"

# 清理 create-dmg 工具目录
echo "🧹 清理临时文件..."
rm -rf ./create-dmg

# 验证 DMG 是否创建成功
if [ -f "${DMG_NAME}" ]; then
    echo ""
    echo "========================================"
    echo "✅ DMG 创建成功!"
    echo "========================================"
    echo "文件: ${DMG_NAME}"
    ls -lh "${DMG_NAME}"

    # 验证 DMG 完整性
    echo ""
    echo "🔍 验证 DMG 完整性..."
    if hdiutil verify "${DMG_NAME}" 2>&1 | grep -q "passed"; then
        echo "✓ DMG 验证通过"
    else
        echo "⚠️  DMG 验证有警告,但文件可能仍然可用"
    fi

    echo ""
    echo "========================================"
    echo "📦 打包配置 (基于 Stats 方案):"
    echo "========================================"
    echo "  窗口尺寸: 500x320"
    echo "  背景图: 1000x600 @144 DPI"
    echo "  图标大小: 80px"
    echo "  布局: Stats 经典风格"
    echo "========================================"
    exit 0
else
    echo ""
    echo "========================================"
    echo "❌ 错误: DMG 文件未生成"
    echo "========================================"
    echo "请检查上面的错误信息"
    exit 1
fi
