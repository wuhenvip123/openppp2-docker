# OpenPPP2 部署脚本，仅供自己学习sh脚本使用，用于解决同时连接多个VPS服务端。
1. 在Debian/Ubuntu系统的VPS上，复制下面的命令以二进制安装 `OpenPPP2` 服务端。  
```
bash <(curl -Ls https://raw.githubusercontent.com/rebecca554owen/openppp2-docker/main/start.sh)
```
输入 `1` 开始安装，一直回车保持默认或者根据需要自定义端口;  
输入 `7` 进入查看启动状态;按下 `Ctrl + a ` 再按 `d` 键 退出。
  
2.在本地局域网内的（虚拟机）Linux服务器执行下面的命令。
```
bash <(curl -Ls https://raw.githubusercontents.com/rebecca554owen/openppp2-docker/main/ppp.sh)
```
输入 `1` 开始安装，根据提示输入VPS的IP地址/端口。  
如果需要多开，自行修改 `/etc/ppp/docker-compose.yml` 文件，写多个不同端口服务即可。  
  
3.以上操作完毕，此时用 `nokebox` / `clash` / 'mihomo' 新建一个http协议的节点，服务器地址写步骤2中局域网内机器 ipv6 地址即可连接。

4.如果想要用ipv4连接，那么还需要做一些操作。
首先，开启ipv4转发。
编辑 /etc/sysctl.conf 文件，找到或添加以下行：
```
net.ipv4.ip_forward=1
```
检查是否生效
```
cat /proc/sys/net/ipv4/ip_forward
```
如果输出不是 1，则IP转发未启用。
接着使用命令添加iptabels规则。
```
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 127.0.0.1:8080
```
