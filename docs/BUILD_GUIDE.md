# ClashX Meta 构建指南

## 🚀 快速开始

### 一键构建

```bash
make build
```

这会自动完成:
1. ✅ 清理旧的构建产物
2. ✅ 构建并归档应用
3. ✅ 创建 DMG 安装包
4. ✅ 打包调试符号
5. ✅ 打开输出目录

---

## 📦 构建方式

### 方式一: 使用 Makefile (推荐)

```bash
# 查看所有可用命令
make help

# 完整构建 (推荐)
make build

# 仅构建应用 (不打包 DMG)
make build-only

# 仅创建 DMG (应用已构建)
make dmg-only

# 清理构建产物
make clean

# 检查依赖项
make check-deps
```

### 方式二: 手动执行脚本

```bash
# 1. 安装依赖
bash install_dependency.sh

# 2. 构建应用
xcodebuild archive -project ClashX.xcodeproj \
    -scheme "ClashX Meta" \
    -archivePath archive/ClashX.xcarchive \
    -allowProvisioningUpdates

# 3. 导出应用
xcodebuild -exportArchive \
    -exportOptionsPlist exportOptions.plist \
    -archivePath archive/ClashX.xcarchive \
    -exportPath archive

# 4. 创建 DMG
bash create_dmg.sh
```

---

## 🎨 DMG 设计

### 当前配置 (基于 Stats 项目)

- **窗口尺寸**: 500 x 320
- **背景图**: 1000 x 600 @144 DPI
- **图标大小**: 80px
- **布局**: 经典的拖拽式安装界面

### 预览布局

```
┌─────────────────────────────────────┐
│  ClashX Meta                         │
├─────────────────────────────────────┤
│                                      │
│   [应用图标]  ────➜────  [Apps]     │
│    125,175              375,175      │
│                                      │
│   拖动到 Applications 以安装         │
│                                      │
└─────────────────────────────────────┘
```

---

## 🔧 自定义背景图

如果你想自定义 DMG 背景图:

```bash
# 1. 创建 1000x600 的 PNG 图片
#    - 推荐 DPI: 144
#    - 推荐格式: PNG
#    - 参考: stats_background_original.png

# 2. 保存为 dmg_background_new.png

# 3. 重新构建
make dmg-only
```

---

## 📁 输出文件

构建完成后会生成:

```
ClashX Meta.dmg      # DMG 安装包
dSYMs.zip            # 调试符号
archive/             # 构建归档
```

---

## 🔐 代码签名 (可选)

如果需要分发给其他用户,需要签名和公证:

```bash
# 查看签名指南
make sign

# 手动执行签名和公证
xcrun notarytool submit "ClashX Meta.dmg" \
    --keychain-profile "AC_PASSWORD" --wait

xcrun stapler staple "ClashX Meta.dmg"
```

---

## 🛠️ 依赖项

### 必需
- Xcode (已安装命令行工具)
- Git

### 可选
- Homebrew (用于安装额外工具)

检查依赖:
```bash
make check-deps
```

---

## 📚 更多信息

- **完整迁移指南**: 查看 `STATS_MIGRATION_GUIDE.md`
- **DMG 模板方案**: 查看 `DMG_TEMPLATE_GUIDE.md`
- **原项目文档**: 查看 `CLAUDE.md`

---

## ❓ 常见问题

### Q: 构建失败怎么办?

```bash
# 1. 清理后重试
make clean
make build

# 2. 检查依赖
make check-deps

# 3. 查看详细日志
make build 2>&1 | tee build.log
```

### Q: DMG 无法打开?

```bash
# 验证 DMG 完整性
hdiutil verify "ClashX Meta.dmg"
```

### Q: 如何修改窗口大小?

编辑 `create_dmg.sh`:
```bash
--window-size 500 320  # 修改为你想要的尺寸
```

---

## 🎉 享受构建!

有问题? 查看 [STATS_MIGRATION_GUIDE.md](STATS_MIGRATION_GUIDE.md) 获取更多信息。
