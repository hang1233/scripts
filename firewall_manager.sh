#!/bin/bash

# UFW防火墙交互式管理脚本
# 支持检查状态、开启、关闭、验证防火墙及退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        exit 1
    fi
}

# 显示菜单
show_menu() {
    echo -e "${BLUE}========== UFW防火墙管理菜单 ==========${NC}"
    echo "1. 检查防火墙状态"
    echo "2. 开启防火墙"
    echo "3. 关闭防火墙"
    echo "4. 验证防火墙规则"
    echo "5. 退出"
    echo -e "${BLUE}=====================================${NC}"
}

# 检查防火墙状态
check_status() {
    log_info "检查防火墙状态..."
    if sudo ufw status | grep -q "Status: active"; then
        log_info "防火墙已开启"
        sudo ufw status verbose
        return 0
    else
        log_info "防火墙已关闭"
        return 1
    fi
}

# 开启防火墙
enable_firewall() {
    read -p "确定要开启防火墙吗？(y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log_info "正在开启防火墙..."
        sudo ufw enable
        if [ $? -eq 0 ]; then
            log_info "防火墙已成功开启"
            check_status
        else
            log_error "开启防火墙失败"
        fi
    else
        log_info "操作已取消"
    fi
}

# 关闭防火墙
disable_firewall() {
    read -p "确定要关闭防火墙吗？(y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log_info "正在关闭防火墙..."
        sudo ufw disable
        if [ $? -eq 0 ]; then
            log_info "防火墙已成功关闭"
            check_status
        else
            log_error "关闭防火墙失败"
        fi
    else
        log_info "操作已取消"
    fi
}

# 验证防火墙规则
validate_rules() {
    log_info "验证防火墙规则..."
    # 检查是否允许SSH
    if sudo ufw status | grep -q "22/tcp.*ALLOW"; then
        log_info "SSH访问已允许"
    else
        log_warn "SSH访问未允许，可能无法远程登录"
    fi
    
    # 检查是否允许常用Web端口
    for port in 80 443; do
        if sudo ufw status | grep -q "$port/tcp.*ALLOW"; then
            log_info "端口 $port 访问已允许"
        fi
    done
    
    # 检查默认策略
    DEFAULT_IN=$(sudo ufw status | grep "Default" | awk '{print $3}' | head -n1)
    DEFAULT_OUT=$(sudo ufw status | grep "Default" | awk '{print $3}' | tail -n1)
    
    if [ "$DEFAULT_IN" = "deny" ]; then
        log_info "默认入站策略: 拒绝"
    else
        log_warn "默认入站策略: $DEFAULT_IN"
    fi
    
    if [ "$DEFAULT_OUT" = "allow" ]; then
        log_info "默认出站策略: 允许"
    else
        log_warn "默认出站策略: $DEFAULT_OUT"
    fi
    
    # 显示所有允许的端口
    allowed_ports=$(sudo ufw status | grep "ALLOW" | grep -v "v6" | awk '{print $1, $2}')
    if [ -n "$allowed_ports" ]; then
        echo -e "\n${BLUE}允许的端口列表:${NC}"
        echo "$allowed_ports"
    fi
}

# 主函数
main() {
    check_root
    
    while true; do
        show_menu
        read -p "请选择操作 [1-5]: " choice
        
        case "$choice" in
            1)
                check_status
                ;;
            2)
                enable_firewall
                ;;
            3)
                disable_firewall
                ;;
            4)
                validate_rules
                ;;
            5)
                log_info "退出防火墙管理脚本"
                exit 0
                ;;
            *)
                log_error "无效选择，请输入1-5之间的数字"
                ;;
        esac
        
        echo
        read -p "按Enter键返回主菜单..."
        clear
    done
}

# 执行主函数
clear
main
