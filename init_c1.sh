#!/bin/sh

# ====================================================
# 魔云腾 C1 (Alpine ARM) 服务器初始化脚本
# 功能：清理残留服务 + 安装开发工具 (git, zsh, openssl)
# ====================================================

# 定义颜色输出
echo_info() { echo "\033[32m[INFO]\033[0m $1"; }
echo_warn() { echo "\033[33m[WARN]\033[0m $1"; }

echo_info ">>> 1. 开始安装必备软件包 (git, zsh, openssl)..."
# 系统源已配置，直接安装
apk add git zsh openssl curl htop ca-certificates

echo_info ">>> 2. 停用魔云腾官方 OpenRC 服务..."
for svc in mytsvr myt_sdk; do
    if [ -f "/etc/init.d/$svc" ]; then
        rc-service $svc stop 2>/dev/null || true
        rc-update del $svc default 2>/dev/null || true
        echo_info " - 服务 $svc 已被禁用"
    fi
done

echo_info ">>> 3. 彻底封禁隐藏的幽灵组件 (myt_vpc)..."
VPC_PATH="/mmc/resource/myt_vpc/myt_vpc"

# 找到并杀死所有 myt_vpc 进程
pids=$(ps | grep "myt_vpc" | grep -v grep | awk '{print $1}')
if [ -n "$pids" ]; then
    kill -9 $pids
    echo_info " - 已强制杀死正在运行的 myt_vpc"
fi

# 重命名文件并撤销执行权限，防止脚本自动拉起
if [ -f "$VPC_PATH" ]; then
    mv "$VPC_PATH" "${VPC_PATH}.bak" 2>/dev/null || true
    chmod 000 "${VPC_PATH}.bak" 2>/dev/null || true
    echo_info " - 已封禁二进制文件: $VPC_PATH"
fi

echo_info ">>> 4. 清理 local.d 启动脚本..."
# 魔云腾常在此处设置开机自启逻辑
if [ -d "/etc/local.d" ]; then
    rm -f /etc/local.d/myt*.start
    echo_info " - 已清理 /etc/local.d/ 下的厂商残留脚本"
fi

echo_info ">>> 5. 环境自愈：清理 Docker 状态锁..."
# 解决 1Panel 恢复快照或重启 Docker 时常见的 flock 冲突
rm -f /run/openrc/started/docker
rm -f /var/run/docker.pid
rm -f /var/run/docker.sock

echo_info ">>> 6. 尝试启动容器服务..."
rc-service containerd restart || true
rc-service docker start || true

echo "----------------------------------------------------"
echo "✅ 初始化完成！你的服务器现在是纯净状态了。"
echo " - Git 版本: $(git --version)"
echo " - Zsh 版本: $(zsh --version)"
echo " - OpenSSL:  $(openssl version)"
echo " - 8001 端口: $(netstat -tunlp | grep 8001 || echo '已释放(OK)')"
echo "----------------------------------------------------"
echo_warn "提示: 如需将默认 Shell 改为 zsh，请执行: sed -i 's/\/bin\/ash/\/bin\/zsh/g' /etc/passwd"
