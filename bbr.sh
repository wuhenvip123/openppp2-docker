#!/bin/bash

# 检查并加载 TCP 队列规则和拥塞控制算法
check_and_load_module() {
    local qdisc=$1
    local congestion_control=$2

    local qdisc_available=true
    local congestion_control_available=true

    if ! sysctl net.core.default_qdisc | grep -w $qdisc; then
        echo "尝试使用 $qdisc 队列规则..."
        if ! lsmod | grep -w "$qdisc"; then
            modprobe $qdisc 2>/dev/null
        fi
        if ! sysctl net.core.default_qdisc | grep -w $qdisc; then
            echo "警告: 队列规则 $qdisc 不可用。"
            qdisc_available=false
        fi
    fi
    echo "队列规则 $qdisc 可用。"

    if ! sysctl net.ipv4.tcp_congestion_control | grep -w $congestion_control; then
        echo "尝试使用 $congestion_control 拥塞控制算法..."
        if ! lsmod | grep -w "$congestion_control"; then
            modprobe $congestion_control 2>/dev/null
        fi
        if ! sysctl net.ipv4.tcp_congestion_control | grep -w $congestion_control; then
            echo "警告: 拥塞控制算法 $congestion_control 不可用。"
            congestion_control_available=false
        fi
    fi
    echo "拥塞控制算法 $congestion_control 可用。"

    if [ "$qdisc_available" = false ] || [ "$congestion_control_available" = false ]; then
        return 1
    fi

    return 0
}

# 应用 sysctl 配置
apply_sysctl() {
    local congestion_control=$1
    local qdisc=$2

    check_and_load_module $qdisc $congestion_control
    if [ $? -ne 0 ]; then
        echo "无法加载 $qdisc 或 $congestion_control 模块，退出。"
        return 1
    fi

    # 先清除现有配置
    clear_sysctl_conf

    # 写入新的配置
    write_sysctl_conf $congestion_control $qdisc

    # 应用系统配置
    sysctl -p
    sysctl --system

    # 调用 ulimit 配置函数
    set_ulimit

    echo "优化配置已应用。建议重启以生效。是否现在重启? 回车默认重启"
    read -p "输入选项: ( Y/n )" answer
    if [ -z "$answer" ] || [[ ! "$answer" =~ ^[Nn][Oo]?$ ]]; then
        reboot
    fi
}

# 清空 sysctl 配置，不弹出提示
clear_sysctl_conf() {
    echo "" > /etc/sysctl.conf
}

