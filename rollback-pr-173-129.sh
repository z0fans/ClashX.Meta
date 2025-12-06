#!/bin/bash
#
# PR #173 和 #129 回退脚本
#
# 用法: bash rollback-pr-173-129.sh
#
# 此脚本会将代码回退到应用 PR 之前的状态
#

set -e  # 遇到错误立即退出

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================="
echo "  PR #173 & #129 回退脚本"
echo "========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否在 Git 仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}错误: 当前目录不是 Git 仓库${NC}"
    exit 1
fi

# 获取当前分支
CURRENT_BRANCH=$(git branch --show-current)
echo -e "当前分支: ${YELLOW}${CURRENT_BRANCH}${NC}"
echo ""

# 检查工作区状态
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}警告: 工作区有未提交的变更${NC}"
    echo ""
    git status --short
    echo ""
    read -p "是否继续回退? 未提交的变更将丢失! (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${RED}回退已取消${NC}"
        exit 1
    fi
fi

echo "可用的回退选项:"
echo ""
echo "  1) 回退到原始 main 分支 (完全撤销所有变更)"
echo "  2) 回退到备份分支 backup-before-pr-173-129"
echo "  3) 仅撤销最后一次提交 (保留文件但取消提交)"
echo "  4) 查看变更差异后再决定"
echo "  5) 取消回退"
echo ""
read -p "请选择回退方式 (1-5): " CHOICE

case $CHOICE in
    1)
        echo ""
        echo -e "${YELLOW}回退到 main 分支...${NC}"

        # 保存当前分支名以备恢复
        BACKUP_BRANCH="${CURRENT_BRANCH}-backup-$(date +%Y%m%d-%H%M%S)"
        git branch "$BACKUP_BRANCH" 2>/dev/null || true

        # 切换到 main 分支
        git checkout main

        # 清理工作区
        git clean -fd

        echo -e "${GREEN}✓ 已成功回退到 main 分支${NC}"
        echo -e "  原分支已备份为: ${YELLOW}${BACKUP_BRANCH}${NC}"
        echo -e "  如需恢复,运行: ${YELLOW}git checkout ${BACKUP_BRANCH}${NC}"
        ;;

    2)
        echo ""
        echo -e "${YELLOW}回退到备份分支...${NC}"

        # 检查备份分支是否存在
        if ! git rev-parse --verify backup-before-pr-173-129 >/dev/null 2>&1; then
            echo -e "${RED}错误: 备份分支 backup-before-pr-173-129 不存在${NC}"
            exit 1
        fi

        # 保存当前分支
        BACKUP_BRANCH="${CURRENT_BRANCH}-backup-$(date +%Y%m%d-%H%M%S)"
        git branch "$BACKUP_BRANCH" 2>/dev/null || true

        # 切换到备份分支
        git checkout backup-before-pr-173-129

        echo -e "${GREEN}✓ 已成功回退到备份分支${NC}"
        echo -e "  原分支已备份为: ${YELLOW}${BACKUP_BRANCH}${NC}"
        ;;

    3)
        echo ""
        echo -e "${YELLOW}撤销最后一次提交...${NC}"

        # 显示最后一次提交
        echo ""
        git log -1 --oneline
        echo ""
        read -p "确认撤销此提交? (yes/no): " CONFIRM
        if [ "$CONFIRM" != "yes" ]; then
            echo -e "${RED}回退已取消${NC}"
            exit 1
        fi

        # 软重置到上一个提交
        git reset --soft HEAD~1

        echo -e "${GREEN}✓ 已撤销最后一次提交${NC}"
        echo -e "  文件变更已保留在暂存区"
        echo -e "  运行 ${YELLOW}git reset HEAD .${NC} 可取消暂存"
        echo -e "  运行 ${YELLOW}git checkout -- .${NC} 可丢弃所有变更"
        ;;

    4)
        echo ""
        echo -e "${YELLOW}显示变更差异...${NC}"
        echo ""

        # 显示变更的文件
        echo "变更的文件:"
        git diff --name-status backup-before-pr-173-129..HEAD
        echo ""

        read -p "查看详细差异? (yes/no): " SHOW_DIFF
        if [ "$SHOW_DIFF" = "yes" ]; then
            git diff backup-before-pr-173-129..HEAD
        fi

        echo ""
        echo "请重新运行此脚本选择回退方式"
        ;;

    5)
        echo ""
        echo -e "${GREEN}回退已取消${NC}"
        exit 0
        ;;

    *)
        echo ""
        echo -e "${RED}无效的选择${NC}"
        exit 1
        ;;
esac

echo ""
echo "========================================="
echo "  回退完成"
echo "========================================="
