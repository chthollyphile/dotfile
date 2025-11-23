#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting fresh setup for your Arch Linux system...${NC}"

# 1. 检查是否以 Root 运行 (不建议，因为 AUR 助手不能以 Root 运行)
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}请不要使用 sudo 运行此脚本。脚本内部会在需要时请求 sudo 权限。${NC}"
  exit 1
fi

# 2. 更新系统并安装基本构建工具 (为 AUR 准备)
echo -e "${GREEN}[1/5] 更新系统并安装 base-devel...${NC}"
sudo pacman -Syu --noconfirm --needed base-devel git

# 3. 安装 Pacman 官方仓库包
# 注意：netease-cloud-music-gtk4 移动到了 AUR 部分
echo -e "${GREEN}[2/5] 安装 Pacman 官方包...${NC}"
PACKAGES_PACMAN=(
    "cava"
    "fish"
    "toilet"
    "lolcat"
    "nautilus-python"
    "fcitx5-chinese-addons"
    "fcitx5-configtool"
    "fcitx5-im" # 建议加上这个组，包含 fcitx5 核心库和模块
)

sudo pacman -S --noconfirm --needed "${PACKAGES_PACMAN[@]}"

# 4. 检查并安装 AUR 助手 (默认为 yay)
if ! command -v yay &> /dev/null; then
    echo -e "${BLUE}未检测到 yay，正在安装...${NC}"
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
else
    echo -e "${GREEN}检测到 yay 已安装，跳过安装步骤。${NC}"
fi

# 5. 安装 AUR 包
echo -e "${GREEN}[3/5] 安装 AUR 软件包...${NC}"
PACKAGES_AUR=(
    "waylyrics"
    "mpvpaper"
    "awww-git"
    "discord_arch_electron"
    "netease-cloud-music-gtk4"
)

yay -S --noconfirm --needed "${PACKAGES_AUR[@]}"

# 6. 配置系统语言环境 (Locale)
echo -e "${GREEN}[4/5] 配置系统语言为 zh_CN.UTF-8...${NC}"

# 备份 locale.gen
sudo cp /etc/locale.gen /etc/locale.gen.bak

# 启用 zh_CN.UTF-8
echo "正在修改 /etc/locale.gen..."
sudo sed -i 's/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen

# 同时也确保 en_US.UTF-8 是开启的（作为回退防止乱码）
sudo sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen

# 生成 locale
echo "生成 locale..."
sudo locale-gen

# 设置系统默认语言
echo "设置 /etc/locale.conf..."
echo "LANG=zh_CN.UTF-8" | sudo tee /etc/locale.conf

# 7. (可选) 更改默认 Shell 为 Fish
echo -e "${GREEN}[5/5] 设置 Fish 为默认 Shell? (y/n)${NC}"
read -r change_shell
if [[ "$change_shell" =~ ^[Yy]$ ]]; then
    chsh -s "$(which fish)"
    echo "默认 Shell 已更改为 Fish (需重新登录生效)。"
fi

# 结束
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${GREEN}所有任务已完成！${NC}"
echo -e "${BLUE}请重启系统以应用语言更改和输入法配置。${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

# 使用 toilet 和 lolcat 打印结束语
if command -v toilet &> /dev/null && command -v lolcat &> /dev/null; then
    toilet "Setup Done" | lolcat
fi
