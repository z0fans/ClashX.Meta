# macOS 10.14 测试指南

## 📦 测试包信息

**文件**: `ClashX Meta.dmg` (49MB)
**构建时间**: 2025-12-31
**分支**: `compat-10.14`
**最新提交**: `b50176f`

---

## ✅ 已完成的修复

### 1. 降级 mihomo 内核
- **原版本**: v1.19.17 (需要 macOS 12.0+) ❌
- **新版本**: v1.17.0 (支持 macOS 10.13+) ✅
- **架构**: Universal Binary (x86_64 + arm64)

### 2. 构建配置修复
- 所有目标的 `MACOSX_DEPLOYMENT_TARGET` 统一设为 `10.14`
- 移除不兼容的依赖:
  - Sparkle 2.7.1
  - KeyboardShortcuts
  - SwiftUI-Introspect

### 3. Gatekeeper 绕过
**在 ClashX 主程序中**:
- `ClashProcess.swift` 的 `unzipMetaCore()` 函数会调用 `removeQuarantine()`
- 解压内核后自动执行 `xattr -d com.apple.quarantine`

**在 PrivilegedHelper 中** (新增):
- `MetaTask.swift` 的 `start()` 方法中,启动内核前:
  1. 移除隔离属性: `xattr -d com.apple.quarantine <core_path>`
  2. 设置执行权限: `chmod +x <core_path>`

### 4. 详细日志
- ClashX 日志前缀: `[CORE]`, `[MD5]`, `[VERIFY]`, `[START]`, `[UNZIP]`, `[QUARANTINE]`
- PrivilegedHelper 日志前缀: `[HELPER]`

---

## 🧪 测试步骤 (macOS 10.14 虚拟机)

### 步骤 1: 清理旧数据
```bash
# 删除旧的内核缓存
rm -rf ~/Library/Application\ Support/com.metacubex.ClashX.meta/.private_core

# 删除旧的配置 (可选)
# rm -rf ~/.config/clash.meta
```

### 步骤 2: 安装新版本
1. 打开 `ClashX Meta.dmg`
2. 拖拽到 Applications 文件夹
3. 如果有旧版本,选择替换

### 步骤 3: 准备查看日志

**打开控制台.app (Console.app)**:
1. 在左侧选择你的 Mac
2. 点击 "开始" 按钮开始捕获日志
3. 在搜索框输入: `HELPER` 或 `ClashX`

**或使用终端**:
```bash
# 实时查看系统日志
log stream --predicate 'process CONTAINS "ClashX" OR process CONTAINS "Helper"' --level debug
```

### 步骤 4: 启动应用
1. 从 Applications 启动 ClashX Meta
2. 观察控制台日志输出

### 步骤 5: 收集日志

#### ClashX 应用日志
```bash
cat ~/Library/Logs/ClashX*/ClashX*.log | tail -200
```

#### PrivilegedHelper 系统日志
```bash
log show --predicate 'process == "com.metacubex.ClashX.ProxyConfigHelper"' --last 5m | grep HELPER
```

#### 内核崩溃日志 (如果有)
```bash
ls -la ~/.config/clash.meta/logs/
cat ~/.config/clash.meta/logs/meta_core_crash_*.log
```

---

## 🔍 预期日志输出

### ✅ 成功的日志应该包含:

**ClashX 主程序**:
```
[CORE] Checking core at: /Users/.../com.metacubex.ClashX.ProxyConfigHelper.meta
[MD5] Starting core validation
[MD5] Core path: ...
[MD5] chmod +x succeeded
[MD5] Expected: 965cf0085348ec785ac6e03540083757
[MD5] Actual:   965cf0085348ec785ac6e03540083757
[MD5] Validation result: SUCCESS
[CORE] Core file exists and MD5 is valid
[VERIFY] Verifying core file: ...
[VERIFY] Core executed successfully
[VERIFY] Output: Mihomo Meta v1.17.0 ...
[CORE] Core version: v1.17.0
[CORE] SUCCESS: Core validation passed
[START] Core path: ...
[START] Calling PrivilegedHelper.startMeta...
[START] PrivilegedHelper response received
[START] SUCCESS: Core started successfully
```

