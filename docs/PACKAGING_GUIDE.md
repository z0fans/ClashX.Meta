# ClashX.Meta 打包与发布指南（main / compat 分离）

本文档用于指导后续发布，确保：
- `main` 正常触发自动打包与应用内更新。
- `compat-10.14` 保持独立，不影响 `main` 的更新链路。

## 1. 发布策略总览

- `main`：正式主线，使用 `v*` 标签触发 GitHub Actions 自动打包与发布。
- `compat-10.14`：旧系统兼容线，视为独立软件，不参与 `main` 的自动更新链路。

当前工作流触发条件见 `.github/workflows/main.yml`：
- `push.tags: [ v* ]`
- `workflow_dispatch`

## 2. main 分支发布（触发自动更新）

### 2.1 发布前检查

在仓库根目录执行：

```bash
git switch main
git pull --ff-only origin main
git status
```

确认：
- 当前分支是 `main`
- 无未提交的业务改动
- 版本变更已完成（代码已准备好）

### 2.2 提交与推送

```bash
git add <changed-files>
git commit -m "<release changes>"
git push origin main
```

### 2.3 打 tag 触发 CI 自动打包

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

示例：

```bash
git tag v1.4.34
git push origin v1.4.34
```

触发后，工作流会自动执行：
- `bash install_dependency.sh`
- `xcodebuild archive ...`
- `create_dmg.sh`
- 更新 `sparkle` 分支 appcast（tag 触发时）
- 创建 GitHub Release（tag 触发时）

## 3. compat-10.14 打包（与 main 更新隔离）

### 3.1 关键原则

- `compat-10.14` 不应影响 `main` 更新链路。
- 避免在 `compat-10.14` 上使用会进入 `v*` 规则的正式更新标签。

### 3.2 推荐做法

优先使用 `workflow_dispatch` 在 `compat-10.14` 分支执行构建（仅产物，不走 tag 发布链路）。

如需打标签，建议使用不会匹配 `v*` 规则的命名（例如 `compat-1.4.34`），避免触发主线自动更新发布流程。

## 4. 发布后验证清单

### 4.1 main

1. 打开的 Action run 是否为新 tag（例如 `v1.4.34`）。
2. Action 最终状态是否 `success`。
3. GitHub Release 是否生成对应 DMG。
4. `sparkle` 分支 appcast 是否更新。
5. 已安装 `main` 客户端是否可收到更新提示。

### 4.2 compat-10.14

1. 构建产物是否可下载。
2. 不应影响 `main` appcast 与主线更新提示。

## 5. 常见失败点

- 本地构建缺少 `ClashX/Resources/com.metacubex.ClashX.ProxyConfigHelper.meta.gz`：
  - 这是依赖脚本生成物，执行 `bash install_dependency.sh` 可恢复。
- 未配置好发布密钥（如 `ED_KEY`）会导致 appcast/自动更新发布失败。

## 6. 快速命令模板

### main 正式发布

```bash
git switch main
git pull --ff-only origin main
git add .
git commit -m "release: <message>"
git push origin main
git tag vX.Y.Z
git push origin vX.Y.Z
```

### compat 独立构建（推荐 workflow_dispatch）

```bash
git switch compat-10.14
git pull --ff-only origin compat-10.14
# 在 GitHub Actions 页面手动运行 workflow_dispatch，并选择 compat-10.14 分支
```
