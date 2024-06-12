#!/bin/bash

# 检查是否安装了Docker
if ! command -v docker &> /dev/null
then
    echo "Docker未安装。是否安装Docker？(yes/no)"
    read install_docker
    if [ "$install_docker" == "yes" ]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        if [ $? -ne 0 ]; then
            echo "Docker安装失败，请检查网络连接或手动安装。"
            exit 1
        fi
        echo "Docker安装成功。"
    else
        echo "未安装Docker，脚本退出。"
        exit 1
    fi
fi

selected_container=""

# 显示操作菜单
while true; do
    if [ -n "$selected_container" ]; then
        echo "当前选中的容器: $selected_container"
    else
        echo "当前没有选中的容器。"
    fi
    
    echo "请选择操作："
    echo "1. 列出所有容器"
    echo "2. 选择容器"
    echo "3. 启动容器"
    echo "4. 停止容器"
    echo "5. 重启容器"
    echo "6. 更新容器镜像"
    echo "7. 清空无用的镜像"
    echo "8. 退出"
    read -p "输入数字选择操作：" choice

    case $choice in
        1)
            docker ps -a
            ;;
        2)
            echo "所有容器："
            docker ps -a --format "table {{.ID}}\t{{.Names}}"
            read -p "输入要选择的容器ID或名称：" selected_container
            ;;
        3)
            if [ -n "$selected_container" ]; then
                docker start $selected_container
            else
                echo "请先选择一个容器。"
            fi
            ;;
        4)
            if [ -n "$selected_container" ]; then
                docker stop $selected_container
            else
                echo "请先选择一个容器。"
            fi
            ;;
        5)
            if [ -n "$selected_container" ]; then
                docker restart $selected_container
            else
                echo "请先选择一个容器。"
            fi
            ;;
        6)
            if [ -n "$selected_container" ]; then
                read -p "输入要更新的容器镜像名称：" image_name
                docker pull $image_name
                echo "重新创建使用新镜像的容器（注意：请根据实际情况修改启动参数）："
                docker stop $selected_container
                docker rm $selected_container
                docker run -d --name $selected_container $image_name
            else
                echo "请先选择一个容器。"
            fi
            ;;
        7)
            docker image prune -f
            ;;
        8)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效的选择，请重新输入。"
            ;;
    esac
done
