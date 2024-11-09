#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
NC='\033[0m' # 无颜色

# 固定长度的分隔符
FIXED_SEPARATOR_LENGTH=90

# 打印分隔线，并在中间居中显示标题
print_separator_with_title() {
    local title="$1"
    local total_length=$FIXED_SEPARATOR_LENGTH
    local part_length=$(( (total_length - ${#title}) / 2 ))
    local separator
    printf -v separator "%*s" $total_length
    separator=${separator// /=} # 替换空格为等号
    printf "%.*s %s %.*s\n" "$part_length" "$separator" "$title" "$part_length" "$separator"
}

# 打印各个部分内容
print_section() {
    local title="$1"
    local content="$2"
    if [[ -n "$content" ]]; then
        print_separator_with_title "$title"
        echo -e "${GREEN}${content}${NC}"
    fi
}

# 显示服务器运行时间
print_section "服务器运行时间" "$(uptime -p; echo '启动时间:' $(uptime -s))"

# 获取所有分区的硬盘占用情况，排除overlay文件系统
print_section "硬盘占用情况" "$(df -h | grep -v '^tmpfs' | grep -v 'none' | grep -v 'overlay')"

# 显示内存占用情况
print_section "内存占用情况" "$(free -h | awk 'NR==1 || /Mem:|Swap:/')"

# 显示其他硬件信息
print_section "其他硬件信息" "CPU 核心数: $(nproc)"

# 显示内存容量
print_section "内存容量" "$(free -h | awk '/Mem:/ {print $2}')"

# 使用 lsblk 计算实际的磁盘总容量，排除重复计算
disk_total=$(lsblk -b -d -o SIZE /dev/[sh]d* 2>/dev/null | awk '{s+=$1} END {printf "%.1fG", s/1024/1024/1024}')
print_section "磁盘总容量" "$disk_total"

# 显示网卡信息（包括 IP 地址）
net_info=$(ip -o -4 addr show | awk '{print $2, $4}')
print_section "网卡信息" "$net_info"

# 显示服务状态，如果服务不可用则不显示
if systemctl list-units --type=service | grep -q 'zabbix-agent.service'; then
    print_section "Zabbix服务状态" "$(systemctl is-active zabbix-agent 2>/dev/null)"
fi

if systemctl list-units --type=service | grep -q 'mariadb.service'; then
    print_section "MariaDB服务状态" "$(systemctl is-active mariadb 2>/dev/null)"
fi

if systemctl list-units --type=service | grep -q 'docker.service'; then
    print_section "Docker服务状态" "$(systemctl is-active docker 2>/dev/null)"
fi

# 显示Docker中运行的服务，如果没有则不显示
if command -v docker &>/dev/null; then
    print_section "Docker中运行的服务" "$(docker ps --format 'table {{.Names}}\t{{.Status}}')"
fi

# 显示当前登录用户
print_section "当前登录用户" "$(who)"

# 显示后台运行的 tmux 会话，如果没有则不显示
if command -v tmux &>/dev/null; then
    print_section "tmux 会话" "$(tmux list-sessions 2>/dev/null || echo '')"
fi
