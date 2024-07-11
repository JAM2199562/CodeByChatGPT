#!/bin/bash

# 检查是否以 root 或 sudo 运行
check_root() {
  if [ $(id -u) -ne 0 ]; then
    echo -e "\033[31m请以 root 或 sudo 权限运行此脚本。\033[0m"
    exit 1
  fi
}

# 检查操作系统版本
check_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION_ID=$(awk -F '=' '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"')

    if [[ "$OS" == "Red Hat Enterprise Linux" || "$OS" == "CentOS Linux" ]]; then
      if (($(echo "$VERSION_ID < 7" | bc -l))); then
        echo -e "\033[31m操作系统版本小于7，不支持。\033[0m"
        exit 1
      fi
    elif [[ "$OS" == "Ubuntu" ]]; then
      if (($(echo "$VERSION_ID < 18" | bc -l))); then
        echo -e "\033[31mUbuntu版本小于18，不支持。\033[0m"
        exit 1
      fi
    else
      echo -e "\033[31m不支持的操作系统：$OS。\033[0m"
      exit 1
    fi
  else
    echo -e "\033[31m无法确定操作系统版本。\033[0m"
    exit 1
  fi
}

# 安装防火墙
install_firewall() {
  check_os
  if [ "$OS" = "Ubuntu" ]; then
    echo "正在 Ubuntu 上安装 Firewalld..."
    sudo apt-get update
    sudo apt-get install -y firewalld
  elif [ "$OS" = "Red Hat Enterprise Linux" ] || [ "$OS" = "CentOS Linux" ]; then
    echo "正在 Red Hat/CentOS 上安装 Firewalld..."
    sudo yum install -y firewalld
  else
    echo -e "\033[31m不支持的操作系统版本。\033[0m"
    exit 1
  fi
}

# 禁用 UFW
disable_ufw() {
  if ufw status | grep -q 'active'; then
    echo "正在禁用 UFW..."
    sudo ufw disable
  else
    echo "UFW 已经是禁用状态，无需操作。"
  fi
}

# 启用并启动防火墙
start_firewall() {
  echo "启动 Firewalld..."
  sudo systemctl enable firewalld
  sudo systemctl start firewalld
}

# 放行全部监听端口
open_all_listening_ports() {
  echo -e "\033[33m是否要将主机当前所有监听端口全部加入放行清单并重载？(y/n)\033[0m"
  read -p "请输入 y 或 n: " answer
  case $answer in
  [Yy]*)
    echo "正在检查所有监听端口并加入放行清单..."
    for port in $(netstat -tunlp | grep LISTEN | awk '{print $4}' | awk -F ":" '{print $NF}' | sort -n | uniq); do
      sudo firewall-cmd --zone=public --add-port=${port}/tcp --permanent
      sudo firewall-cmd --zone=public --add-port=${port}/udp --permanent
    done
    sudo firewall-cmd --reload
    ;;
  [Nn]*)
    echo "跳过将监听端口加入放行清单的步骤。"
    ;;
  *)
    echo "无效的输入。请输入 y 或 n。"
    ;;
  esac
}

# 检查 Ubuntu 系统的防火墙状态
check_ubuntu_firewall() {
  check_os
  if [ "$OS" = "Ubuntu" ]; then
    if ufw status | grep -Fxq 'Status: active'; then
      echo -e "\033[33m当前防火墙是 UFW，是否要禁用 UFW 并切换到 firewall-cmd 管理？(y/n)\033[0m"
      read -p "请输入 y 或 n: " answer
      case $answer in
      [Yy]*)
        install_firewall
        disable_ufw
        start_firewall
        ;;
      [Nn]*)
        echo "跳过禁用 UFW 和安装 firewall-cmd 的步骤。"
        ;;
      *)
        echo "无效的输入。请输入 y 或 n。"
        ;;
      esac
    fi
  fi
}

# 检查 Red Hat 系统的防火墙状态
check_redhat_firewall() {
  check_os
  if [ "$OS" = "Red Hat Enterprise Linux" ] || [ "$OS" = "CentOS Linux" ]; then
    if ! command -v firewall-cmd &>/dev/null; then
      echo -e "\033[33mfirewall-cmd 未安装，是否协助安装？\033[0m"
      install_firewall
      start_firewall
    fi
  fi
}

firewall_management() {
  echo -e "\033[32m前置检查通过，进入防火墙管理。\033[0m"
  while true; do
    echo "请选择一个操作："
    echo "1) 放行端口"
    echo "2) 加白名单"
    echo "3) 加黑名单"
    echo "4) 查看防火墙清单"
    echo "q) 退出"
    read -p "请输入你的选择 (1-4 或 q): " choice

    case $choice in
    1)
      allow_port
      ;;
    2)
      add_whitelist
      ;;
    3)
      add_blacklist
      ;;
    4)
      list_rules
      ;;
    q)
      echo "退出防火墙管理。"
      break
      ;;
    *)
      echo "无效的输入。请输入 1-4 或 q。"
      ;;
    esac
  done
}

allow_port() {
  echo -e "\033[33m请输入你要放行的端口号。\033[0m"
  echo -e "\033[32m例如：\033[0m"
  echo -e "\033[34m  单个端口：80\033[0m"
  echo -e "\033[34m  多个端口：80,443\033[0m"
  echo -e "\033[34m  端口范围：8000-9000\033[0m"
  echo -e "\033[31m注意：不支持混合格式（如：80,8000-9000）。\033[0m"
  read -p "请输入端口号： " ports

  IFS=',' read -ra ADDR <<<"$ports"
  for i in "${ADDR[@]}"; do
    firewall-cmd --zone=public --add-port="$i"/tcp --permanent
    firewall-cmd --zone=public --add-port="$i"/udp --permanent
  done

  firewall-cmd --reload
  echo -e "\033[32m已放行端口：$ports。\033[0m"
}

add_to_list() {
  local zone=$1
  echo -e "\033[33m请输入你要加入的 IP 地址。\033[0m"
  echo -e "\033[32m例如：\033[0m"
  echo -e "\033[34m  单个 IP：192.168.1.1\033[0m"
  echo -e "\033[34m  CIDR 网段：192.168.1.0/24\033[0m"
  read -p "请输入 IP 地址： " ip_address

  for check_zone in public drop trusted; do
    if firewall-cmd --zone=$check_zone --query-source="$ip_address" >/dev/null; then
      read -p $'\e[31m'"IP 地址 $ip_address 已经在 $check_zone 名单中，你是否要将其从 $check_zone 名单中移除？(y/n) "$'\e[0m' answer
      if [[ $answer == "y" ]]; then
        firewall-cmd --zone=$check_zone --remove-source="$ip_address" --permanent
      else
        echo "操作已取消。"
        return
      fi
    fi
  done

  firewall-cmd --zone=$zone --add-source="$ip_address" --permanent
  firewall-cmd --reload
  echo "已将 IP 地址 $ip_address 加入 $zone 名单。"
}

add_whitelist() {
  add_to_list trusted
}

add_blacklist() {
  add_to_list drop
}

list_rules() {
  for zone in drop trusted public; do
    echo -e "\033[1;33m######## $zone rules ########\033[0m"
    firewall-cmd --zone=$zone --list-all
  done
}

# 主函数
main() {
  check_root
  check_os
  check_ubuntu_firewall
  check_redhat_firewall
  firewall_management
}

main
