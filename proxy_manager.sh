#!/bin/bash

# Function to add a host entry for proxy.local
set_hosts_for_proxy() {
    read -p "Enter the IP address for proxy.local: " ip_address

    if [[ -z "$ip_address" ]]; then
        echo "IP address cannot be empty. Please try again."
        return
    fi

    # Check if the entry already exists in /etc/hosts
    if grep -q "proxy.local" /etc/hosts; then
        echo "An entry for proxy.local already exists. Updating the IP address."
        sudo sed -i "/proxy.local/c\\$ip_address proxy.local" /etc/hosts
    else
        echo "Adding a new entry for proxy.local."
        echo "$ip_address proxy.local" | sudo tee -a /etc/hosts > /dev/null
    fi

    echo "The hosts file has been updated successfully."
}

set_proxy_for_apt() {
    # Define the apt configuration file
    apt_conf_file="/etc/apt/apt.conf"

    # Create a backup of the apt.conf file with a timestamp
    timestamp=$(date +"%Y%m%d%H%M")
    backup_file="${apt_conf_file}.${timestamp}.bak"

    echo "Backing up $apt_conf_file to $backup_file"
    sudo cp "$apt_conf_file" "$backup_file"

    # Define the proxy settings
    proxy_settings='Acquire::http::Proxy "http://proxy.local:10882";
Acquire::https::Proxy "http://proxy.local:10882";'

    # Apply the proxy settings
    echo "Applying proxy settings to $apt_conf_file"
    echo "$proxy_settings" | sudo tee "$apt_conf_file" > /dev/null

    echo "Proxy settings have been applied successfully."
}

set_proxy_for_curl() {
    # Create or edit the ~/.curlrc file
    curlrc_file="$HOME/.curlrc"

    # Create a backup of the .curlrc file with a timestamp
    if [[ -f "$curlrc_file" ]]; then
        timestamp=$(date +"%Y%m%d%H%M")
        backup_file="${curlrc_file}.${timestamp}.bak"
        echo "Backing up $curlrc_file to $backup_file"
        cp "$curlrc_file" "$backup_file"
    fi

    # Define the proxy settings
    proxy_setting='proxy = "http://proxy.local:10882"'

    # Apply the proxy settings to the .curlrc file
    echo "Applying proxy settings to $curlrc_file"
    echo "$proxy_setting" > "$curlrc_file"

    echo "Proxy settings for curl have been applied successfully."
}

set_proxy_for_docker_cli() {
    # 定义代理配置
    http_proxy="http://proxy.local:10882"
    https_proxy="http://proxy.local:10882"
    no_proxy="localhost,127.0.0.1,::1,*.aac.com,*.aac.tech"

    # 创建或编辑 ~/.docker/config.json 文件
    config_file="$HOME/.docker/config.json"
    backup_file="$config_file.$(date +'%Y%m%d%H%M').bak"

    # 如果配置文件存在，则进行备份
    if [ -f "$config_file" ]; then
        cp "$config_file" "$backup_file"
        echo "已备份现有配置文件到: $backup_file"
    fi

    # 创建目录（如果不存在）
    mkdir -p "$(dirname "$config_file")"

    # 生成新的代理配置
    sudo tee "$config_file" > /dev/null <<EOL
{
    "proxies": {
        "default": {
            "httpProxy": "$http_proxy",
            "httpsProxy": "$https_proxy",
            "noProxy": "$no_proxy"
        }
    }
}
EOL

    echo "Docker CLI 代理配置已完成。"
}

# Main menu loop
while true; do
    echo "Select the operation to perform (you can separate multiple options with commas or input a range like 0-12):"
    echo "0) Set hosts for proxy.local"
    echo "1) Set proxy for apt"
    echo "2) Set proxy for curl"
    echo "3) Set proxy for Docker"
    echo "4) Set proxy for Git"
    echo "5) Set proxy for Go"
    echo "6) Set proxy for Maven"
    echo "7) Set proxy for npm"
    echo "8) Set proxy for pip"
    echo "9) Set proxy for rsync"
    echo "10) Set proxy for wget"
    echo "11) Set proxy for Yarn"
    echo "12) Set proxy for yum"
    echo "q) Quit"
    read -p "Enter your choice: " choice

    # Check if the user wants to quit
    if [[ $choice = "q" ]]; then
        exit 0
    fi

    expanded_choices=()

    # Check if the input is a range
    if [[ $choice =~ ^[0-9]+-[0-9]+$ ]]; then
        IFS='-' read -ra RANGE <<< "$choice"
        start=${RANGE[0]}
        end=${RANGE[1]}
        # Check if the range is valid
        if (( start <= end )); then
            for (( j=start; j<=end; j++ )); do
                expanded_choices+=($j)
            done
        else
            echo "Invalid range input. Please enter again."
            continue
        fi
    else
        IFS=',' read -ra ADDR <<< "$choice"
        for i in "${ADDR[@]}"; do
            expanded_choices+=($i)
        done
    fi

    for i in "${expanded_choices[@]}"; do
        case $i in
            0) set_hosts_for_proxy ;;
            1) set_proxy_for_apt ;;
            2) set_proxy_for_curl ;;
            3) set_proxy_for_docker_cli ;;
            4) set_proxy_for_git ;;
            5) set_proxy_for_go ;;
            6) set_proxy_for_maven ;;
            7) set_proxy_for_npm ;;
            8) set_proxy_for_pip ;;
            9) set_proxy_for_rsync ;;
            10) set_proxy_for_wget ;;
            11) set_proxy_for_yarn ;;
            12) set_proxy_for_yum ;;
            *) echo "Invalid option: $i" ;;
        esac
    done
done
