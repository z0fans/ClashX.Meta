APP = ClashX Meta
BUNDLE_ID = com.metacubex.ClashX.Meta

BUILD_PATH = $(PWD)/archive
APP_PATH = "$(BUILD_PATH)/ClashX.xcarchive/Products/Applications/$(APP).app"
ZIP_PATH = "$(BUILD_PATH)/$(APP).zip"

.SILENT: archive sign prepare-dmg prepare-dSYM clean open
.PHONY: build archive sign prepare-dmg prepare-dSYM clean open

# 完整构建流程 (参考 Stats 项目)
build: clean archive prepare-dmg prepare-dSYM open

# --- 主要构建步骤 --- #

archive: clean
	@echo "========================================"
	@echo "📦 开始构建 $(APP)"
	@echo "========================================"

	# 构建并归档应用
	xcodebuild archive \
		-project ClashX.xcodeproj \
		-scheme "$(APP)" \
		-archivePath $(BUILD_PATH)/ClashX.xcarchive \
		-showBuildTimingSummary \
		-allowProvisioningUpdates

	@echo "✅ 应用归档完成"

	# 导出应用
	xcodebuild -exportArchive \
		-exportOptionsPlist "$(PWD)/exportOptions.plist" \
		-archivePath $(BUILD_PATH)/ClashX.xcarchive \
		-exportPath $(BUILD_PATH)

	@echo "✅ 应用导出完成"

	# 创建 ZIP 归档 (用于公证)
	ditto -c -k --keepParent $(APP_PATH) $(ZIP_PATH)

	@echo "✅ ZIP 归档创建完成"

sign:
	@echo "========================================"
	@echo "🔐 准备签名和公证"
	@echo "========================================"
	@echo ""
	@echo "⚠️  注意: 签名和公证需要 Apple Developer 账号"
	@echo ""
	@echo "手动执行以下步骤:"
	@echo ""
	@echo "1. 提交公证:"
	@echo "   xcrun notarytool submit $(ZIP_PATH) \\"
	@echo "       --keychain-profile \"AC_PASSWORD\" --wait"
	@echo ""
	@echo "2. 验证公证状态:"
	@echo "   xcrun notarytool info <submission-id> \\"
	@echo "       --keychain-profile \"AC_PASSWORD\""
	@echo ""
	@echo "3. 装订公证票据:"
	@echo "   xcrun stapler staple $(APP_PATH)"
	@echo ""
	@echo "4. 验证签名:"
	@echo "   spctl -a -t exec -vvv $(APP_PATH)"
	@echo ""
	@echo "========================================"

prepare-dmg:
	@echo "========================================"
	@echo "📀 创建 DMG 安装包"
	@echo "基于 Stats 项目的打包方案"
	@echo "========================================"

	# 执行 DMG 打包脚本
	bash $(PWD)/create_dmg.sh

	@echo "✅ DMG 创建完成"

prepare-dSYM:
	@echo "========================================"
	@echo "🔍 打包调试符号"
	@echo "========================================"

	if [ -d "$(BUILD_PATH)/ClashX.xcarchive/dSYMs" ]; then \
		cd $(BUILD_PATH)/ClashX.xcarchive/dSYMs && \
		zip -r $(PWD)/dSYMs.zip .; \
		echo "✅ dSYMs 打包完成: dSYMs.zip"; \
	else \
		echo "⚠️  未找到 dSYMs 目录"; \
	fi

# --- 辅助命令 --- #

clean:
	@echo "🧹 清理旧的构建产物..."
	rm -rf $(BUILD_PATH)
	rm -f "$(PWD)/$(APP).dmg"
	rm -f "$(PWD)/dSYMs.zip"
	@echo "✓ 清理完成"

open:
	@echo ""
	@echo "========================================"
	@echo "✅ 构建流程完成!"
	@echo "========================================"
	@echo ""
	@echo "生成的文件:"
	@echo "  - $(APP).dmg"
	if [ -f "$(PWD)/dSYMs.zip" ]; then \
		echo "  - dSYMs.zip"; \
	fi
	@echo ""
	@echo "正在打开工作目录..."
	open $(PWD)

# --- 开发辅助命令 --- #

# 仅构建应用 (不打包 DMG)
build-only: clean archive
	@echo "✅ 仅构建完成,应用位于: $(APP_PATH)"

# 仅创建 DMG (假设应用已构建)
dmg-only: prepare-dmg
	@echo "✅ DMG 创建完成"

# 检查依赖
check-deps:
	@echo "========================================"
	@echo "🔍 检查依赖项"
	@echo "========================================"
	@command -v xcodebuild >/dev/null 2>&1 || { echo "❌ 未安装 Xcode"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "❌ 未安装 Git"; exit 1; }
	@echo "✅ Xcode: $$(xcodebuild -version | head -n1)"
	@echo "✅ Git: $$(git --version)"
	@echo ""
	@echo "可选依赖:"
	@command -v brew >/dev/null 2>&1 && echo "✅ Homebrew: $$(brew --version | head -n1)" || echo "⚠️  未安装 Homebrew"
	@echo ""
	@echo "✅ 所有必需依赖已安装"

# 显示帮助信息
help:
	@echo "========================================"
	@echo "ClashX Meta 构建工具"
	@echo "基于 Stats 项目的 Makefile 方案"
	@echo "========================================"
	@echo ""
	@echo "可用命令:"
	@echo ""
	@echo "  make build         - 完整构建流程 (推荐)"
	@echo "  make archive       - 构建并归档应用"
	@echo "  make prepare-dmg   - 创建 DMG 安装包"
	@echo "  make prepare-dSYM  - 打包调试符号"
	@echo "  make sign          - 显示签名和公证指南"
	@echo "  make clean         - 清理构建产物"
	@echo ""
	@echo "辅助命令:"
	@echo ""
	@echo "  make build-only    - 仅构建应用 (不打包 DMG)"
	@echo "  make dmg-only      - 仅创建 DMG (应用已构建)"
	@echo "  make check-deps    - 检查依赖项"
	@echo "  make help          - 显示此帮助信息"
	@echo ""
	@echo "========================================"
	@echo ""
	@echo "示例用法:"
	@echo ""
	@echo "  # 完整构建 (包含 DMG)"
	@echo "  make build"
	@echo ""
	@echo "  # 仅构建应用"
	@echo "  make build-only"
	@echo ""
	@echo "  # 清理后重新构建"
	@echo "  make clean && make build"
	@echo ""
	@echo "========================================"

.DEFAULT_GOAL := help
