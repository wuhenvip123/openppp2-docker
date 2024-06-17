#!/bin/bash

# 列出所有网卡，排除lo网卡
echo "Available network interfaces (excluding 'lo'):"
ip link show | grep -v lo | grep -oP '(?<=: ).*?(?=:)' | awk '{print "- " $1}'
echo ""

# 让用户确认选择哪个网卡
read -p "Enter the interface name to monitor (e.g., eth0): " interface_name
interface_name=${interface_name:-eth0}  # 默认为eth0

# 检查输入的网卡名是否有效
if ! ip link show "$interface_name" > /dev/null 2>&1; then
  echo "Error: Network interface $interface_name does not exist."
  exit 1
fi

# 提示输入每月起始日期，设默认值为1
read -p "Enter the start day of the month for monitoring (1-31, default 1): " month_start_day
month_start_day=${month_start_day:-1}

# 检查起始日期是否在合理范围内
if ! [[ "$month_start_day" =~ ^[1-9]$|^[12][0-9]$|^3[01]$ ]]; then
  echo "Error: Invalid start day of the month."
  exit 1
fi

# 提示输入流量上限，默认为1TB
read -p "Enter the traffic limit in TB (default 1): " traffic_limit
traffic_limit=${traffic_limit:-1}

# 检查流量上限是否是正数
if ! [[ "$traffic_limit" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Error: Invalid traffic limit."
  exit 1
fi

# 转换流量上限为GB
traffic_limit_gb=$(echo "$traffic_limit * 1024" | bc)

# 更新vnstat配置
sudo sed -i.bak "/^Interface/d" /etc/vnstat.conf
sudo sed -i "/^MonthRotate/d" /etc/vnstat.conf
echo "Interface \"$interface_name\"" | sudo tee -a /etc/vnstat.conf
echo "MonthRotate $month_start_day" | sudo tee -a /etc/vnstat.conf
sudo systemctl restart vnstat

# 自动关机脚本
cat << 'EOF' > shutdown.sh
#!/bin/bash
interface_name="$1"
traffic_limit_gb="$2"

# 更新网卡记录
vnstat -i "$interface_name"
# 获取每月用量 $11:进站+出站
ax=$(vnstat --oneline | awk -F ";" '{print $11}')
log_file="/tmp/cron_shutdown_debug.log"

echo "$(date): Checking traffic for $interface_name, current usage: $ax" >> "$log_file"

# 如果每月用量单位是GB则进入
if [[ "$ax" == *GB* ]]; then
  # 每月实际流量数除以流量阈值，大于或等于1，则执行关机命令
  usage=$(echo "$ax" | sed 's/ GB//g')
  if (( $(echo "$usage >= $traffic_limit_gb" | bc -l) )); then
    echo "$(date): Traffic limit exceeded, shutting down." >> "$log_file"
    sudo /usr/sbin/shutdown -h now
  else
    echo "$(date): Traffic is within the limit." >> "$log_file"
  fi
else
  echo "$(date): Traffic unit is not GB, skipping check." >> "$log_file"
fi
EOF

# 授予执行权限
chmod +x check.sh

# 设置定时任务，每5分钟执行一次检查
(crontab -l 2>/dev/null; echo "*/5 * * * * /bin/bash $(pwd)/check.sh $interface_name $traffic_limit_gb > /tmp/cron_shutdown_debug.log 2>&1") | crontab -

echo "Setup complete!"
