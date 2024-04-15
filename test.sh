#!/bin/bash

# 使用curl从外部服务获取当前服务器的公网IP
default_serverIP=$(curl -s http://ipinfo.io/ip)

# 如果curl命令失败，则回退到一个硬编码的默认IP
if [ -z "$default_serverIP" ]; then
    default_serverIP="10.0.0.1"
fi

# 提示用户输入VPS IP地址，提供从外部服务获取的IP作为默认值
read -p "请输入 VPS IP 地址 [默认: $default_serverIP]: " serverIP
serverIP=${serverIP:-$default_serverIP}

echo "使用的 VPS IP 地址为: $serverIP"


# 用户输入测试次数，默认为 1
read -p "请输入测试次数 [默认: 1]: " count
count=${count:-1}

# 用户输入测试时长，默认为 60 秒
read -p "请输入测试时长（秒）[默认: 60]: " time
time=${time:-60}

# 用户选择的测试类型
echo "请选择测试类型:"
echo "1. TCP_STREAM"
echo "2. UDP_STREAM"
echo "3. TCP_RR"
echo "4. TCP_CRR"
echo "5. UDP_RR"
echo "6. 全部测试"
read -p "输入选项 (1-6): " test_choice

# 根据用户选择执行测试
run_test() {
    local test_type=$1
    echo "开始测试: $test_type"
    netperf -t $test_type -H ${serverIP} -l ${time}
    echo "测试结束: $test_type"
    echo "-----------"
}

for ((i=1; i<=count; i++))
do
    echo "Instance: $i-------"
    case $test_choice in
        1)
            run_test "TCP_STREAM"
            ;;
        2)
            run_test "UDP_STREAM"
            ;;
        3)
            run_test "TCP_RR"
            ;;
        4)
            run_test "TCP_CRR"
            ;;
        5)
            run_test "UDP_RR"
            ;;
        6)
            run_test "TCP_STREAM"
            run_test "UDP_STREAM"
            run_test "TCP_RR"
            run_test "TCP_CRR"
            run_test "UDP_RR"
            ;;
        *)
            echo "无效的选择。"
            exit 1
            ;;
    esac
done
