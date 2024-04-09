#!/bin/bash
# 自用脚本，用于安装和配置。
# 仅测试于 Debian / Ubuntu 平台。
ppp_path="/etc/ppp"
ppp_name="openppp2"

# 颜色全局变量
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

install_ppp() {
pre_setup
get_ip_info
check_and_install_docker
setup_directory_and_name
select_mode_and_configure
generate_ppp_docker_compose
create_or_modify_ppp_config
}

# 环境准备
pre_setup() {
    # 检查是否为Alpine Linux
    if grep -q 'ID=alpine' /etc/os-release; then
        echo -e "${red}" "错误: 本脚本不支持Alpine Linux。${plain}"
        exit 1
    fi

    # 检查是否为CentOS
    if grep -q 'ID=centos' /etc/os-release; then
        echo -e "${yellow}" "检测到CentOS系统，正在为CentOS安装必需的软件包...${plain}"
        yum install -y sudo curl vim
        echo -e "${green}" "所需软件安装完成。${plain}"
    else
        # 默认为Debian/Ubuntu系统
        echo -e "${yellow}" "正在安装必需的软件包...${plain}"
        apt-get update
        apt-get install -y sudo curl vim
        echo -e "${green}" "所需软件安装完成。${plain}"
    fi
}

# 获取IP信息判断是否在中国
get_ip_info() {
    local ip_info=$(curl -m 10 -s https://ipapi.co/json)
    if [[ $? -ne 0 ]]; then
        echo -e "${yellow}" "警告: 无法从 ipapi.co 获取IP信息。您需要手动指定是否使用中国镜像。${plain}"
        read -p "您是否在中国？如果是请输入 'Y',否则输入 'N': [Y/n] " input
        [[ "${input}" =~ ^[Yy]$ ]] && echo "Y" || echo "N"
    else
        if echo -e "${ip_info}" | grep -q 'China'; then
            echo "Y"
        else
            echo "N"
        fi
    fi
}

# 检查和安装 Docker
check_and_install_docker() {
    # 检查 Docker 是否已安装
    if command -v docker >/dev/null; then
        echo -e "${green}" "Docker 已安装。${plain}"
        return  # 直接返回，不进行安装
    fi

    local use_cn_mirror=$(get_ip_info)
    if [ "${use_cn_mirror}" == "Y" ]; then
        echo -e "${yellow}" "检测到您可能在中国，将使用中国镜像加速Docker安装。${plain}"
        curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
    else
        echo -e "${yellow}" "未检测到您在中国，正常安装Docker。${plain}"
        curl -fsSL https://get.docker.com | sh
    fi
    systemctl enable docker
    systemctl start docker
    echo -e "${green}" "Docker 安装完成。${plain}"
}

# 设置默认的配置路径和名称，并确认目录是否存在
setup_directory_and_name() {
    if [ ! -d "${ppp_path}" ]; then
        echo -e "${yellow}" "未找到配置路径，开始新建: ${ppp_path} 目录 ${plain}"
        mkdir -p "${ppp_path}"
    else
        echo -e "${green}" "配置路径已存在: ${ppp_path} ${plain}"
    fi
    chmod 755 -R "${ppp_path}"
}
# 用户选择模式并配置
select_mode_and_configure() {
    echo -e "请选择运行模式："
    select mode in "server" "client"; do
        case ${REPLY} in
            1|2) echo -e "您选择了 ${mode} 模式。"; break;;
            *) echo -e "无效的选择，请重新选择。"; continue;;
        esac
    done
}

# 检查 Docker Compose 命令
get_docker_compose_cmd() {
    if docker compose version &>/dev/null; then
        # Docker Compose V2
        echo "docker compose"
    elif docker-compose --version &>/dev/null; then
        # Docker Compose V1
        echo "docker-compose"
    else
        echo -e "${red}" "未找到 Docker Compose 命令。${plain}"
        exit 1
    fi
}

# 执行 Docker Compose 操作
docker_compose_action() {
    local action=$1
    local compose_cmd=$(get_docker_compose_cmd)

    cd "${ppp_path}" || { echo -e "${red}错误：无法进入 ${ppp_path} 目录${plain}"; exit 1; }

    if [[ $compose_cmd == "docker compose" ]]; then
        docker compose $action || { echo -e "${red}Docker Compose V2 操作失败${plain}"; exit 1; }
    else
        $compose_cmd $action || { echo -e "${red}Docker Compose V1 操作失败${plain}"; exit 1; }
    fi
}

start_ppp() {
    echo -e "启动${ppp_name}...${plain}"
    docker_compose_action "up -d"
    echo -e "${ppp_name}已启动。${plain}"
    before_show_menu
}

stop_ppp() {
    echo -e "停止${ppp_name}...${plain}"
    docker_compose_action "down"
    echo -e "${ppp_name}已停止。${plain}"
    before_show_menu
}

restart_ppp_update() {
    echo -e "重启${ppp_name}...${plain}"
    docker_compose_action "pull"
    docker_compose_action "up -d"
    echo -e "${ppp_name}已重启。${plain}"
    docker image prune -f -a
    before_show_menu
}

show_ppp_log() {
    echo -e ">> 正在获取${ppp_name}日志，正常启动则无日志"
    docker_compose_action "logs -f"
    before_show_menu
}

uninstall_ppp() {
    echo -e ">> 卸载${ppp_name}"
    docker_compose_action "down"
    if [[ -d "${ppp_path}" ]]; then
        rm -rf "${ppp_path}"
        echo -e "${ppp_path} 已删除。"
    fi
    docker rm ${ppp_name} &>/dev/null
    docker rmi $(docker images -q rebecca554owen/${ppp_name}) &>/dev/null || echo -e "Docker 镜像可能已被删除。"
    echo -e "${ppp_name}已卸载。"
    before_show_menu
}

