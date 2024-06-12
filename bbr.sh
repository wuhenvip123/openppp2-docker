#!/bin/bash

# 系统优化脚本

optimize_system() {
    # 确保 sysctl 配置文件存在
    local sysctl_file="/etc/sysctl.conf"
    [ ! -f "$sysctl_file" ] && touch "$sysctl_file"

    # 清理已有配置
    sed -i '/net.ipv4.tcp/d' $sysctl_file
    sed -i '/fs.file-max/d' $sysctl_file
    sed -i '/fs.inotify.max_user_instances/d' $sysctl_file
    sed -i '/net.core/d' $sysctl_file
    sed -i '/vm.swappiness/d' $sysctl_file

    # 添加新的系统配置
    cat >> $sysctl_file << EOF
# 系统文件描述符限制
fs.file-max = 1048575
fs.inotify.max_user_instances = 8192

# 网络核心配置
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 100000
net.core.somaxconn = 1000000
net.core.default_qdisc = cake
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
net.ipv4.tcp_congestion_control = bbr3
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

# ARP配置
net.ipv4.neigh.default.gc_thresh1 = 128
net.ipv4.neigh.default.gc_thresh2 = 512
net.ipv4.neigh.default.gc_thresh3 = 4096
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2

# 内核设置
kernel.panic = 1
kernel.pid_max = 32768
kernel.shmmax = 4294967296
kernel.shmall = 1073741824
kernel.core_pattern = core_%e
vm.panic_on_oom = 1

EOF

    # 应用系统配置
    sysctl -p
    sysctl --system

    # 设置文件描述符限制
    cat > /etc/security/limits.conf << EOF
* soft nofile 1048575
* hard nofile 1048575
* soft nproc unlimited
* hard nproc unlimited
* soft core unlimited
* hard core unlimited
EOF

    # 设置ulimit
    sed -i '/ulimit -SHn/d' /etc/profile
    echo "ulimit -SHn 1048575" >> /etc/profile

    # 确保PAM限制模块被正确加载
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi

    # 系统守护进程重新加载
    systemctl daemon-reload

    echo "优化配置已应用，建议重启系统以完全生效。"
}

# 运行优化函数
optimize_system
