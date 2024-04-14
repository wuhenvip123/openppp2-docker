#!/bin/bash

# 更新系统和安装必需的工具
setup_environment() {
    echo "更新系统和安装依赖..."
    apt update -y && apt install -y sudo screen unzip wget

    # 创建目录并进入
    mkdir -p /etc/ppp
    cd /etc/ppp
}

# 下载并安装PPP
install_ppp() {
    download_ppp
}

# 下载并更新PPP
update_ppp() {
    echo "正在更新PPP..."
    download_ppp
    echo "更新完成。请考虑重启PPP服务。"
}

# 通用的PPP下载和安装函数
download_ppp() {
    # 根据系统内核版本和架构下载合适的openppp2版本
    kernel_version=$(uname -r)
    arch=$(dpkg --print-architecture)
    echo "系统架构: $arch, 内核版本: $kernel_version"
    compare_kernel_version=$(echo -e "5.10\n$kernel_version" | sort -V | head -n1)

    if [[ $arch == "amd64" ]]; then
        if [[ $compare_kernel_version == "5.10" ]] && [[ $kernel_version != "5.10" ]]; then
            wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64-io-uring.zip -O openppp2.zip
        else
            wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip -O openppp2.zip
        fi
    elif [[ $arch == "arm64" ]]; then
        if [[ $compare_kernel_version == "5.10" ]] && [[ $kernel_version != "5.10" ]]; then
            wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-aarch64-io-uring.zip -O openppp2.zip
        else
            wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-aarch64.zip -O openppp2.zip
        fi
    fi

    # 解压并清理安装包
    echo "解压下载的文件..."
    unzip -o openppp2.zip && rm openppp2.zip
    chmod +x ppp
    echo "下载配置文件..."
    wget -O appsettings.json https://raw.githubusercontent.com/rebecca554owen/openppp2-docker/main/appsettings.json
    echo "请手动编辑配置文件以匹配您的设置：vim appsettings.json"
}

# 使用screen运行PPP
start_ppp() {
    screen -S ppp -dm /etc/ppp/ppp -m -s
    echo "ppp服务已在screen中启动。"
}

# 停止PPP服务
stop_ppp() {
    pkill -f ppp
    echo "ppp服务已停止。"
}

# 显示帮助
show_help() {
    echo "用法: $0 {install|start|stop|update|help}"
}

# 主菜单
case "$1" in
    install)
        setup_environment
        install_ppp
        ;;
    start)
        start_ppp
        ;;
    stop)
        stop_ppp
        ;;
    update)
        update_ppp
        ;;
    help|*)
        show_help
        ;;
esac
