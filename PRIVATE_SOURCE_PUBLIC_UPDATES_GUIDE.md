# ClashX.Meta 私有源码 + 公共更新源方案（保持现有更新逻辑）

本文档用于指导后续将源码仓库改为私有，同时保持用户端 Sparkle 更新正常可用。

---

## 1. 目标

- 源码仓库可设为 private（保护代码）。
- 用户仍可正常收到应用内更新提示并下载新版本。
- 继续沿用当前 Sparkle 机制：`appcast.xml` + DMG + `SUPublicEDKey` 验签。

---

## 2. 当前逻辑（现状）

当前客户端更新依赖：

- `SUFeedURL` 指向 GitHub 公共 raw 地址（`sparkle` 分支）。
- CI 产出 DMG 后更新 `appcast.xml`。
- 客户端通过 Sparkle 拉取 appcast 并提示更新。

风险：

- 一旦源码仓库变为 private，客户端无法匿名读取 appcast 与下载地址，更新链路会中断。

---

## 3. 目标架构（推荐）

采用“双仓/双域”模型：

- **私有仓库**：保存源码并执行构建（例如 `z0fans/ClashX.Meta`）。
- **公共更新源**：仅托管更新元数据与安装包（例如 `z0fans/ClashX.Meta-Updates` 或 GitHub Pages 域名）。

更新流：

1. 私有仓库 CI 构建 `ClashX.dmg`。
2. CI 生成/更新 `appcast.xml`。
3. CI 将 `appcast.xml` + DMG 发布到公共更新源。
4. 客户端使用新的 `SUFeedURL` 正常拉取更新。

---

## 4. 公共更新源选型

可选三种，按维护成本排序：

1. **GitHub Pages（推荐）**
   - 优点：稳定、免费、HTTPS 默认可用。
   - 典型地址：`https://<user>.github.io/<repo>/appcast.xml`

2. **独立公开更新仓库（Releases + raw）**
   - 优点：和源码仓库彻底分离。
   - 注意：需保证 appcast 中 URL 可公网匿名下载。

3. **对象存储（S3/R2/OSS）**
   - 优点：可控性高、可 CDN。
   - 注意：需维护上传凭据、生命周期和权限策略。

---

## 5. 迁移步骤（必须按顺序）

### 阶段 A：准备公共更新源

1. 创建公开仓库（例：`ClashX.Meta-Updates`）或 Pages 站点。
2. 准备目录结构（示例）：

```text
/appcast.xml
/downloads/ClashX.dmg
```

3. 在私有源码仓库 Secrets 中添加发布凭据：
   - `UPDATES_REPO_TOKEN`（可 push 到更新仓库）
   - 若用对象存储，则添加对应 AK/SK。

### 阶段 B：发布“桥接版本”（关键）

先发一个桥接版本，把客户端 `SUFeedURL` 改到公共更新源。

- 修改 `ClashX/Info.plist` 中 `SUFeedURL` 为新公共地址。
- `SUPublicEDKey` 保持不变（继续使用现有签名私钥生成签名）。
- 该版本仍可在当前公开源码仓库发布一次，确保老用户都能升级到新 feed。

### 阶段 C：切换 CI 发布目标

在 `.github/workflows/main.yml` 中，将“更新 sparkle 分支”的步骤改为：

- 发布到公共 updates 仓库/Pages。
- `appcast.xml` 中下载链接改为公共更新源域名。

### 阶段 D：验证后再设源码 private

1. 用桥接版客户端执行“检查更新”。
2. 验证可读取新 `appcast.xml`、可下载 DMG、可完成升级。
3. 验证通过后，再将源码仓库改为 private。

---

## 6. CI 改造建议（最小改动）

保留现有构建与签名步骤，仅替换发布落点：

- 保留：
  - `bash install_dependency.sh`
  - `xcodebuild archive`
  - `create_dmg.sh`
  - Sparkle appcast 生成步骤

- 替换：
  - 由“推送本仓库 sparkle 分支”改为“推送公共更新源”。

建议新增独立 Job：

- `publish_updates` 依赖 `build`
- 输入：`ClashX.dmg`、`appcast.xml`
- 输出：更新仓库 `main` 或 `gh-pages` 分支

---

## 7. 分支与产品隔离规则（你当前策略）

- `main`：主线产品，允许自动更新。
- `compat-10.14`：独立兼容产品，不与 `main` 更新源互通。
- 严禁复用同一 `SUFeedURL`（避免互相串更）。

建议：

- `main` 使用 `https://updates-main.example.com/appcast.xml`
- `compat-10.14` 若未来需要更新，使用独立 `appcast-legacy.xml` 或完全禁用更新。

---

## 8. 发布前检查清单（每次发版）

1. 当前分支是否为 `main`。
2. `Info.plist` 的 `SUFeedURL` 是否指向公共更新源。
3. `SUPublicEDKey` 与签名私钥是否匹配。
4. CI Secrets 是否有效。
5. `appcast.xml` 下载 URL 是否可匿名访问。
6. 客户端手动“检查更新”是否命中新版本。

---

## 9. 常见故障与处理

### 问题：用户不弹更新

- 检查 `SUFeedURL` 是否仍指向 private 地址。
- 检查 `appcast.xml` 是否可公网访问（浏览器无登录可打开）。
- 检查 appcast 签名字段与 DMG 是否匹配。

### 问题：能看到版本但下载失败

- 检查 DMG URL 是否 403/404。
- 检查文件名是否与 appcast 条目一致。

### 问题：升级后签名校验失败

- 检查 `SUPublicEDKey` 与使用的私钥是否同一对。

---

## 10. 推荐实施节奏

1. 本周：搭建公共 updates 仓库 + 改 CI（不切 private）。
2. 下周：发布桥接版本并观察 3~7 天。
3. 稳定后：源码仓库改为 private。

---

## 11. 一句话结论

你可以把源码仓库设为 private，但必须先把 Sparkle 的 `appcast.xml` 和安装包迁移到公开更新源；只要这一步完成，用户更新体验不会变。
