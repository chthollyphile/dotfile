#!/bin/bash

# ==========================================
# Arch Linux 显卡模式切换工具 (EnvyControl + Systemd Fix)
# ==========================================

# 定义颜色，让输出更清晰
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否安装了 envycontrol
if ! command -v envycontrol &> /dev/null; then
    echo -e "${RED}错误: 未找到 envycontrol 命令。请先安装它。${NC}"
    exit 1
fi

# 获取当前模式
CURRENT_MODE=$(envycontrol -q)

clear
echo -e "${BLUE}========================================${NC}"
echo -e "       显卡模式切换 & 睡眠修复工具       "
echo -e "${BLUE}========================================${NC}"
echo -e "当前显卡模式: ${YELLOW}${CURRENT_MODE}${NC}"
echo ""
echo "请选择要切换的目标模式："
echo ""
echo -e "  ${GREEN}1.${NC} 省电模式 (Integrated / Intel Only)"
echo -e "     - 完全禁用 NVIDIA 显卡"
echo -e "     - 自动禁用 NVIDIA 睡眠服务 (修复睡死问题)"
echo ""
echo -e "  ${GREEN}2.${NC} 游戏模式 (Hybrid / Intel + NVIDIA)"
echo -e "     - 开启 NVIDIA 显卡 (按需调用)"
echo -e "     - 自动启用 NVIDIA 睡眠服务 (防止显存丢失)"
echo ""
echo -e "  ${GREEN}3.${NC} 取消并退出"
echo ""
echo -e "${BLUE}========================================${NC}"
read -p "请输入选项数字 [1-3]: " choice

case $choice in
    1)
        echo ""
        echo -e "${YELLOW}正在切换到 Integrated (省电) 模式...${NC}"
        
        # 1. 切换显卡模式
        sudo envycontrol -s integrated --verbose
        
        # 2. 处理服务：立即停止并禁用，防止当前或重启后卡死
        echo -e "${YELLOW}正在禁用 NVIDIA 挂起服务...${NC}"
        sudo systemctl disable --now nvidia-suspend nvidia-hibernate nvidia-resume
        
        echo -e "${GREEN}成功！已切换至 Integrated 模式并清理了 NVIDIA 服务。${NC}"
        ;;
        
    2)
        echo ""
        echo -e "${YELLOW}正在切换到 Hybrid (游戏) 模式...${NC}"
        
        # 1. 切换显卡模式
        sudo envycontrol -s hybrid --verbose
        
        # 2. 处理服务：只 Enable，不 Now。因为当前显卡可能还没电，强行 Start 可能会报错。
        # 重启后这些服务会自动生效。
        echo -e "${YELLOW}正在预启用 NVIDIA 挂起服务 (重启后生效)...${NC}"
        sudo systemctl enable nvidia-suspend nvidia-hibernate nvidia-resume
        
        echo -e "${GREEN}成功！已切换至 Hybrid 模式并配置了电源管理服务。${NC}"
        ;;
        
    3)
        echo "操作已取消。"
        exit 0
        ;;
        
    *)
        echo -e "${RED}无效的输入，脚本退出。${NC}"
        exit 1
        ;;
esac

# 询问是否重启
echo ""
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${RED}注意：更改显卡模式需要重启才能生效。${NC}"
read -p "是否立即重启电脑? (y/n): " reboot_choice

if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}正在重启...${NC}"
    reboot
else
    echo -e "${GREEN}请记得稍后手动重启以应用更改。${NC}"
fi
