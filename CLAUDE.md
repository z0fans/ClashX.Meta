# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

ClashX.Meta 是一个基于 [Clash Meta (mihomo)](https://github.com/MetaCubeX/mihomo) 内核的 macOS 代理客户端。这是一个原生 Swift/SwiftUI 应用程序，支持 TUN 模式和系统代理配置。

## 构建命令

### 环境准备

```bash
# 安装 Golang（构建依赖）
brew install golang

# 下载依赖项（包括 mihomo 内核、GeoIP 数据库、Dashboard）
bash install_dependency.sh

# 解析 Swift Package 依赖
xcodebuild -resolvePackageDependencies -project ClashX.xcodeproj
```

### 构建应用

```bash
# 构建并归档
xcodebuild archive -project ClashX.xcodeproj -scheme "ClashX Meta" -archivePath archive/ClashX.xcarchive -showBuildTimingSummary -allowProvisioningUpdates
```

### 代码质量

```bash
# SwiftLint 检查（配置在 .swiftlint.yml）
swiftlint
```

## 架构概览

### 核心组件

1. **ClashProcess** (`ClashX/General/ClashProcess.swift`)
   - 管理 mihomo 核心进程的生命周期
   - 处理核心文件验证和解压
   - 通过 PrivilegedHelper 启动核心

2. **ApiRequest** (`ClashX/General/ApiRequest.swift`)
   - 与 Clash RESTful API 通信的单例
   - 使用 WebSocket 订阅流量、日志和内存数据
   - 管理代理、规则、连接等 API 调用

3. **ConfigManager** (`ClashX/General/Managers/ConfigManager.swift`)
   - 配置状态管理（RxSwift BehaviorRelay）
   - API 端口、密钥、运行状态管理
   - 配置文件监听

4. **PrivilegedHelperManager** (`ClashX/General/Managers/PrivilegedHelperManager.swift`)
   - 管理特权助手进程（用于系统代理和 TUN 模式）
   - 处理 SMJobBless 安装流程

5. **MenuItemFactory** (`ClashX/General/Managers/MenuItemFactory.swift`)
   - 动态生成状态栏菜单项
   - 处理代理组、规则提供者的菜单渲染

### 目录结构

```
ClashX/
├── AppDelegate.swift      # 应用入口，状态栏菜单管理
├── General/
│   ├── ClashProcess.swift # 核心进程管理
│   ├── ApiRequest.swift   # API 通信层
│   ├── ClashMetaConfig.swift # 配置解析
│   └── Managers/          # 各类管理器
├── Dashboard/             # SwiftUI Dashboard 界面
│   ├── Views/             # 各功能页面视图
│   └── Models/            # Dashboard 数据模型
├── Models/                # 数据模型（ClashProxy, ClashConfig 等）
├── ViewControllers/       # AppKit 视图控制器
└── AppleScript/           # AppleScript 命令支持

ProxyConfigHelper/         # 特权助手（系统代理/TUN 配置）
```

### 关键依赖 (Swift Package Manager)

- **Alamofire**: HTTP 网络请求
- **RxSwift/RxCocoa**: 响应式编程
- **SwiftyJSON**: JSON 解析
- **Yams**: YAML 配置文件解析
- **Starscream**: WebSocket 客户端
- **Sparkle**: 自动更新框架
- **KeyboardShortcuts**: 全局快捷键

### 配置文件位置

- 默认配置目录: `$HOME/.config/clash`
- 默认配置文件: `config.yaml`
- 自定义状态栏图标: `~/.config/clash/menuImage.png`

### URL Scheme 支持

```
clash://install-config?url=<encoded_url>&name=<config_name>
clash://update-config
```

### AppleScript 支持

```applescript
tell application "ClashX Meta" to toggleProxy      -- 切换系统代理
tell application "ClashX Meta" to proxyMode 'rule' -- 设置代理模式 (global/direct/rule)
tell application "ClashX Meta" to TunMode          -- 切换 TUN 模式
```
