#!/bin/bash

# 用户输入 VPS IP 地址，默认为 10.0.0.1
read -p "请输入 VPS IP 地址 [默认: 10.0.0.1]: " serverIP
serverIP=${serverIP:-10.0.0.1}

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
