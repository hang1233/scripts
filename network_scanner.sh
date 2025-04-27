#!/bin/bash

# 定义颜色变量
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # 无颜色

# 显示脚本使用帮助
show_help() {
  echo -e "${YELLOW}内网主机扫描工具${NC}"
  echo -e "用法: $0 [网段]"
  echo -e "示例: $0 192.168.1"
  echo -e "      $0 10.0.0"
  echo -e "格式: 前三段IP地址，如192.168.1"
  echo -e "注意: 将扫描指定网段的1-254主机"
}

# 检查参数
if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
  exit 0
fi

# 验证IP格式
IP_REGEX='^([0-9]{1,3}\.){2}[0-9]{1,3}$'
if ! [[ $1 =~ $IP_REGEX ]]; then
  echo -e "${RED}错误: 无效的IP网段格式${NC}"
  echo -e "请使用格式: 192.168.1"
  exit 1
fi

network=$1
# 创建临时文件用于记录在线主机
temp_file=$(mktemp)

echo -e "${YELLOW}开始扫描网段 ${network}.1 至 ${network}.254...${NC}"
echo -e "${YELLOW}实时显示在线主机:${NC}"
echo "----------------------------------------"

# 使用并行处理提高扫描速度
for i in {1..254}; do
  # 使用ping命令检测主机是否在线，超时设置为1秒，只发送1个数据包
  (ping -c 1 -W 1 ${network}.$i > /dev/null 2>&1 && 
   echo -e "${GREEN}[在线]${NC} ${network}.$i" && 
   echo "${network}.$i" >> "$temp_file") &
  
  # 限制并行进程数量，避免系统负载过高
  if [[ $(jobs -r | wc -l) -ge 20 ]]; then
    wait -n
  fi
done

# 等待所有后台进程完成
wait

# 统计在线主机数
online_hosts=$(wc -l < "$temp_file")
total_hosts=254

echo "----------------------------------------"
echo -e "${YELLOW}扫描完成!${NC}"
echo -e "网段: ${network}.0/24"
echo -e "在线主机数: ${GREEN}${online_hosts}${NC}"
echo -e "总扫描主机数: ${total_hosts}"

# 清理临时文件
rm -f "$temp_file" 