before_show_menu() {
    echo -e "\n${yellow}* 按任意键返回主菜单 *${plain}"
    read -r -n1 -s
    echo -e
    show_menu
}

show_menu() {
    echo -e "
    ${green}自用${ppp_name}脚本${plain} ${red}${plain}
    ————————————————
    ${green}1.${plain} 安装${ppp_name}
    ${green}2.${plain} 修改${ppp_name}配置
    ${green}3.${plain} 启动${ppp_name}
    ${green}4.${plain} 停止${ppp_name}
    ${green}5.${plain} 重启${ppp_name}
    ${green}6.${plain} 查看${ppp_name}日志
    ${green}7.${plain} 卸载${ppp_name}
    ————————————————
    ${green}0.${plain} 退出脚本
    "
    echo -e && read -r -ep "请输入选择: " num
    case ${num} in
        1) install_ppp ;;
        2) create_or_modify_ppp_config ;;
        3) start_ppp ;;
        4) stop_ppp ;;
        5) restart_ppp_update ;;
        6) show_ppp_log ;;
        7) uninstall_ppp ;;
        0) exit 0 ;;
        *) echo -e "${red}" "无效选择，请重新选择。${plain}" ;;
    esac
    before_show_menu
}

# 根据用户选择的模式来生成不同的配置文件
generate_ppp_docker_compose() {
    ppp_docker="${ppp_path}/docker-compose.yml"
    # 检查 ${ppp_docker} 文件是否存在
    if [ -f "${ppp_docker}" ]; then
        echo -e "${yellow}" "检测到已存在的 ${ppp_docker} 配置文件。${plain}"
        read -p "是否要编辑现有的${ppp_docker}配置文件？[Y/n]: " input
        if [[ "$input" =~ ^[Yy]$ ]]; then
            # 用户选择编辑文件，使用 vim 打开文件
            vim "${ppp_docker}"
            echo -e "${green}" "${ppp_docker}配置文件编辑完成。${plain}"
        else
            echo -e "${yellow}" "跳过编辑${ppp_docker}配置文件。${plain}"
            return # 如果用户选择不编辑，则返回。
        fi
    else
    echo -e "${green}" "已经按 ${mode} 模式生成 ${ppp_docker}配置文件。${plain}"   
    if [[ ${mode} == "server" ]]; then
    cat >"${ppp_docker}" <<EOF
services:
  ${ppp_name}:
    image: rebecca554owen/${ppp_name}:latest
    container_name: ${ppp_name}
    restart: always
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - ./appsettings.json:/${ppp_name}/appsettings.json
    network_mode: host
    command: ppp --mode=server
EOF
    else
    cat >"${ppp_docker}" <<EOF
# Client模式，注意：避免使用restart: always以防重启后失联
services:
  ${ppp_name}:
    image: rebecca554owen/${ppp_name}:latest
    container_name: ${ppp_name}
    restart: no
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - ./appsettings.json:/${ppp_name}/appsettings.json
    ports:
      - "8080:8080"
    networks:
      - ${ppp_name}network
    command: ppp --mode=client --tun-static=yes --block-quic=no --set-http-proxy=yes
# 定义网络
networks:
  openpppnetwork:
    driver: bridge
    # enable_ipv6: true # 是否启用IPv6
    ipam:
      driver: default
      config:
        - subnet: 172.20.0.0/24
        # - subnet: 2001:db8:1::/64 # 定义IPv6子网
EOF
    fi        
    fi
}

create_or_modify_ppp_config() {
    ppp_config="${ppp_path}/appsettings.json"
    if [ -f "${ppp_config}" ]; then
        echo -e "${yellow}检测到已存在${ppp_config}配置文件。${plain}"
        read -p "是否要编辑现有的配置文件？[Y/n]: " edit_choice
        
        if [[ $edit_choice =~ ^[Yy]$ ]]; then
            vim "${ppp_config}"
            echo -e "${green}${ppp_config}配置文件修改成功。${plain}"
            restart_ppp_update
            return
        fi
        
    fi

    # 如果选择重新生成配置文件，或配置文件不存在
    echo -e "${yellow}重新生成${ppp_config}。${plain}"
    read -p "请输入VPS IP: " vps_ip
    read -p "请输入VPS 端口: " port

    # 设置内网IP的默认值并提示用户
    default_lan_ip="::"
    read -p "请输入内网IP地址（默认为${default_lan_ip}，服务端保持默认值即可）: " lan_ip
    lan_ip=${lan_ip:-$default_lan_ip}

    cat >"${ppp_config}" <<EOF
{
    "concurrent": 1,
    "cdn": [2080, 2443],
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
            "servers": ["${vps_ip}:${port}"]
        }
    },
    "websocket": {
        "host": "starrylink.net",
        "path": "/tun",
        "listen": {
            "ws": 20080,
            "wss": 20443
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
        "log": "./ppp.log",
        "node": 1,
        "subnet": true,
        "mapping": true,
        "backend": "",
        "backend-key": "HaEkTB55VcHovKtUPHmU9zn0NjFmC6tff"
    },
    "client": {
        "guid": "{F4569208-BB45-4DEB-B115-0FEA1D91B85B}",
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
            "port": 8080
        },
        "mappings": [
            {
                "local-ip": "${lan_ip}",
                "local-port": 80,
                "protocol": "tcp",
                "remote-ip": "::",
                "remote-port": 10001
            },
            {
                "local-ip": "${lan_ip}",
                "local-port": 7000,
                "protocol": "udp",
                "remote-ip": "::",
                "remote-port": 10002
            }
        ]
    }
}
EOF
    echo -e "${green}${ppp_config}配置文件生成成功。${plain}"
    restart_ppp_update
}

show_menu
