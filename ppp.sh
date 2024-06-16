#!/bin/bash

ppp_dir="/etc/ppp" # 定义安装目录

# 检测操作系统
OS=""
if [ -f /etc/redhat-release ]; then
    OS="CentOS"
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

# 定义安装和管理PPP的函数
function install_ppp() {
    echo "检测到操作系统：$OS"
    
    # 根据操作系统选择合适的更新和安装命令
    case "$OS" in
        ubuntu | debian)
            echo "更新系统和安装依赖 (Debian/Ubuntu)..."
            apt update && apt install -y sudo screen unzip wget
            ;;
        centos)
            echo "更新系统和安装依赖 (CentOS)..."
            yum update -y && yum install -y sudo screen unzip wget
            ;;
        *)
            echo "不支持的操作系统"
            return 1
            ;;
    esac

    echo "创建目录并进入..."
    mkdir -p $ppp_dir
    cd $ppp_dir

    kernel_version=$(uname -r)
    arch=$(uname -m)
    echo "系统架构: $arch, 内核版本: $kernel_version"

    compare_kernel_version=$(echo -e "5.10\n$kernel_version" | sort -V | head -n1)

    # 定义不同架构和系统的URL
    if [[ $arch == "x86_64" ]]; then
        if [[ $compare_kernel_version == "5.10" ]] && [[ $kernel_version != "5.10" ]]; then
            default_url="https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64-io-uring.zip"
        else
            default_url="https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip"
        fi
    elif [[ $arch == "aarch64" ]]; then
        if [[ $compare_kernel_version == "5.10" ]] && [[ $kernel_version != "5.10" ]]; then
            default_url="https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-aarch64-io-uring.zip"
        else
            default_url="https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-aarch64.zip"
        fi
    fi

    echo "默认下载地址: $default_url"
    echo "是否使用默认下载地址? (Y/n):"
    read use_default
    
    # 将输入转换为小写以简化比较
    use_default=$(echo "$use_default" | tr '[:upper:]' '[:lower:]')
    
    # 只有当用户明确输入 'n' 或 'no' 时才请求输入新的下载地址
    if [[ "$use_default" == "n" || "$use_default" == "no" ]]; then
        echo "请输入新的下载地址:"
        read download_url
    else
        download_url="$default_url"
    fi

    echo "下载文件中..."
    wget "$download_url"
    echo "解压下载的文件..."
    unzip -o '*.zip' -x 'appsettings.json' && rm *.zip
    chmod +x ppp

# 选择模式
echo "请选择模式（默认为服务端）："
echo "1) 服务端"
echo "2) 客户端"
read -p "输入选择 (1 或 2，默认为1): " mode_choice

# 设置默认选项
mode_choice=${mode_choice:-1}

# 根据选择设置ExecStart和Restart策略
if [[ "$mode_choice" == "2" ]]; then
    exec_start="/usr/bin/screen -DmS ppp $ppp_dir/ppp --mode=client --tun-host=yes --tun-vnet=yes --tun-static=yes --block-quic=no --set-http-proxy=yes"
    restart_policy="no"
else
    exec_start="/usr/bin/screen -DmS ppp $ppp_dir/ppp --mode=server"
    restart_policy="always"
fi

# 配置系统服务
echo "配置系统服务..."
cat > /etc/systemd/system/ppp.service << EOF
[Unit]
Description=PPP Service with Screen
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$ppp_dir
ExecStart=$exec_start
Restart=$restart_policy
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    modify_config # 检测配置是否存在并编辑配置文件
    start_ppp
    echo "PPP服务已配置并启动。"
    show_menu
}

function uninstall_ppp() {
    echo "停止并卸载PPP服务..."
    sudo systemctl stop ppp.service
    sudo systemctl disable ppp.service
    sudo rm -f /etc/systemd/system/ppp.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
    echo "删除安装文件..."

    # 获取PPP进程的PID
    pids=$(pgrep ppp)
    
    # 检查是否有PID返回
    if [ -z "$pids" ]; then
        echo "没有找到PPP进程。"
    else
        echo "找到PPP进程，正在杀死..."
        kill $pids
        echo "已发送终止信号到PPP进程。"
    fi

    sudo rm -rf $ppp_dir
    echo "PPP服务已完全卸载。"
}

function start_ppp() {
    sudo systemctl enable ppp.service
    sudo systemctl daemon-reload
    sudo systemctl start ppp.service
    echo "PPP服务已启动。"
}

function stop_ppp() {
    sudo systemctl stop ppp.service
    echo "PPP服务已停止。"
}

function restart_ppp() {
    sudo systemctl daemon-reload
    sudo systemctl restart ppp.service
    echo "PPP服务已重启。"
}

function update_ppp() {
    echo "正在停止PPP服务以进行更新..."
    stop_ppp
    echo "更新PPP服务中..."
    install_ppp
    echo "重启PPP服务..."
    restart_ppp
    echo "PPP服务已更新并重启。"
}

function view_ppp_session() {
    echo "查看PPP会话..."
    screen -r ppp
    echo "提示：使用 'Ctrl+a d' 来detach会话而不是关闭它。"
}

