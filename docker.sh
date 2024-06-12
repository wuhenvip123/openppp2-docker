#!/bin/bash

# 检查是否安装了Docker
if ! command -v docker &> /dev/null; then
    echo "Docker未安装，是否安装Docker？回车默认安装，请输入 yes 或 no "
    read install_docker
    if [[ "$install_docker" == "NO" || "$install_docker" == "no" || "$install_docker" == "N" || "$install_docker" == "n" ]]; then
        echo "未安装Docker，脚本退出。"
        exit 1
    else
        echo "正在安装Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        if [ $? -ne 0 ]; then
            echo "Docker安装失败，请检查网络连接或手动安装。"
            echo "curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun"
            exit 1
        fi
        echo "Docker安装成功。"
    fi
fi

selected_container=""
containers=()

# 列出所有容器并选择容器
select_container() {
    containers=($(docker ps -a --format "{{.ID}} {{.Names}} {{.Image}}"))
    if [ ${#containers[@]} -eq 0 ]; then
        echo "没有找到容器。"
        return 1
    elif [ ${#containers[@]} -eq 3 ]; then
        selected_container=${containers[0]}
        selected_container_name=${containers[1]}
        selected_container_image=${containers[2]}
        echo "自动选中唯一的容器: ID: $selected_container 名称: $selected_container_name 镜像: $selected_container_image"
        return 0
    else
        echo "所有容器："
        for ((i=0; i<${#containers[@]}; i+=3)); do
            echo "$((i/3+1)). ID: ${containers[i]} 名称: ${containers[i+1]} 镜像: ${containers[i+2]}"
        done
        read -p "输入要选择的容器序号（或按Enter返回主菜单）：" container_index
        if [[ -z "$container_index" ]]; then
            return 1
        elif [[ $container_index =~ ^[0-9]+$ ]] && [ $container_index -gt 0 ] && [ $container_index -le $(( ${#containers[@]} / 3 )) ]; then
            selected_container=${containers[((container_index-1)*3)]}
            selected_container_name=${containers[((container_index-1)*3+1)]}
            selected_container_image=${containers[((container_index-1)*3+2)]}
            echo "选中的容器: ID: $selected_container 名称: $selected_container_name 镜像: $selected_container_image"
            return 0
        else
            echo "无效的序号。"
            return 1
        fi
    fi
}

# 显示操作菜单
while true; do
    if [ -n "$selected_container" ]; then
        echo "当前选中的容器: ID: $selected_container 名称: $selected_container_name 镜像: $selected_container_image"
    else
        echo "当前没有选中的容器。"
    fi

    echo "请选择操作："
    echo "1. 列出并选择容器"
    echo "2. 启动容器"
    echo "3. 停止容器"
    echo "4. 重启容器"
    echo "5. 更新容器镜像"
    echo "6. 清空无用的镜像"
    echo "7. 退出"
    read -p "输入数字选择操作：" choice

    if [[ -z "$selected_container" && $choice -ne 1 && $choice -ne 7 ]]; then
        echo "请先选择一个容器。"
        select_container
        if [[ $? -ne 0 ]]; then
            continue
        fi
    fi

    case $choice in
        1)
            select_container
            ;;
        2)
            docker start $selected_container
            ;;
        3)
            docker stop $selected_container
            ;;
        4)
            docker restart $selected_container
            ;;
        5)
            read -p "输入要更新的容器镜像名称：" image_name
            docker pull $image_name
            if [ $? -eq 0 ]; then
                echo "重新创建使用新镜像的容器（注意：请根据实际情况修改启动参数）："
                docker stop $selected_container
                docker rm $selected_container
                docker run -d --name $selected_container_name $image_name
            else
                echo "镜像更新失败，请检查镜像名称或网络连接。"
            fi
            ;;
        6)
            docker image prune -f
            ;;
        7)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效的选择，请重新输入。"
            ;;
    esac
done