**PrivilegedHelper (系统日志)**:
```
[HELPER] Start called with path: /Users/.../com.metacubex.ClashX.ProxyConfigHelper.meta
[HELPER] Removing quarantine attribute from: ...
[HELPER] xattr exit status: 0
[HELPER] Setting executable permission...
[HELPER] chmod exit status: 0
[HELPER] About to run process...
[HELPER] Process started successfully, PID: 12345
[HELPER] Returning result: {"externalController":"...","secret":"..."}
```

### ❌ 失败的日志可能包含:

**如果 verifyCoreFile 失败**:
```
[VERIFY] ERROR: Failed to execute core: ...
[VERIFY] ERROR: This is likely due to macOS Gatekeeper blocking unsigned/unnotarized executable
```

**如果 PrivilegedHelper 启动失败**:
```
[HELPER] ERROR: Failed to start process: ...
[HELPER] ERROR: Error domain: NSCocoaErrorDomain
[HELPER] ERROR: Error code: 257
[HELPER] Returning result: Start meta error, ...
```

**如果返回空字符串**:
```
[START] Response string: ''
[START] ERROR: Response is empty string
[START] ERROR: This usually means the core binary failed to execute
```

---

## 📊 故障排查

### 问题 1: "打开 Meta 失败" 对话框
**原因**: 内核验证或启动失败
**检查**:
1. 查看 `[VERIFY]` 日志 - 内核是否能执行 `-v` 命令
2. 查看 `[HELPER]` 日志 - Helper 是否成功启动进程

### 问题 2: 内核版本不对
**检查**: 日志中应该显示 `Mihomo Meta v1.17.0`
```bash
# 手动验证内核版本
gunzip -c ~/Library/Application\ Support/com.metacubex.ClashX.meta/.private_core/com.metacubex.ClashX.ProxyConfigHelper.meta.gz > /tmp/core
chmod +x /tmp/core
/tmp/core -v
rm /tmp/core
```

### 问题 3: 隔离属性未移除
**检查**:
```bash
xattr ~/Library/Application\ Support/com.metacubex.ClashX.meta/.private_core/com.metacubex.ClashX.ProxyConfigHelper.meta

# 应该不显示 com.apple.quarantine
```

### 问题 4: PrivilegedHelper 未安装
**症状**: 日志显示 `[START] ERROR: PrivilegedHelper not found`
**解决**: 重新安装 Helper
1. 打开 ClashX Meta 偏好设置
2. 点击 "Install Helper" 或类似按钮

---

## 📝 报告问题

如果测试失败,请提供:

1. **完整的日志文件**
   ```bash
   # 打包所有日志
   tar -czf clashx-logs.tar.gz \
     ~/Library/Logs/ClashX* \
     ~/.config/clash.meta/logs/
   ```

2. **系统信息**
   ```bash
   sw_vers
   ```

3. **内核文件信息**
   ```bash
   ls -lh ~/Library/Application\ Support/com.metacubex.ClashX.meta/.private_core/
   xattr ~/Library/Application\ Support/com.metacubex.ClashX.meta/.private_core/*
   ```

4. **错误截图** (如果有对话框)

---

## 🎯 关键修复点总结

1. ✅ **内核降级** - v1.17.0 支持 macOS 10.13+
2. ✅ **双重隔离移除** - ClashX 解压时 + Helper 启动时
3. ✅ **双重权限设置** - ClashX 验证时 + Helper 启动时
4. ✅ **详细日志** - 便于定位问题
5. ✅ **构建目标统一** - 所有组件都是 10.14

如果这个版本仍然失败,日志会明确告诉我们是哪一步出了问题!