function modify_config() {
    ppp_config="${ppp_dir}/appsettings.json"
    if [ -f "${ppp_config}" ]; then
        echo -e "检测到已存在${ppp_config}配置文件。"
        read -p "是否要编辑现有的配置文件？[Y/n]: " edit_choice
        if [[ $edit_choice =~ ^[Yy]$ ]]; then
                vim "${ppp_config}"
                echo -e "${ppp_config}配置文件修改成功。"
                restart_ppp
                return
            else
            echo -e "${green}不修改${ppp_config}配置文件。${plain}"
            return
        fi
    else
    # 如果配置文件不存在，则重新生成配置文件
    echo -e "重新生成${ppp_config}。"
    # 检测公网出口/内网IP来提示用户
    curl -m 10 -s ip.sb
    ip addr | grep 'inet ' | grep -v ' lo' | awk '{print $2}' | cut -d/ -f1
    default_vps_ip="::"
    read -p "请输入VPS IP地址（默认为${default_vps_ip}，服务端保持默认值即可）: " vps_ip
    vps_ip=${vps_ip:-$default_vps_ip}
    while true; do
        read -p "请输入VPS 端口 [默认: 2024]: " port
        port=${port:-2024}
    
        if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1000 ] && [ "$port" -le 65535 ]; then
            break
        else
            echo "输入的端口无效。请确保它是在1000到65535的范围内。"
        fi
    done
    # 设置监听Interface的默认值::用于ipv6
    default_lan_ip="::"
    read -p "请输入内网IP地址（默认为${default_lan_ip}，服务端保持默认值即可）: " lan_ip
    lan_ip=${lan_ip:-$default_lan_ip}
    # 设置线程数，随机uuid，避免多客户端时候冲突。
    concurrent=$(nproc)
    random_guid=$(uuidgen)
    
    echo -e " 节点 ${vps_ip}:${port} 线程数 ${concurrent} 用户ID ${random_guid} "
    
    cat >"${ppp_config}" <<EOF
{
    "concurrent": ${concurrent},
    "key": {
        "kf": 154543927,
        "kx": 128,
        "kl": 10,
        "kh": 12,
        "protocol": "aes-128-cfb",
        "protocol-key": "N6HMzdUs7IUnYHwq",
        "transport": "aes-256-cfb",
        "transport-key": "HWFweXu2g5RVMEpy",
        "masked": false,
        "plaintext": false,
        "delta-encode": false,
        "shuffle-data": false
    },
    "ip": {
        "public": "${vps_ip}",
        "interface": "${lan_ip}"
    },
    "vmem": {
        "size": 0,
        "path": "./"
    },
    "tcp": {
        "inactive": {
            "timeout": 300
        },
        "connect": {
            "timeout": 5
        },
        "listen": {
            "port": ${port}
        },
        "turbo": true,
        "backlog": 511,
        "fast-open": true
    },
    "udp": {
        "inactive": {
            "timeout": 72
        },
        "dns": {
            "timeout": 4,
            "redirect": "0.0.0.0"
        },
        "listen": {
            "port": ${port}
        },
        "static": {
            "keep-alive": [1, 5],
            "dns": true,
            "quic": true,
            "icmp": true,
            "aggligator": 0,
            "servers": ["${vps_ip}:${port}"]
        }
    },
    "websocket": {
        "host": "starrylink.net",
        "path": "/tun",
        "listen": {
            "ws": 2095,
            "wss": 2096
        },
        "ssl": {
            "certificate-file": "starrylink.net.pem",
            "certificate-chain-file": "starrylink.net.pem",
            "certificate-key-file": "starrylink.net.key",
            "certificate-key-password": "test",
            "ciphersuites": "TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256"
        },
        "verify-peer": true,
        "http": {
            "error": "Status Code: 404; Not Found",
            "request": {
                "Cache-Control": "no-cache",
                "Pragma": "no-cache",
                "Accept-Encoding": "gzip, deflate",
                "Accept-Language": "zh-CN,zh;q=0.9",
                "Origin": "http://www.websocket-test.com",
                "Sec-WebSocket-Extensions": "permessage-deflate; client_max_window_bits",
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0"
            },
            "response": {
                "Server": "Kestrel"
            }
        }
    },
    "server": {
        "log": "/dev/null",
        "node": 1,
        "subnet": true,
        "mapping": false,
        "backend": "",
        "backend-key": "HaEkTB55VcHovKtUPHmU9zn0NjFmC6tff"
    },
    "client": {
        "guid": "{${random_guid}}",
        "server": "ppp://${vps_ip}:${port}/",
        "bandwidth": 0,
        "reconnections": {
            "timeout": 5
        },
        "paper-airplane": {
            "tcp": true
        },
        "http-proxy": {
            "bind": "${lan_ip}",
            "port": ${port}
        },
        "mappings": [
            {
                "local-ip": "${lan_ip}",
                "local-port": 10000,
                "protocol": "tcp",
                "remote-ip": "::",
                "remote-port": 10000
            },
            {
                "local-ip": "${lan_ip}",
                "local-port": 10000,
                "protocol": "udp",
                "remote-ip": "::",
                "remote-port": 10000
            }
        ]
    }
}
EOF
    restart_ppp
    fi
    echo -e "${ppp_config}配置文件生成成功。"
}

# 显示菜单并处理用户输入
function show_menu() {
    PS3='请选择一个操作: '
    options=("安装PPP" "启动PPP" "停止PPP" "重启PPP" "更新PPP" "卸载PPP" "查看PPP会话" "修改配置文件" "退出")
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
            "卸载PPP")
                uninstall_ppp
                ;;
            "查看PPP会话")
                view_ppp_session
                ;;
            "修改配置文件")
                modify_config
                ;;
            "退出")
                break
                ;;
            *) echo "无效选项 $REPLY";;
        esac
    done
}

# 脚本入口
show_menu
