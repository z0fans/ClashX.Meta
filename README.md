# Sparkle Updates Repository

This branch stores Sparkle auto-update metadata and release archives.

**DO NOT MANUALLY EDIT** - This branch is automatically maintained by GitHub Actions.

## 内容说明

- `appcast.xml` - Sparkle 更新订阅源文件
- `ClashX Meta v*.zip` - 各版本的应用归档
- `*.delta` - 增量更新文件（如果启用）

## 工作原理

当推送新的 tag 时，GitHub Actions 会：
1. 构建应用
2. 签名并打包
3. 更新此分支的 appcast.xml
4. 上传新版本文件

应用会从以下地址检查更新：
https://raw.githubusercontent.com/z0fans/ClashX.Meta/refs/heads/sparkle/appcast.xml
