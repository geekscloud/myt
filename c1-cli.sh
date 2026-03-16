#!/bin/sh

# ====================================================
# 魔云腾 C1 管理工具 (c1-cli) - 2026 最终版
# 功能：厂商清理、环境初始化、Rust/rktop 迁移、Oh My Zsh 自动化
# ====================================================

echo_info() { echo "\033[32m[INFO]\033[0m $1"; }
echo_warn() { echo "\033[33m[WARN]\033[0m $1"; }

# 1. 系统初始化清理
do_clean() {
    echo_info "开始清理厂商服务与 Docker 锁..."
    echo "myt-c1" > /etc/hostname && hostname "myt-c1"
    for svc in mytsvr myt_sdk; do
        [ -f "/etc/init.d/$svc" ] && rc-service $svc stop 2>/dev/null && rc-update del $svc default 2>/dev/null
    done
    pkill -9 -f "myt_vpc" 2>/dev/null
    VPC_PATH="/mmc/resource/myt_vpc/myt_vpc"
    if [ -f "$VPC_PATH" ]; then
        mv "$VPC_PATH" "${VPC_PATH}.bak" 2>/dev/null
        chmod 000 "${VPC_PATH}.bak"
    fi
    rm -f /run/openrc/started/docker /var/run/docker.pid /var/run/docker.sock
    rc-service containerd restart && rc-service docker start
    echo_info "清理完成！"
}

# 2. 自动化安装 Oh My Zsh 及插件
do_oh_my_zsh() {
    echo_info "正在安装 Oh My Zsh..."
    apk add git zsh curl
    
    # 自动化安装 OMZ (不进入交互 Shell，自动切换默认 Shell)
    sh -c "$(curl -fsSL https://raw.staticdn.net/robbyrussell/oh-my-zsh/master/tools/install.sh)" "" --unattended --keep-zshrc
    
    # 设置 Zsh 路径常量 (针对 root 用户)
    ZSH_CUSTOM="/root/.oh-my-zsh/custom"
    
    echo_info "安装插件: zsh-autosuggestions & zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM}/plugins/zsh-autosuggestions || true
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting || true
    
    # 修改 .zshrc 启用插件 (精准替换 plugins= 行)
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/g' /root/.zshrc
    
    # 强制切换默认 Shell (Alpine 特色)
    sed -i 's/\/bin\/ash/\/bin\/zsh/g' /etc/passwd
    
    echo_info "Oh My Zsh 安装配置完成！重启终端后生效。"
}

# 3. 迁移安装 Rust (至 /mmc)
do_rust_install() {
    echo_info "配置 Rust 迁移至 /mmc/rustup..."
    mkdir -p /mmc/rustup/rustup /mmc/rustup/cargo
    [ -L "/root/.rustup" ] || ln -s /mmc/rustup/rustup /root/.rustup
    [ -L "/root/.cargo" ] || ln -s /mmc/rustup/cargo /root/.cargo
    
    if ! grep -q "RUSTUP_HOME" /root/.zshrc; then
        cat >> /root/.zshrc <<EOF
export RUSTUP_HOME=/root/.rustup
export CARGO_HOME=/root/.cargo
export PATH=\$CARGO_HOME/bin:\$PATH
EOF
    fi
    
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    echo_info "Rust 安装完成！"
}

# 4. 安装 rktop
do_rktop() {
    echo_info "正在编译安装 rktop..."
    apk add build-base ncurses-dev
    source /root/.cargo/env
    cargo install rktop
    echo_info "rktop 安装成功。"
}

show_menu() {
    echo "------------------------------------------------"
    echo "   魔云腾 C1 管理工具 (CLI 版)"
    echo "------------------------------------------------"
    echo " 1) 基础清理 (清理厂商服务/Docker/改主机名)"
    echo " 2) 安装常用包 (git, zsh, vim, dc, procps)"
    echo " 3) 一键 Oh My Zsh (含补全/高亮插件)"
    echo " 4) 迁移安装 Rust (至 /mmc 存储)"
    echo " 5) 编译安装 rktop"
    echo " 6) 配置 SSH (允许 Root 登录)"
    echo " 0) 退出"
    echo "------------------------------------------------"
    printf "请输入选项: "
}

while true; do
    show_menu
    read choice
    case $choice in
        1) do_clean ;;
        2) apk add git zsh vim openssl curl htop ca-certificates docker-compose procps iproute2 bind-tools ;;
        3) do_oh_my_zsh ;;
        4) do_rust_install ;;
        5) do_rktop ;;
        6)
            sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
            sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
            rc-service sshd restart && echo_info "SSH 配置已生效"
            ;;
        0) exit 0 ;;
        *) echo_warn "无效选项" ;;
    esac
done
