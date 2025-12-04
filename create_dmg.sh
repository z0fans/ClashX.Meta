#!/bin/bash

# ClashX Meta DMG 打包脚本
# 用法: ./create_dmg.sh

set -e

# 配置变量
APP_NAME="ClashX Meta"
APP_PATH="archive/ClashX.xcarchive/Products/Applications/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
TEMP_DMG_NAME="temp.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_BACKGROUND="dmg_background.png"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
echo "创建临时目录: ${TEMP_DIR}"

# 清理函数
cleanup() {
    echo "清理临时文件..."
    rm -rf "${TEMP_DIR}"
    rm -f "${TEMP_DMG_NAME}"
}
trap cleanup EXIT

# 检查应用是否存在
if [ ! -d "${APP_PATH}" ]; then
    echo "错误: 找不到应用程序 ${APP_PATH}"
    exit 1
fi

# 复制应用到临时目录
echo "复制应用到临时目录..."
cp -R "${APP_PATH}" "${TEMP_DIR}/"

# 创建 Applications 文件夹的软链接
echo "创建 Applications 链接..."
ln -s /Applications "${TEMP_DIR}/Applications"

# 如果存在背景图,复制到临时目录
if [ -f "${DMG_BACKGROUND}" ]; then
    mkdir -p "${TEMP_DIR}/.background"
    cp "${DMG_BACKGROUND}" "${TEMP_DIR}/.background/"
fi

# 计算需要的磁盘空间(应用大小 + 50MB 缓冲)
APP_SIZE=$(du -sm "${APP_PATH}" | awk '{print $1}')
DMG_SIZE=$((APP_SIZE + 50))
echo "DMG 大小: ${DMG_SIZE}MB"

# 创建临时 DMG
echo "创建临时 DMG..."
hdiutil create -srcfolder "${TEMP_DIR}" \
    -volname "${VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${DMG_SIZE}m \
    "${TEMP_DMG_NAME}"

# 挂载临时 DMG
echo "挂载 DMG..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG_NAME}" | grep Volumes | awk '{print $3}')

if [ -z "${MOUNT_DIR}" ]; then
    echo "错误: 无法挂载 DMG"
    exit 1
fi

echo "DMG 已挂载到: ${MOUNT_DIR}"

# 设置 DMG 窗口属性
echo "配置 DMG 窗口..."
cat > /tmp/dmg_setup.applescript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 450}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set background picture of viewOptions to file ".background:${DMG_BACKGROUND}"

        -- 设置图标位置
        set position of item "${APP_NAME}.app" of container window to {125, 180}
        set position of item "Applications" of container window to {375, 180}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# 执行 AppleScript (如果背景图存在)
if [ -f "${DMG_BACKGROUND}" ]; then
    osascript /tmp/dmg_setup.applescript || true
else
    # 简化版布局(无背景图)
    cat > /tmp/dmg_setup_simple.applescript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 450}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100

        -- 设置图标位置
        set position of item "${APP_NAME}.app" of container window to {125, 180}
        set position of item "Applications" of container window to {375, 180}

        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF
    osascript /tmp/dmg_setup_simple.applescript || true
fi

# 设置权限
chmod -Rf go-w "${MOUNT_DIR}" || true

# 同步并卸载
sync
echo "卸载 DMG..."
hdiutil detach "${MOUNT_DIR}" -quiet || {
    echo "尝试强制卸载..."
    hdiutil detach "${MOUNT_DIR}" -force
}

# 转换为压缩的只读 DMG
echo "压缩 DMG..."
rm -f "${DMG_NAME}"
hdiutil convert "${TEMP_DMG_NAME}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_NAME}"

# 验证 DMG
echo "验证 DMG..."
hdiutil verify "${DMG_NAME}"

echo "✅ DMG 创建完成: ${DMG_NAME}"
ls -lh "${DMG_NAME}"
