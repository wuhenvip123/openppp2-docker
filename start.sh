#!/bin/bash

# 更新系统和安装必需的工具
echo "更新系统和安装依赖..."
apt update -y && apt install -y sudo screen unzip wget

# 创建目录并进入
mkdir -p /etc/ppp
cd /etc/ppp

# 根据系统内核版本和架构下载合适的openppp2版本
kernel_version=$(uname -r)
arch=$(dpkg --print-architecture)
echo "系统架构: $arch, 内核版本: $kernel_version"

# 自动选择下载地址
compare_kernel_version=$(echo -e "5.10\n$kernel_version" | sort -V | head -n1)
default_url=""

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

# 提示用户是否使用默认地址或输入新地址
echo "默认下载地址: $default_url"
echo "您是否想使用默认下载地址? 输入 'no' 以输入新的下载地址: "
read use_default

if [[ "$use_default" != "no" ]]; then
    download_url="$default_url"
else
    echo "请输入新的下载地址:"
    read download_url
fi

# 下载文件
echo "下载文件中..."
wget "$download_url"

# 解压并清理安装包
echo "解压下载的文件..."
unzip -o '*.zip' && rm *.zip
chmod +x ppp

# 下载并编辑配置文件
echo "下载配置文件..."
wget -O appsettings.json https://raw.githubusercontent.com/rebecca554owen/openppp2-docker/main/appsettings.json
echo "请手动编辑配置文件以匹配您的设置：vim appsettings.json"

# 配置系统服务
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

# 启用并启动服务
echo "启用并启动PPP服务..."
sudo systemctl enable ppp.service
sudo systemctl daemon-reload
sudo systemctl start ppp.service
sudo systemctl status ppp.service

echo "PPP服务已配置并启动。"
echo "运行 screen -r ppp 命令随时连接到 ppp 进程的 screen 会话 "
