# ClashX Meta DMG 模板使用指南

## 概述

使用 `.DS_Store` 预配置文件来创建具有完美布局的 DMG，无需 AppleScript，完全兼容 CI 环境。

## 工作原理

1. **本地创建模板**: 在你的 Mac 上手动调整 DMG 布局，生成 `.DS_Store` 文件
2. **提交到仓库**: 将 `.DS_Store` 文件提交到 Git
3. **CI 自动使用**: GitHub Actions 构建时直接应用这个布局配置

## 使用步骤

### 第一步：创建 DMG 模板（只需执行一次）

```bash
# 1. 先构建应用（如果还没构建）
xcodebuild archive -project ClashX.xcodeproj \
  -scheme "ClashX Meta" \
  -archivePath archive/ClashX.xcarchive \
  -allowProvisioningUpdates

# 2. 运行模板生成脚本
./create_dmg_template.sh
```

### 第二步：手动调整布局

脚本会自动打开 Finder 窗口，请按以下步骤操作：

1. **调整窗口大小**
   - 拖动窗口角落调整到合适大小（建议 500x350）

2. **打开视图选项**
   - 按 `Cmd + J` 或选择「查看 > 显示视图选项」

3. **配置图标显示**
   - 图标大小：100-128 像素
   - 网格间距：根据喜好调整
   - 文本大小：12-14

4. **拖动图标到合适位置**
   - 将 `ClashX Meta.app` 拖到左侧（约 x=125）
   - 将 `Applications` 拖到右侧（约 x=375）

5. **（可选）设置背景**
   - 在视图选项中选择「背景」
   - 可以选择纯色或拖入图片

6. **关闭窗口**
   - 关闭 Finder 窗口
   - 回到终端按回车继续

### 第三步：验证生成的文件

```bash
# 检查生成的文件
ls -la dmg_template/

# 应该看到:
# dmg_template/
#   DS_Store              <- 布局配置文件
#   .background/          <- 背景图（如果设置了）
#     background.png
```

### 第四步：提交到仓库

```bash
# 添加到 Git
git add dmg_template/
git add create_dmg_with_template.sh
git commit -m "feat: 添加 DMG 布局模板配置"
git push
```

### 第五步：更新 CI 脚本

修改 `.github/workflows/main.yml`，将：
```yaml
- name: create dmg
  run: bash create_dmg.sh
```

改为：
```yaml
- name: create dmg
  run: bash create_dmg_with_template.sh
```

## 本地测试

```bash
# 使用模板创建 DMG
./create_dmg_with_template.sh

# 打开验证效果
open "ClashX Meta.dmg"
```

## 重新调整布局

如果需要修改布局：

```bash
# 重新运行模板生成脚本
./create_dmg_template.sh

# 调整布局后，提交新的 DS_Store
git add dmg_template/DS_Store
git commit -m "update: 调整 DMG 布局"
git push
```

## 常见问题

### Q: 为什么不直接使用 create-dmg 的 AppleScript？
A: GitHub Actions 的 macOS runner 不支持 AppleScript，会导致构建失败。

### Q: .DS_Store 文件没有生成怎么办？
A:
1. 确保在 Finder 中打开了文件夹
2. 尝试调整一下图标位置
3. 关闭窗口等待几秒
4. 重新运行脚本

### Q: 如何显示隐藏文件查看 .DS_Store？
A: 在 Finder 中按 `Cmd + Shift + .`

### Q: CI 构建时找不到模板怎么办？
A: 确保 `dmg_template/` 目录已提交到 Git 仓库

## 参考资源

- [VS Code DMG 构建脚本](https://github.com/microsoft/vscode/blob/main/build/darwin/create-dmg.sh)
- [Atom DMG 构建方案](https://github.com/atom/atom/blob/master/script/build-dmg.sh)
