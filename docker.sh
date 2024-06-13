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

# 获取容器列表并选择容器
select_container() {
    containers=($(docker ps -a --format "{{.ID}} {{.Names}} {{.Image}} {{.Status}}"))
    if [ ${#containers[@]} -eq 0 ]; then
        echo "没有找到容器。"
        return 1
    fi
    echo "所有容器："
    for ((i=0; i<${#containers[@]}; i+=4)); do
        echo "$((i/4+1)). ID: ${containers[i]} 名称: ${containers[i+1]} 镜像: ${containers[i+2]} 状态: ${containers[i+3]}"
    done
    read -p "输入要选择的容器序号：" container_index
    if [[ $container_index =~ ^[0-9]+$ ]] && [ $container_index -gt 0 ] && [ $container_index -le $(( ${#containers[@]} / 4 )) ]; then
        selected_container=${containers[((container_index-1)*4)]}
        selected_container_name=${containers[((container_index-1)*4+1)]}
        selected_container_image=${containers[((container_index-1)*4+2)]}
        selected_container_status=${containers[((container_index-1)*4+3)]}
        echo "选中的容器: ID: $selected_container 名称: $selected_container_name 镜像: $selected_container_image 状态: $selected_container_status"
        return 0
    else
        echo "无效的序号。"
        return 1
    fi
}

# 显示操作菜单
while true; do
    clear
    echo "请选择操作："
    echo "1. 启动容器"
    echo "2. 停止容器"
    echo "3. 重启容器"
    echo "4. 更新容器镜像"
    echo "5. 清空无用的镜像"
    echo "6. 查看容器日志"
    echo "7. 退出"
    read -p "输入数字选择操作：" choice

    case $choice in
        1|2|3|4|6|7)
            select_container
            if [[ $? -ne 0 ]]; then
                read -p "按任意键返回菜单..."
                continue
            fi
            ;;
    esac

    case $choice in
        1)
            docker start $selected_container
            if [[ $? -eq 0 ]]; then
                echo "容器启动成功。"
            else
                echo "容器启动失败。"
            fi
            ;;
        2)
            docker stop $selected_container
            if [[ $? -eq 0 ]]; then
                echo "容器停止成功。"
            else
                echo "容器停止失败。"
            fi
            ;;
        3)
            docker restart $selected_container
            if [[ $? -eq 0 ]]; then
                echo "容器重启成功。"
            else
                echo "容器重启失败。"
            fi
            ;;
        4)
            read -p "输入要更新的镜像名称：" image_name
            docker pull $image_name
            if [ $? -eq 0 ]; then
                echo "镜像更新成功。"
                container_config=$(docker inspect $selected_container --format='{{json .HostConfig}}')
                docker stop $selected_container
                docker rm $selected_container
                docker run -d --name $selected_container_name --restart unless-stopped $(echo $container_config | jq -r 'to_entries[] | "--" + .key + "=" + (.value|tostring)') $image_name
                if [[ $? -eq 0 ]]; then
                    echo "容器重新创建成功。"
                else
                    echo "容器重新创建失败。"
                fi
            else
                echo "镜像更新失败，请检查镜像名称或网络连接。"
            fi
            ;;
        5)
            docker image prune -f
            if [[ $? -eq 0 ]]; then
                echo "无用镜像清理成功。"
            else
                echo "无用镜像清理失败。"
            fi
            ;;
        6)
            docker logs $selected_container
            if [[ $? -eq 0 ]]; then
                echo "容器日志查看成功。"
            else
                echo "容器日志查看失败。"
            fi
            ;;
        7)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效的选择，请重新输入。"
            ;;
    esac
    read -p "按任意键返回菜单..."
done
