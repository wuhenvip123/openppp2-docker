#!/bin/bash

# 应用 sysctl 配置
apply_sysctl() {
    local congestion_control=$1
    local qdisc=$2

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
    read -p "输入选项: (Y/n) " answer
    if [ -z "$answer" ] || [[ ! "$answer" =~ ^[Nn][Oo]?$ ]]; then
        reboot
    fi
}

# 清空 sysctl 配置，不弹出提示
clear_sysctl_conf() {
    echo "" > /etc/sysctl.conf
}

# 清理 sysctl 配置，不提示重启
clear_sysctl() {
    clear_sysctl_conf
    sysctl -p
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
    sysctl net.ipv4.tcp_available_congestion_control | awk -F "=" '{print $2}' | tr ' ' '\n'
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

# 写 sysctl 配置文件
write_sysctl_conf() {
    local congestion_control=$1
    local qdisc=$2
    cat >> /etc/sysctl.conf << EOF
# 系统文件描述符限制，设置最大文件描述符数量
fs.file-max = $((1024 * 1024))

# 设置每个用户实例的 inotify 实例数量上限
fs.inotify.max_user_instances = 8192

# 网络核心配置
net.core.rmem_max = $((64 * 1024 * 1024))
net.core.wmem_max = $((64 * 1024 * 1024))
net.core.netdev_max_backlog = 100000
net.core.somaxconn = 1000000
net.core.optmem_max = 65536

# TCP配置
net.ipv4.tcp_syncookies = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_rmem = 4096 87380 $((64 * 1024 * 1024))
net.ipv4.tcp_wmem = 4096 65536 $((64 * 1024 * 1024))
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_max_orphans = 262144
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 2
net.ipv4.tcp_keepalive_intvl = 2
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_abort_on_overflow = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 55000

# IP 转发配置
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1

# IPv6 配置
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.lo.forwarding = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2

# 调整虚拟内存行为
vm.swappiness = 10
vm.overcommit_memory = 1

# 设置 TCP 拥塞控制算法
net.ipv4.tcp_congestion_control = $congestion_control

# 设置默认队列规则
net.core.default_qdisc = $qdisc
EOF
}

menu
