# 🔐 保存私钥到 GitHub Secrets

## 私钥文件位置

✅ 私钥已导出到：`/tmp/sparkle_private_key.pem`

## 操作步骤

### 步骤 1：复制私钥到剪贴板

在终端执行：

```bash
cat /tmp/sparkle_private_key.pem | pbcopy
```

这会将私钥内容复制到剪贴板（不会显示在屏幕上）。

### 步骤 2：在 GitHub 添加 Secret

1. 打开浏览器访问：
   ```
   https://github.com/z0fans/ClashX.Meta/settings/secrets/actions
   ```

2. 点击 **New repository secret** 按钮

3. 填写表单：
   - **Name**: `ED_KEY`
   - **Secret**: 按 `Command+V` 粘贴私钥

4. 点击 **Add secret** 保存

### 步骤 3：删除临时文件

完成后，删除临时私钥文件：

```bash
rm -f /tmp/sparkle_private_key.pem
```

## 配置摘要

**公钥**（已配置或需要配置到 `ClashX/Info.plist`）：
```
zUo6br6+dUWuN1oUWUYq4GNzl8DiEJKOMkMVCfFlR4M=
```

**更新源 URL**（需要配置到 `ClashX/Info.plist`）：
```
https://raw.githubusercontent.com/z0fans/ClashX.Meta/refs/heads/sparkle/appcast.xml
```

## 下一步

完成私钥配置后，您需要：

1. ✅ sparkle 分支已创建
2. ⏳ 修改 `ClashX/Info.plist`：
   - 更新 `SUFeedURL` 为您的仓库地址
   - 更新 `SUPublicEDKey` 为您的公钥
3. ⏳ 启用 `.github/workflows/main.yml` 中的 Sparkle 步骤
4. ⏳ 提交并推送修改
5. ⏳ 推送 tag 测试自动更新

---

**重要提醒**：
- ⚠️ 私钥必须保密，不要分享或提交到代码仓库
- ⚠️ 只有配置了正确的私钥，签名验证才能通过
- ⚠️ 公钥和私钥必须配对使用

---

**创建时间**: 2025-12-04