# 写 sysctl 配置文件
write_sysctl_conf() {
    local congestion_control=$1
    local qdisc=$2
    cat >> /etc/sysctl.conf << EOF
# 系统文件描述符限制，设置最大文件描述符数量
fs.file-max = $((1024 * 1024))  # 设置最大文件描述符数量

# 设置每个用户实例的 inotify 实例数量上限
fs.inotify.max_user_instances = 8192  # 设置每个用户实例的 inotify 实例数量上限

# 网络核心配置
net.core.rmem_max = $((64 * 1024 * 1024))  # 设置最大接收缓冲区大小
net.core.wmem_max = $((64 * 1024 * 1024))  # 设置最大发送缓冲区大小
net.core.netdev_max_backlog = 100000  # 设置接收队列的最大长度
net.core.somaxconn = 1000000  # 设置最大连接数
net.core.optmem_max = 65536  # 设置每个套接字的最大可选内存

# TCP配置
net.ipv4.tcp_syncookies = 0  # 禁用 syncookies 洪水攻击保护
net.ipv4.tcp_tw_reuse = 1  # 允许复用 TIME-WAIT sockets 用于新的 TCP 连接
net.ipv4.tcp_timestamps = 0  # 禁用 TCP 时间戳
net.ipv4.tcp_rmem = 4096 87380 $((64 * 1024 * 1024))  # 设置 TCP 接收缓冲区
net.ipv4.tcp_wmem = 4096 65536 $((64 * 1024 * 1024))  # 设置 TCP 发送缓冲区
net.ipv4.tcp_fastopen = 3  # 开启 TCP Fast Open
net.ipv4.tcp_window_scaling = 1  # 开启 TCP 窗口扩展
net.ipv4.tcp_adv_win_scale = -2  # 设置 TCP 窗口缩放因子
net.ipv4.tcp_mtu_probing = 1  # 开启 TCP MTU 探测
net.ipv4.tcp_max_orphans = 262144  # 设置最大孤儿连接数
net.ipv4.tcp_syn_retries = 3  # 设置 TCP SYN 重试次数
net.ipv4.tcp_synack_retries = 3  # 设置 TCP SYN-ACK 重试次数
net.ipv4.tcp_keepalive_time = 300  # 设置 TCP 保持连接时间
net.ipv4.tcp_keepalive_probes = 2  # 设置 TCP 保持连接探测数
net.ipv4.tcp_keepalive_intvl = 2  # 设置 TCP 保持连接探测间隔
net.ipv4.tcp_fin_timeout = 10  # 设置 TCP 连接关闭超时时间
net.ipv4.tcp_abort_on_overflow = 1  # 启用 TCP 溢出时的快速终止
net.ipv4.tcp_max_syn_backlog = 8192  # 设置最大 SYN 等待队列长度
net.ipv4.tcp_max_tw_buckets = 55000  # 设置最大 TIME-WAIT bucket 数量

# IP 转发配置
net.ipv4.ip_forward = 1  # 启用 IP 转发
net.ipv4.conf.all.forwarding = 1  # 启用所有接口的 IP 转发
net.ipv4.conf.default.forwarding = 1  # 启用默认接口的 IP 转发

# IPv6 配置
net.ipv6.conf.all.forwarding = 1  # 启用所有接口的 IPv6 转发
net.ipv6.conf.default.forwarding = 1  # 启用默认接口的 IPv6 转发
net.ipv6.conf.lo.forwarding = 1  # 启用本地接口的 IPv6 转发
net.ipv6.conf.all.disable_ipv6 = 0  # 启用 IPv6
net.ipv6.conf.default.disable_ipv6 = 0  # 启用默认接口的 IPv6
net.ipv6.conf.lo.disable_ipv6 = 0  # 启用本地接口的 IPv6
net.ipv6.conf.all.accept_ra = 2  # 接受 Router Advertisement
net.ipv6.conf.default.accept_ra = 2  # 接受默认接口的 Router Advertisement

# 调整虚拟内存行为
vm.swappiness = 10  # 设置虚拟内存交换使用率
vm.overcommit_memory = 1  # 允许内存过度分配

# 设置 TCP 拥塞控制算法
net.ipv4.tcp_congestion_control = $congestion_control  # 设置 TCP 拥塞控制算法
# 设置默认队列规则
net.core.default_qdisc = $qdisc  # 设置默认队列规则
EOF
}

# 设置 ulimit 配置
set_ulimit() {
    cat > /etc/security/limits.conf << EOF
* soft nofile $((1024 * 1024))
* hard nofile $((1024 * 1024))
* soft nproc unlimited
* hard nproc unlimited
* soft core unlimited
* hard core unlimited
EOF
    sed -i '/ulimit -SHn/d' /etc/profile
    echo "ulimit -SHn $((1024 * 1024))" >> /etc/profile
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
}

# 清理 sysctl 配置，不提示重启
clear_sysctl() {
    clear_sysctl_conf
    sysctl -p
}

# 显示系统信息
check_status() {
    kernel_version=$(uname -r | awk -F "-" '{print $1}')
    kernel_version_full=$(uname -r)
    net_congestion_control=$(cat /proc/sys/net/ipv4/tcp_congestion_control)
    net_qdisc=$(cat /proc/sys/net/core/default_qdisc)
    
    echo "当前系统信息:"
    echo "内核版本: $kernel_version_full"
    echo "TCP 拥塞控制算法: $net_congestion_control"
    echo "默认队列规则: $net_qdisc"
}

# 获取可用的拥塞控制算法
get_available_congestion_controls() {
    sysctl net.ipv4.tcp_available_congestion_control | awk -F "=" '{print $2}' | tr -d ' '
}

# 菜单选项
menu() {
    check_status

    local available_congestion_controls=$(get_available_congestion_controls)
    local queue_disciplines=("fq" "fq_pie" "cake")

    echo "可用的拥塞控制算法:"
    PS3="请选择拥塞控制算法: "
    select congestion_control in $available_congestion_controls; do
        if [ -n "$congestion_control" ]; then
            break
        else
            echo "无效选项，请重新选择。"
        fi
    done

    echo "可用的队列规则:"
    PS3="请选择队列规则: "
    select qdisc in "${queue_disciplines[@]}"; do
        if [ -n "$qdisc" ]; then
            break
        else
            echo "无效选项，请重新选择。"
        fi
    done

    echo "您选择了: 拥塞控制算法 $congestion_control 和队列规则 $qdisc"
    apply_sysctl $congestion_control $qdisc
}

menu
