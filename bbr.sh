#!/bin/bash

# 检测内核版本是否支持 BBR3
check_kernel_for_bbr3() {
    local kernel_version=$(uname -r | cut -d- -f1)
    if [[ $(echo $kernel_version | awk -F. '{print ($1 * 1000 + $2 * 10 + $3)}') -lt 6010 ]]; then
        echo "0"
    else
        echo "1"
    fi
}

# 应用 sysctl 配置
apply_sysctl() {
    local congestion_control=$1
    local qdisc=$2
    cat > /etc/sysctl.conf << EOF
# 系统文件描述符限制
fs.file-max = 1048575
fs.inotify.max_user_instances = 8192

# 网络核心配置
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 100000
net.core.somaxconn = 1000000
net.core.default_qdisc = $qdisc
net.core.optmem_max = 65536

# TCP配置
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
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
net.ipv4.tcp_congestion_control = $congestion_control

# IP转发
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1

# IPv6配置
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
EOF

    # 应用系统配置
    sysctl -p
    sysctl --system
    echo "优化配置已应用。建议重启以生效。是否现在重启? (默认: Y/n)"
    read -p "输入选项: " answer
    if [ -z "$answer" ] || [[ ! "$answer" =~ ^[Nn][Oo]?$ ]]; then
        reboot
    fi
}

# 清理 sysctl 配置
clear_sysctl() {
    echo "" > /etc/sysctl.conf
    sysctl -p
    echo "优化配置已清除。建议重启以生效。是否现在重启? (默认: Y/n)"
    read -p "输入选项: " answer
    if [ -z "$answer" ] || [[ ! "$answer" =~ ^[Nn][Oo]?$ ]]; then
        reboot
    fi
}

# 菜单选项
menu() {
    echo "请选择优化方案:"
    local support_bbr3=$(check_kernel_for_bbr3)
    if [[ $support_bbr3 -eq 1 ]]; then
        echo "1) 启用优化方案 bbr+fq"
        echo "2) 启用优化方案 bbr+fq_pie"
        echo "3) 启用优化方案 bbr+cake"
        echo "4) 启用优化方案 bbr3+fq"
        echo "5) 启用优化方案 bbr3+fq_pie"
        echo "6) 启用优化方案 bbr3+cake"
    else
        echo "1) 启用优化方案 bbr+fq"
        echo "2) 启用优化方案 bbr+fq_pie"
        echo "3) 启用优化方案 bbr+cake"
    fi
    echo "7) 清理优化"
    echo "8) 退出"
    read -p "输入选项: " option
    case $option in
        1)
            apply_sysctl "bbr" "fq"
            ;;
        2)
            apply_sysctl "bbr" "fq_pie"
            ;;
        3)
            apply_sysctl "bbr" "cake"
            ;;
        4)
            [[ $support_bbr3 -eq 1 ]] && apply_sysctl "bbr3" "fq"
            ;;
        5)
            [[ $support_bbr3 -eq 1 ]] && apply_sysctl "bbr3" "fq_pie"
            ;;
        6)
            [[ $support_bbr3 -eq 1 ]] && apply_sysctl "bbr3" "cake"
            ;;
        7)
            clear_sysctl
            ;;
        8)
            exit 0
            ;;
        *)
            echo "无效选项，请重新选择。"
            menu
            ;;
    esac
}

menu
