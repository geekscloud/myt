#!/bin/sh

# ====================================================
# 魔云腾 C1 (Alpine ARM) 服务器初始化脚本
# 功能：清理残留服务 + 安装开发工具 + 修改主机名 + 配置 SSH
# ====================================================

# 定义颜色输出
echo_info() { echo "\033[32m[INFO]\033[0m $1"; }
echo_warn() { echo "\033[33m[WARN]\033[0m $1"; }

echo_info ">>> 1. 开始安装必备软件包 (后端排查增强)..."
# 增加 iproute2(ip命令), bind-tools(dig), tzdata(时区)
apk add git zsh vim openssl curl htop ca-certificates \
        docker-compose procps iproute2 bind-tools tzdata

echo_info ">>> 2. 修改系统主机名为 myt-c1..."
NEW_HOSTNAME="myt-c1"
echo "$NEW_HOSTNAME" > /etc/hostname
hostname "$NEW_HOSTNAME"
# 修改 hosts 文件防止 sudo 等工具报错
sed -i "s/127.0.1.1.*/127.0.1.1 $NEW_HOSTNAME/g" /etc/hosts || echo "127.0.1.1 $NEW_HOSTNAME" >> /etc/hosts

echo_info ">>> 3. 配置 SSH 允许 Root 密码与密钥登录..."
if [ -f "/etc/ssh/sshd_config" ]; then
    # 允许 Root 登录
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    # 允许 密码登录
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    # 允许 密钥登录 (通常默认开启，这里强制确认)
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    
    rc-service sshd restart || echo_warn "SSHD 重启失败，请检查配置"
else
    echo_warn "未找到 sshd_config，请确认是否安装了 openssh"
fi

echo_info ">>> 4. 停用魔云腾官方 OpenRC 服务..."
for svc in mytsvr myt_sdk; do
    if [ -f "/etc/init.d/$svc" ]; then
        rc-service $svc stop 2>/dev/null || true
        rc-update del $svc default 2>/dev/null || true
        echo_info " - 服务 $svc 已被禁用"
    fi
done

echo_info ">>> 5. 彻底封禁隐藏的幽灵组件 (myt_vpc)..."
VPC_PATH="/mmc/resource/myt_vpc/myt_vpc"
# 使用 procps 提供的 pkill 更精准
if pgrep -f "myt_vpc" > /dev/null; then
    pkill -9 -f "myt_vpc"
    echo_info " - 已强制杀死正在运行的 myt_vpc"
fi

if [ -f "$VPC_PATH" ]; then
    mv "$VPC_PATH" "${VPC_PATH}.bak" 2>/dev/null || true
    chmod 000 "${VPC_PATH}.bak" 2>/dev/null || true
    echo_info " - 已封禁二进制文件: $VPC_PATH"
fi

echo_info ">>> 6. 清理 local.d 启动脚本..."
if [ -d "/etc/local.d" ]; then
    rm -f /etc/local.d/myt*.start
    echo_info " - 已清理 /etc/local.d/ 下的厂商残留脚本"
fi

echo_info ">>> 7. 环境自愈：清理 Docker 状态锁..."
rm -f /run/openrc/started/docker /var/run/docker.pid /var/run/docker.sock

echo_info ">>> 8. 尝试启动容器服务..."
rc-service containerd restart || true
rc-service docker start || true

echo "----------------------------------------------------"
echo "✅ 初始化完成！你的服务器现在是纯净状态了。"
echo " - 当前主机名: $(hostname)"
echo " - SSH 配置: 已允许 Root 密码/密钥登录"
echo " - 常用工具: vim, docker-compose, ip, dig"
echo " - 8001 端口: $(netstat -tunlp | grep 8001 || echo '已释放(OK)')"
echo "----------------------------------------------------"
echo_warn "提示: 如需将默认 Shell 改为 zsh，请执行: sed -i 's/\/bin\/ash/\/bin\/zsh/g' /etc/passwd"
