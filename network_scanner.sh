#!/bin/bash

# 内网主机在线状态检测脚本
# 用于测试指定网段内的主机是否在线

# 显示脚本使用信息
show_usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help        显示此帮助信息"
    echo "  -s, --subnet      指定IP网段，格式为 x.x.x.x/24"
    echo ""
    echo "示例: $0 -s 192.168.1.0/24"
}

# 验证IP地址格式
validate_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# 验证CIDR格式
validate_cidr() {
    local cidr=$1
    local ip=$(echo $cidr | cut -d'/' -f1)
    local mask=$(echo $cidr | cut -d'/' -f2)

    if ! validate_ip $ip; then
        return 1
    fi

    if [[ ! $mask =~ ^[0-9]{1,2}$ ]]; then
        return 1
    fi

    if [[ $mask -lt 0 || $mask -gt 32 ]]; then
        return 1
    fi

    return 0
}

# 从CIDR获取IP范围
get_ip_range() {
    local cidr=$1
    local ip=$(echo $cidr | cut -d'/' -f1)
    local mask=$(echo $cidr | cut -d'/' -f2)
    
    # 计算网络地址和可用IP范围
    IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
    local ip_num=$(( (i1 << 24) + (i2 << 16) + (i3 << 8) + i4 ))
    local netmask=$(( 0xFFFFFFFF << (32 - mask) ))
    local network=$(( ip_num & netmask ))
    local broadcast=$(( network | (~netmask & 0xFFFFFFFF) ))
    
    # 转换为IP地址
    local net_i1=$(( (network >> 24) & 0xFF ))
    local net_i2=$(( (network >> 16) & 0xFF ))
    local net_i3=$(( (network >> 8) & 0xFF ))
    local net_i4=$(( network & 0xFF ))
    
    local bcast_i1=$(( (broadcast >> 24) & 0xFF ))
    local bcast_i2=$(( (broadcast >> 16) & 0xFF ))
    local bcast_i3=$(( (broadcast >> 8) & 0xFF ))
    local bcast_i4=$(( broadcast & 0xFF ))
    
    # 返回网络地址和广播地址
    echo "$net_i1.$net_i2.$net_i3.$net_i4"
    echo "$bcast_i1.$bcast_i2.$bcast_i3.$bcast_i4"
}

# 检查主机是否在线
check_host() {
    local ip=$1
    ping -c 1 -W 1 $ip > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "\e[32m[在线]\e[0m $ip"
        # 尝试获取主机名
        hostname=$(nslookup $ip 2>/dev/null | grep "name =" | awk '{print $4}' | tr -d '.')
        if [ -n "$hostname" ]; then
            echo -e "      主机名: $hostname"
        fi
    else
        echo -e "\e[31m[离线]\e[0m $ip" > /dev/null
    fi
}

# 主函数
main() {
    # 检查是否有root权限
    if [ "$(id -u)" -ne 0 ]; then
        echo "此脚本需要root权限才能运行。请使用sudo执行。"
        exit 1
    fi

    # 默认选项
    subnet=""

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -s|--subnet)
                subnet=$2
                shift 2
                ;;
            *)
                echo "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # 如果没有指定网段，提示用户输入
    if [ -z "$subnet" ]; then
        echo "请输入要扫描的IP网段 (格式为 x.x.x.x/24):"
        read subnet
    fi

    # 验证CIDR格式
    if ! validate_cidr $subnet; then
        echo "错误: 无效的IP网段格式。请使用 x.x.x.x/24 格式。"
        exit 1
    fi

    echo "开始扫描网段 $subnet ..."
    echo "这可能需要一些时间，请耐心等待..."
    echo ""

    # 获取网络地址和广播地址
    read network
    read broadcast
    get_ip_range $subnet

    # 提取网络部分
    net_part=$(echo $network | cut -d'.' -f1-3)
    
    # 创建临时文件存储结果
    temp_file=$(mktemp)
    
    # 并行检查所有IP
    for i in $(seq 1 254); do
        ip="$net_part.$i"
        # 跳过网络地址和广播地址
        if [ "$ip" = "$network" ] || [ "$ip" = "$broadcast" ]; then
            continue
        fi
        check_host $ip &
        # 限制并发数
        if [ $(jobs | wc -l) -ge 50 ]; then
            wait -n
        fi
    done
    
    # 等待所有后台任务完成
    wait
    
    echo ""
    echo "扫描完成！"
    echo "在线主机列表:"
    echo "----------------------------"
    grep "\[在线\]" $temp_file | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n
    echo "----------------------------"
    
    # 清理临时文件
    rm -f $temp_file
}

# 执行主函数
main "$@"    
