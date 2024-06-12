#!/bin/bash

# 检查并加载 TCP 拥塞控制算法模块
check_and_load_module() {
    local qdisc=$1
    if ! sysctl net.ipv4.tcp_available_congestion_control | grep -qw $qdisc; then
        echo "尝试加载 $qdisc 模块..."
        if ! lsmod | grep -qw "tcp_$qdisc"; then
            modprobe tcp_$qdisc 2>/dev/null
        fi
        if ! sysctl net.ipv4.tcp_available_congestion_control | grep -qw $qdisc; then
            echo "错误: 拥塞控制算法 $qdisc 不可用。"
            return 1
        fi
    fi
    echo "拥塞控制算法 $qdisc 可用。"
    return 0
}

# 应用 sysctl 配置
apply_sysctl() {
    local qdisc=$1
    check_and_load_module $qdisc
    if [ $? -ne 0 ]; then
        echo "无法加载 $qdisc 模块，退出。"
        return 1
    fi

    # 先清除现有配置
    clear_sysctl_conf

    # 写入新的配置
    write_sysctl_conf $qdisc

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
    local qdisc=$1
    cat >> /etc/sysctl.conf << EOF
# TCP 拥塞控制
net.ipv4.tcp_congestion_control = $qdisc

# 其他网络优化参数
fs.file-max = $((1024 * 1024))
fs.inotify.max_user_instances = 8192
net.core.rmem_max = $((64 * 1024 * 1024))
net.core.wmem_max = $((64 * 1024 * 1024))
net.core.netdev_max_backlog = 100000
net.core.somaxconn = 1000000
net.core.optmem_max = 65536
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.lo.forwarding = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2
vm.swappiness = 10
vm.overcommit_memory = 1
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

# 菜单选项
menu() {
    echo "请选择优化方案:"
    echo "1) 启用优化方案 bbr+fq"
    echo "2) 启用优化方案 bbr+fq_pie"
    echo "3) 启用优化方案 bbr+cake (推荐)"
    echo "4) 清理优化"
    echo "5) 退出"
    read -p "输入选项: " option
    case $option in
        1)
            apply_sysctl "bbr" && apply_sysctl "fq"
            ;;
        2)
            apply_sysctl "bbr" && apply_sysctl "fq_pie"
            ;;
        3)
            apply_sysctl "bbr" && apply_sysctl "cake"
            ;;
        4)
            clear_sysctl
            echo "优化配置已清除。建议重启以生效。是否现在重启? 回车默认重启"
            read -p "输入选项: ( Y/n )" answer
            if [ -z "$answer" ] || [[ ! "$answer" =~ ^[Nn][Oo]?$ ]]; then
                reboot
            fi
            ;;
        5)
            exit 0
            ;;
        *)
            echo "无效选项，请重新选择。"
            menu
            ;;
    esac
}

menu
