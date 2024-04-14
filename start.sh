#!/bin/bash

# 定义安装和管理PPP的函数
function install_ppp() {
    echo "更新系统和安装依赖..."
    apt update -y && apt install -y sudo screen unzip wget

    echo "创建目录并进入..."
    mkdir -p /etc/ppp
    cd /etc/ppp

    kernel_version=$(uname -r)
    arch=$(dpkg --print-architecture)
    echo "系统架构: $arch, 内核版本: $kernel_version"

    compare_kernel_version=$(echo -e "5.10\n$kernel_version" | sort -V | head -n1)

    if [[ $arch == "amd64" ]]; then
        if [[ $compare_kernel_version == "5.10" ]] && [[ $kernel_version != "5.10" ]]; then
            default_url="https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64-io-uring.zip"
        else
            default_url="https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip"
        fi
    elif [[ $arch == "arm64" ]]; then
        if [[ $compare_kernel_version == "5.10" ]] && [[ $kernel_version != "5.10" ]]; then
            default_url="https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-aarch64-io-uring.zip"
        else
            default_url="https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-aarch64.zip"
        fi
    fi

    echo "默认下载地址: $default_url"
    echo "您是否想使用默认下载地址? 输入 'no' 以输入新的下载地址: "
    read use_default

    if [[ "$use_default" != "no" ]]; then
        download_url="$default_url"
    else
        echo "请输入新的下载地址:"
        read download_url
    fi

    echo "下载文件中..."
    wget "$download_url"
    echo "解压下载的文件..."
    unzip -o '*.zip' && rm *.zip
    chmod +x ppp

    echo "下载配置文件..."
    wget -O appsettings.json https://raw.githubusercontent.com/rebecca554owen/openppp2-docker/main/appsettings.json
    echo "请手动编辑配置文件以匹配您的设置：vim appsettings.json"

    echo "配置系统服务..."
    cat > /etc/systemd/system/ppp.service << EOF
[Unit]
Description=PPP Service with Screen
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/ppp
ExecStart=/usr/bin/screen -DmS ppp /etc/ppp/ppp -m -s
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    echo "启用并启动PPP服务..."
    sudo systemctl enable ppp.service
    sudo systemctl daemon-reload
    sudo systemctl start ppp.service
    sudo systemctl status ppp.service
    echo "PPP服务已配置并启动。"
}

function start_ppp() {
    sudo systemctl start ppp.service
    echo "PPP服务已启动。"
}

function stop_ppp() {
    sudo systemctl stop ppp.service
    echo "PPP服务已停止。"
}

function restart_ppp() {
    sudo systemctl restart ppp.service
    echo "PPP服务已重启。"
}

function update_ppp() {
    echo "更新PPP服务..."
    install_ppp
}

function view_ppp_session() {
    echo "查看PPP会话..."
    screen -r ppp
}

# 显示菜单并处理用户输入
PS3='请选择一个操作: '
options=("安装PPP" "启动PPP" "停止PPP" "重启PPP" "更新PPP" "查看PPP会话" "退出")
select opt in "${options[@]}"
do
    case $opt in
        "安装PPP")
            install_ppp
            ;;
        "启动PPP")
            start_ppp
            ;;
        "停止PPP")
            stop_ppp
            ;;
        "重启PPP")
            restart_ppp
            ;;
        "更新PPP")
            update_ppp
            ;;
        "查看PPP会话")
            view_ppp_session
            ;;
        "退出")
            break
            ;;
        *) echo "无效选项 $REPLY";;
    esac
done
