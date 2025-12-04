# ✅ Sparkle 自动更新配置进度

## 已完成 ✅

1. ✅ 生成 Sparkle 密钥对
   - 公钥：`zUo6br6+dUWuN1oUWUYq4GNzl8DiEJKOMkMVCfFlR4M=`
   - 私钥：已保存在您的 macOS 钥匙串

2. ✅ 配置公钥到 `ClashX/Info.plist`

3. ✅ 更新源地址已修改为您的仓库：
   ```
   https://raw.githubusercontent.com/z0fans/ClashX.Meta/refs/heads/sparkle/appcast.xml
   ```

4. ✅ 启用工作流中的 Sparkle 步骤

## 待完成任务 📋

### 任务 1: 获取并保存私钥到 GitHub Secrets

**步骤 1 - 从钥匙串导出私钥**：

在终端执行：
```bash
security find-generic-password -s "Sparkle EdDSA Private Key" -w
```

这会输出类似这样的内容：
```
-----BEGIN PRIVATE KEY-----
MFMCAQEwBQYDK2VwBCIEIN5nPHqxQmLBNYgKK0zzIQwt4q...
-----END PRIVATE KEY-----
```

**步骤 2 - 保存到 GitHub Secrets**：

1. 复制完整的私钥内容（包括 BEGIN 和 END 行）

2. 前往：https://github.com/z0fans/ClashX.Meta/settings/secrets/actions

3. 点击 **New repository secret**

4. 填写：
   - Name: `ED_KEY`
   - Secret: 粘贴私钥内容

5. 点击 **Add secret**

---

### 任务 2: 创建 sparkle 分支

在当前项目目录执行：

```bash
# 创建并切换到新的 sparkle 分支
git checkout --orphan sparkle

# 清空所有文件
git rm -rf .

# 创建初始文件
cat > README.md << 'EOF'
# Sparkle Updates Repository

This branch stores Sparkle auto-update metadata and release archives.

**DO NOT MANUALLY EDIT** - This branch is automatically maintained by GitHub Actions.
EOF

# 创建 .gitignore
cat > .gitignore << 'EOF'
*.delta
old_updates/
EOF

# 提交并推送
git add README.md .gitignore
git commit -m "Initialize sparkle branch for auto-updates"
git push origin sparkle

# 切回 main 分支
git checkout main
```

---

### 任务 3: 提交并推送当前修改

```bash
# 查看修改
git status

# 添加文件
git add ClashX/Info.plist .github/workflows/main.yml SETUP_AUTO_UPDATE.md NEXT_STEPS.md

# 提交
git commit -m "feat: 配置 Sparkle 自动更新系统

- 添加 Sparkle 公钥到 Info.plist
- 更新源地址指向自己的仓库
- 启用工作流 Sparkle 步骤
- 添加配置文档"

# 推送
git push origin main
```

---

### 任务 4: 测试自动更新

**推送一个 tag 触发构建**：

```bash
# 创建 tag
git tag v1.4.30

# 推送 tag（这会触发 GitHub Actions）
git push origin v1.4.30
```

**GitHub Actions 会自动执行**：
1. ✅ 构建应用
2. ✅ 创建 ZIP 包
3. ✅ 使用私钥签名
4. ✅ 创建 GitHub Release
5. ✅ 上传到 Release
6. ✅ 更新 sparkle 分支的 appcast.xml

**验证结果**：

1. 检查 GitHub Actions：https://github.com/z0fans/ClashX.Meta/actions
2. 检查 Release：https://github.com/z0fans/ClashX.Meta/releases
3. 检查 appcast.xml：
   ```
   https://raw.githubusercontent.com/z0fans/ClashX.Meta/refs/heads/sparkle/appcast.xml
   ```

---

## 快速执行清单

```bash
# 1. 导出私钥（复制输出，保存到 GitHub Secrets）
security find-generic-password -s "Sparkle EdDSA Private Key" -w

# 2. 创建 sparkle 分支
git checkout --orphan sparkle
git rm -rf .
echo "# Sparkle Updates" > README.md
echo "*.delta" > .gitignore
git add .
git commit -m "Initialize sparkle branch"
git push origin sparkle
git checkout main

# 3. 提交当前修改
git add ClashX/Info.plist .github/workflows/main.yml SETUP_AUTO_UPDATE.md NEXT_STEPS.md
git commit -m "feat: 配置 Sparkle 自动更新系统"
git push origin main

# 4. 测试
git tag v1.4.30
git push origin v1.4.30
```

---

## 密钥信息（重要！）

**公钥**（已配置到应用）：
```
zUo6br6+dUWuN1oUWUYq4GNzl8DiEJKOMkMVCfFlR4M=
```

**私钥位置**：
- macOS 钥匙串：`Sparkle EdDSA Private Key`
- 需要保存到 GitHub Secrets（名称：`ED_KEY`）

⚠️ **警告**：私钥必须保密！不要提交到 Git 仓库或公开分享。

---

**配置完成时间**: 2025-12-04
**配置者**: Claude Code
