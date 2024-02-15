#!/bin/bash

# 脚本名称：ssh_allow_hk_only.sh
# 用途：配置 iptables 和 ipset 来仅允许来自香港的 IP 地址访问 SSH 端口（22 端口），并使规则持久化

# 设置 ipset 集合的名称，用于存储香港的 IP 区段
SET_NAME="hk-ips"

# 确保脚本以 root 权限运行
if [ "$(id -u)" != "0" ]; then
   echo "该脚本必须以 root 权限运行" 1>&2
   exit 1
fi

# 检查并安装 ipset、wget，如果它们尚未安装
if ! command -v ipset &> /dev/null; then
    echo "正在安装 ipset..."
    apt-get update
    apt-get install -y ipset
fi

if ! command -v wget &> /dev/null; then
    echo "正在安装 wget..."
    apt-get install -y wget
fi

# 检查并安装 iptables-persistent，用于规则持久化
if ! dpkg -l | grep -qw iptables-persistent; then
    echo "正在安装 iptables-persistent..."
    apt-get install -y iptables-persistent
fi

# 创建或重置 ipset 集合
echo "创建或重置 ipset 集合..."
ipset destroy $SET_NAME &> /dev/null
ipset create $SET_NAME hash:net

# 下载并添加香港的 IP 地址范围到 ipset 集合
echo "下载并添加香港 IP 地址到集合..."
wget -O- http://www.ipdeny.com/ipblocks/data/countries/hk.zone | while read line; do
    ipset add $SET_NAME $line
done

# 配置 iptables 规则以允许集合中的 IP 访问 22 端口，并阻止其他 IP
echo "配置 iptables 规则..."
iptables -A INPUT -p tcp --dport 22 -m set --match-set $SET_NAME src -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j DROP

# 保存 iptables 规则以实现持久化
echo "保存 iptables 规则..."
iptables-save > /etc/iptables/rules.v4

echo "配置完成：仅允许来自香港的 IP 地址访问 SSH 端口（22 端口）。规则已持久化。"
