#!/bin/sh

# ====================================================
# 魔云腾 C1 管理工具 (c1-cli)
# 功能：厂商清理、环境初始化、Rust/rktop 迁移安装
# ====================================================

echo_info() { echo "\033[32m[INFO]\033[0m $1"; }
echo_warn() { echo "\033[33m[WARN]\033[0m $1"; }

# 1. 系统初始化清理
do_clean() {
    echo_info "开始清理厂商服务与 Docker 锁..."
    # 修改主机名
    echo "myt-c1" > /etc/hostname && hostname "myt-c1"
    
    # 停用服务
    for svc in mytsvr myt_sdk; do
        [ -f "/etc/init.d/$svc" ] && rc-service $svc stop 2>/dev/null && rc-update del $svc default 2>/dev/null
    done
    
    # 封禁 vpc
    pkill -9 -f "myt_vpc" 2>/dev/null
    VPC_PATH="/mmc/resource/myt_vpc/myt_vpc"
    if [ -f "$VPC_PATH" ]; then
        mv "$VPC_PATH" "${VPC_PATH}.bak" 2>/dev/null
        chmod 000 "${VPC_PATH}.bak"
    fi
    
    # 清理 Docker 锁
    rm -f /run/openrc/started/docker /var/run/docker.pid /var/run/docker.sock
    rc-service containerd restart && rc-service docker start
    echo_info "清理完成！"
}

# 2. 安装 Rust 并迁移至 /mmc
do_rust_install() {
    echo_info "配置 Rust 迁移至 /mmc/rustup..."
    mkdir -p /mmc/rustup/rustup /mmc/rustup/cargo
    
    # 软链接处理
    [ -L "/root/.rustup" ] || ln -s /mmc/rustup/rustup /root/.rustup
    [ -L "/root/.cargo" ] || ln -s /mmc/rustup/cargo /root/.cargo
    
    # 配置环境
    if ! grep -q "RUSTUP_HOME" /root/.zshrc; then
        cat >> /root/.zshrc <<EOF
export RUSTUP_HOME=/root/.rustup
export CARGO_HOME=/root/.cargo
export PATH=\$CARGO_HOME/bin:\$PATH
EOF
    fi
    source /root/.zshrc
    
    echo_info "正在通过官方脚本安装 Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    
    source /root/.cargo/env
    echo_info "Rust 安装完成！"
}

# 3. 安装 rktop
do_rktop() {
    echo_info "正在编译安装 rktop (需安装 build-base)..."
    apk add build-base ncurses-dev
    cargo install rktop
    echo_info "rktop 安装成功，请直接输入 rktop 运行。"
}

# 菜单显示
show_menu() {
    echo "------------------------------------------------"
    echo "   魔云腾 C1 管理工具 (CLI 版)"
    echo "------------------------------------------------"
    echo " 1) 基础清理 (清理厂商服务/Docker/改主机名)"
    echo " 2) 安装常用包 (git, zsh, vim, dc, procps)"
    echo " 3) 迁移安装 Rust (至 /mmc 存储)"
    echo " 4) 编译安装 rktop"
    echo " 5) 配置 SSH (允许 Root 登录)"
    echo " 0) 退出"
    echo "------------------------------------------------"
    printf "请输入选项: "
}

# 执行逻辑
while true; do
    show_menu
    read choice
    case $choice in
        1) do_clean ;;
        2) apk add git zsh vim openssl curl htop ca-certificates docker-compose procps iproute2 bind-tools ;;
        3) do_rust_install ;;
        4) do_rktop ;;
        5)
            sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
            sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
            rc-service sshd restart && echo_info "SSH 配置已生效"
            ;;
        0) exit 0 ;;
        *) echo_warn "无效选项" ;;
    esac
done
