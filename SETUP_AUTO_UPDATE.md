# 🔄 配置自动更新完整指南

按照以下步骤配置 Sparkle 自动更新系统，让用户可以从您的仓库自动更新应用。

---

## 步骤 1: 安装 Sparkle 工具

```bash
brew install sparkle
```

---

## 步骤 2: 生成密钥对

在终端执行以下命令：

```bash
$(brew --prefix)/Caskroom/sparkle/2.*/bin/generate_keys
```

**输出示例**：
```
A key has been generated and saved in your keychain.

Public EdDSA key (SUPublicEDKey):
Jhu0RI5Vp02om6JhxYnFewD82GCV8v7U05toMFXb+7U=

Private EdDSA key (to sign updates):
-----BEGIN PRIVATE KEY-----
MFMCAQEwBQYDK2VwBCIEIN5nPHqxQmLBNYgKK0zzIQwt4q0rlvDKpWF9YxMU1wUr
oaAwHgYDK2VwAyEAJhu0RI5Vp02om6JhxYnFewD82GCV8v7U05toMFXb+7U=
-----END PRIVATE KEY-----

Please keep your private key in a safe place; never publish it!
```

⚠️ **重要**：
- **公钥**：用于应用验证更新签名（公开，写入 Info.plist）
- **私钥**：用于签名更新包（保密，保存到 GitHub Secrets）

---

## 步骤 3: 配置公钥到应用

**手动操作**：

1. 复制上面生成的公钥（如：`Jhu0RI5Vp02om6JhxYnFewD82GCV8v7U05toMFXb+7U=`）
2. 打开 `ClashX/Info.plist`
3. 找到第 134 行的 `SUPublicEDKey`
4. 将 `YOUR_PUBLIC_KEY_HERE` 替换为您的公钥

**或者告诉我您的公钥，我帮您修改**

---

## 步骤 4: 保存私钥到 GitHub Secrets

1. 复制生成的**完整私钥**（包括 `-----BEGIN PRIVATE KEY-----` 和 `-----END PRIVATE KEY-----`）

2. 前往您的 GitHub 仓库：
   ```
   https://github.com/z0fans/ClashX.Meta/settings/secrets/actions
   ```

3. 点击 **New repository secret**

4. 填写信息：
   - **Name**: `ED_KEY`
   - **Secret**: 粘贴完整的私钥内容

5. 点击 **Add secret**

---

## 步骤 5: 创建 sparkle 分支

在当前项目目录执行：

```bash
# 创建并切换到新的 sparkle 分支
git checkout --orphan sparkle

# 清空所有文件
git rm -rf .

# 创建初始文件
echo "# Sparkle Updates Repository

This branch stores Sparkle auto-update metadata and release archives.

**DO NOT MANUALLY EDIT** - This branch is automatically maintained by GitHub Actions.
" > README.md

# 创建 .gitignore
echo "*.delta
old_updates/
" > .gitignore

# 提交并推送
git add README.md .gitignore
git commit -m "Initialize sparkle branch for auto-updates"
git push origin sparkle

# 切回 main 分支
git checkout main
```

---

## 步骤 6: 启用工作流中的 Sparkle 步骤

编辑 `.github/workflows/main.yml`，取消注释第 72-107 行。

**我可以帮您自动完成这一步，您确认后我会修改并提交。**

---

## 步骤 7: 测试更新流程

### 7.1 推送一个测试 tag

```bash
# 确保所有修改已提交
git add .
git commit -m "chore: 配置 Sparkle 自动更新"
git push origin main

# 创建并推送 tag
git tag v1.4.30
git push origin v1.4.30
```

### 7.2 检查 GitHub Actions

前往：https://github.com/z0fans/ClashX.Meta/actions

应该能看到：
- ✅ 构建成功
- ✅ 创建了 GitHub Release
- ✅ 上传了 `ClashX Meta.zip`
- ✅ sparkle 分支被更新
- ✅ 生成了 `appcast.xml`

### 7.3 验证 appcast.xml

访问：
```
https://raw.githubusercontent.com/z0fans/ClashX.Meta/refs/heads/sparkle/appcast.xml
```

应该能看到类似内容：
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <item>
            <title>v1.4.30</title>
            <link>https://github.com/z0fans/ClashX.Meta/releases/tag/v1.4.30</link>
            <sparkle:version>v1.4.30</sparkle:version>
            <enclosure url="..." sparkle:edSignature="..." />
        </item>
    </channel>
</rss>
```

---

## 工作原理

```
┌─────────────┐
│  推送 Tag   │ (v1.4.30)
└──────┬──────┘
       │
       v
┌─────────────────────┐
│  GitHub Actions     │
│  触发构建           │
└──────┬──────────────┘
       │
       ├─→ 构建应用 (.app)
       ├─→ 打包 ZIP
       ├─→ 使用私钥签名
       ├─→ 上传到 GitHub Release
       └─→ 更新 sparkle 分支的 appcast.xml
           │
           v
    ┌───────────────────┐
    │  用户打开应用     │
    └─────┬─────────────┘
          │
          v
    检查更新 (读取 appcast.xml)
          │
          v
    使用公钥验证签名
          │
          v
    提示用户下载更新
```

---

## 当前进度检查表

- [x] 修改更新源 URL 为您的仓库
- [ ] 生成 Sparkle 密钥对
- [ ] 配置公钥到 Info.plist
- [ ] 保存私钥到 GitHub Secrets
- [ ] 创建 sparkle 分支
- [ ] 启用工作流 Sparkle 步骤
- [ ] 推送 tag 测试

---

## 下一步

**请您先执行步骤 2（生成密钥对），然后告诉我生成的公钥，我会帮您完成后续配置。**

执行命令：
```bash
$(brew --prefix)/Caskroom/sparkle/2.*/bin/generate_keys
```

生成后，将**公钥**（Public EdDSA key）告诉我即可。
