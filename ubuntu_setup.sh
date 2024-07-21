#!/bin/bash

# 检查操作系统是否为 Debian 或 Ubuntu
if [[ -z "$(grep 'debian\|ubuntu' /etc/os-release)" ]]; then
    echo "此脚本只适用于 Debian 或 Ubuntu 系统。"
    exit 1
fi

# 询问用户是否在中国大陆，并在同一行接收输入
read -p "您是否在中国大陆？(y/n): " in_china
in_china=${in_china,,}  # 转换为小写

# 功能函数
install_common_software() {
    apt install -y curl vim wget nload mlocate net-tools screen git autoconf dnsutils autoconf libtool automake build-essential libgmp-dev nload sysstat
}

install_go() {
    # 检查是否已经安装 Go
    if command -v go >/dev/null 2>&1; then
        INSTALLED_GO_VERSION=$(go version | awk '{print $3}')
        echo "Go 已安装，版本为 ${INSTALLED_GO_VERSION}。跳过安装。"
        return
    fi

    # 获取操作系统架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="armv6l"
            ;;
        *)
            echo "不支持的架构: $ARCH"
            exit 1
            ;;
    esac

    # 获取全部 Go 版本清单
    GO_VERSIONS_JSON=$(curl -s https://golang.google.cn/dl/?mode=json)
    GO_VERSIONS=$(echo "$GO_VERSIONS_JSON" | jq -r '.[].version')

    # 打印可用的 Go 版本供用户选择
    echo "可用的 Go 版本如下："
    echo "$GO_VERSIONS" | nl -w 2 -s '. '

    # 让用户选择 Go 版本
    read -p "请输入要安装的 Go 版本号前的序号: " VERSION_INDEX

    # 获取用户选择的版本号
    GO_VERSION=$(echo "$GO_VERSIONS" | sed -n "${VERSION_INDEX}p")

    if [ -z "$GO_VERSION" ]; then
        echo "无效的选择。"
        return
    fi

    # 去掉版本号中的 'go' 前缀
    GO_VERSION_NUMBER=$(echo "$GO_VERSION" | sed 's/^go//')

    # 下载 Go 二进制文件
    curl -LO "https://golang.google.cn/dl/${GO_VERSION}.linux-${ARCH}.tar.gz"

    # 解压到 /usr/local 目录
    sudo tar -C /usr/local -xzf "${GO_VERSION}.linux-${ARCH}.tar.gz"

    # 备份 /etc/profile 文件
    sudo cp /etc/profile /etc/profile.bak

    # 添加到系统环境变量中
    if ! grep -q "/usr/local/go/bin" /etc/profile; then
        echo "export PATH=\$PATH:/usr/local/go/bin" | sudo tee -a /etc/profile >/dev/null
    fi

    # 确保立即生效
    export PATH=$PATH:/usr/local/go/bin

    # 清理下载的 tar.gz 文件
    rm "${GO_VERSION}.linux-${ARCH}.tar.gz"

    echo "Go ${GO_VERSION_NUMBER} 已安装。请注销并重新登录以确保 Go 在您的环境中可用。"
}

install_xray() {
    # 定义安装命令
    INSTALL_CMD="bash -c \"\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)\" @ install"

    # 如果在中国大陆，则使用代理连接
    if [ "$in_china" = "y" ]; then
        INSTALL_CMD="bash -c \"\$(curl -L https://ghproxy.nyxyy.org/https://github.com/XTLS/Xray-install/raw/main/install-release.sh)\" @ install"
    fi

    # 执行安装
    eval $INSTALL_CMD
}

install_gost() {
    # 检查并安装 curl、tar 和 gzip
    if ! command -v curl &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y curl screen telnet
    fi

    if ! command -v tar &> /dev/null || ! command -v gzip &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y tar gzip
    fi

    # GOST 版本和下载链接
    GOST_VERSION="3.0.0-rc10"
    DOWNLOAD_URL="https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_amd64.tar.gz"

    # 如果在中国大陆，修改下载链接
    if [ "$in_china" = "y" ]; then
        DOWNLOAD_URL="https://ghproxy.nyxyy.org/${DOWNLOAD_URL}"
    fi

    # 下载 GOST
    curl -L "$DOWNLOAD_URL" -o gost.tar.gz
    if [ ! -f gost.tar.gz ]; then
        echo "下载 GOST 失败"
        exit 1
    fi

    # 解压 GOST
    tar -xzf gost.tar.gz
    if [ ! -f gost ]; then
        echo "解压 GOST 失败"
        exit 1
    fi

    # 赋予执行权限
    chmod +x gost

    # 移动到 /usr/local/bin
    sudo mv gost /usr/local/bin/gost

    # 删除安装包
    rm -rf gost.tar.gz

    # 创建 /opt/gost.sh 并添加正确的 shebang
    cat <<'EOF' | sudo tee /opt/gost.sh > /dev/null
#!/bin/bash
gost -L="socks5://gost:k3LVtKC6fidkuq@:18443"
EOF

    # 赋予 /opt/gost.sh 可执行权限
    sudo chmod +x /opt/gost.sh

    # 创建 GOST 服务
    SERVICE_FILE="/etc/systemd/system/gost.service"
    sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=GOST Service
After=network.target

[Service]
ExecStart=/opt/gost.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载 systemd 管理器配置
    sudo systemctl daemon-reload

    # 启用 GOST 服务（但不启动）
    sudo systemctl enable gost.service

    # 检查防火墙状态并添加规则
    if sudo systemctl is-active --quiet ufw; then
        echo "检测到 ufw 防火墙启动，添加 GOST 规则..."
        sudo ufw allow 18443/tcp
        sudo ufw reload
        echo "GOST 规则已添加到 ufw 防火墙。"
    elif sudo systemctl is-active --quiet firewalld; then
        echo "检测到 firewalld 防火墙启动，添加 GOST 规则..."
        sudo firewall-cmd --permanent --add-port=18443/tcp
        sudo firewall-cmd --reload
        echo "GOST 规则已添加到 firewalld 防火墙。"
    else
        echo "未检测到已启用的防火墙服务。"
    fi

    echo "GOST 服务配置完成，可以通过 'sudo systemctl start gost' 命令启动服务。"
}


install_rust() {
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
}

install_node_and_yarn() {
    # 检查是否已经安装 Node.js
    if command -v node >/dev/null 2>&1; then
        INSTALLED_NODE_VERSION=$(node -v)
        echo "Node.js 已安装，版本为 ${INSTALLED_NODE_VERSION}。跳过安装。"
    else
        # 安装 Node.js
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
        echo "Node.js 安装完成。"
    fi

    # 检查是否已经安装 Yarn
    if command -v yarn >/dev/null 2>&1; then
        INSTALLED_YARN_VERSION=$(yarn -v)
        echo "Yarn 已安装，版本为 ${INSTALLED_YARN_VERSION}。跳过安装。"
    else
        # 安装 Yarn
        npm install --global yarn
        echo "Yarn 安装完成。"
    fi
}

install_vnc_server() {
    # 指定 VNC 用户的用户名
    VNC_USER="vnc"

    # 询问用户要设置的vnc密码
    read -p "您要设定的vnc密码: " VNC_PASSWD

    # 创建 VNC 用户
    echo "创建 VNC 用户: $VNC_USER"
    sudo adduser --gecos "" $VNC_USER --disabled-password
    echo "$VNC_USER:$VNC_PASSWD" | sudo chpasswd
    # 检查系统是否安装了图形用户界面
    if command -v startxfce4 &> /dev/null; then
        echo "XFCE 已安装。"
    elif command -v gnome-session &> /dev/null || command -v kde-config &> /dev/null; then
        echo "检测到非 XFCE 的 GUI 环境。脚本退出。"
        return 1
    else
        echo "安装 XFCE..."
        sudo apt install -y xfce4 xfce4-goodies dbus-x11
    fi

    # 安装 tightvncserver
    sudo apt install -y tightvncserver

    # 设置 VNC 密码和配置文件
    sudo mkdir -p "/home/$VNC_USER/.vnc"
    echo "$VNC_PASSWD" | sudo vncpasswd -f > "/home/$VNC_USER/.vnc/passwd"
    sudo chmod 600 "/home/vnc/.vnc/passwd"
    echo "geometry=1920x1200" | sudo tee "/home/$VNC_USER/.vnc/config"

    # 配置 xstartup 文件
    cat <<EOF > /home/$VNC_USER/.vnc/xstartup
    #!/bin/sh
    unset SESSION_MANAGER
    unset DBUS_SESSION_BUS_ADDRESS
    xrdb /home/vnc/.Xresources
    startxfce4 &
EOF

    sudo chmod +x /home/$VNC_USER/.vnc/xstartup
    sudo chown -R vnc:vnc "/home/$VNC_USER/.vnc"


    # 设置 VNC 服务器默认分辨率
    echo "geometry=1920x1200" > "/home/$VNC_USER/.vnc/config"

    # 设置 VNC 服务器
    vncserver -kill :1 > /dev/null 2>&1
    vncserver

    # 配置 xstartup 文件
    cat <<EOF > /home/$VNC_USER/.vnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xrdb \$HOME/.Xresources
startxfce4 &
EOF
    sudo chown -R vnc:vnc "/home/$VNC_USER/.vnc/xstartup"
    # 使 xstartup 文件可执行
    chmod a+x /home/$VNC_USER/.vnc/xstartup

    # 创建 vnc用户的vnc.sh 脚本
    cat <<EOF > /home/$VNC_USER/vnc_start.sh
#!/bin/bash
vncserver -kill :1
vncserver -geometry 1920x1200
EOF

    # 创建 vnc用户的vnc.sh 脚本
    cat <<EOF > /root/vnc.sh
#!/bin/bash
sudo -u vnc bash /home/vnc/vnc.sh
EOF
    # 使 vnc.sh 文件可执行
    chmod +x /home/$VNC_USER/vnc.sh
    chmod a+x /root/vnc.sh
    chown -R vnc:vnc /home/$VNC_USER/
    echo "VNC 服务器安装和配置完成。你可以运行 '/home/$VNC_USER/vnc.sh' 来启动 VNC 服务器。"
}

configure_history_settings() {
# 需要追加的设置
settings='
export HISTSIZE=10000
export HISTTIMEFORMAT="[%F %T $(whoami)] "
export PS1="\[\e[37;40m\][\[\e[35;40m\]\u\[\e[37;40m\]@\[\e[32;40m\]\h \[\e[34;40m\]\w\[\e[0m\]]\$ "
'

# 追加设置到当前用户的 .bashrc 文件
echo "$settings" >> ~/.bashrc
echo "已添加设置到当前用户的 ~/.bashrc 文件中。"

# 查找 /home 下所有用户的 .bashrc 文件并追加设置
for dir in /home/*/; do
    if [ -f "${dir}.bashrc" ]; then
        echo "$settings" >> "${dir}.bashrc"
        echo "已添加设置到 ${dir}.bashrc 文件中。"
    fi
done

# 追加设置到 /etc/skel/.bashrc 文件
if [ -f "/etc/skel/.bashrc" ]; then
    echo "$settings" >> /etc/skel/.bashrc
    echo "已添加设置到 /etc/skel/.bashrc 文件中。"
fi

echo "所有设置已更新。请退出并重新登录，或者运行 'source ~/.bashrc' 以应用更改。"

}

set_timezone_to_gmt8() {
    echo "正在将时区设置为GMT+8..."

    # 设置时区
    sudo timedatectl set-timezone Asia/Shanghai  # 中国的北京时间为 GMT+8

    # 显示当前时区确认更改
    current_timezone=$(timedatectl | grep 'Time zone' | awk '{print $3}')
    echo "当前时区已设置为: $current_timezone"
}

disable_and_remove_snapd() {
    echo "正在禁用 snapd 服务..."

    systemctl stop snapd.service
    systemctl disable snapd.service
    systemctl disable snapd.socket
    systemctl disable snapd.seeded.service

    echo "正在收集所有 snap 应用..."
    snap_packages=$(snap list | awk '{print $1}' | grep -v "Name" | tr '\n' ' ')

    echo "正在删除 snap 应用..."
    snap remove $snap_packages

    echo "正在删除残留文件..."
    rm -rf /var/cache/snapd/
    
    echo "正在卸载 snapd..."
    apt autoremove --purge -y snapd
    
    echo "设置 snapd 包为 hold 状态，防止重新安装..."
    apt-mark hold snapd

    echo "已成功禁用并移除 snapd 以及其残留文件。"
}

disable_automatic_updates() {
    CONFIG_FILE="/etc/apt/apt.conf.d/10periodic"

    # 检查文件是否存在，如果不存在则创建
    if [ ! -f "$CONFIG_FILE" ]; then
        sudo touch "$CONFIG_FILE"
    fi

    # 添加或更新 APT::Periodic::Unattended-Upgrade 设置
    if grep -q "^APT::Periodic::Unattended-Upgrade" "$CONFIG_FILE"; then
        sudo sed -i 's/^APT::Periodic::Unattended-Upgrade.*/APT::Periodic::Unattended-Upgrade "0";/' "$CONFIG_FILE"
    else
        echo 'APT::Periodic::Unattended-Upgrade "0";' | sudo tee -a "$CONFIG_FILE"
    fi

    echo "Automatic updates have been disabled."
}

disable_kernel_package_installation() {
    cat <<EOF | sudo tee /etc/apt/preferences.d/disable-kernel-packages >/dev/null
Package: linux-image*
Pin: release *
Pin-Priority: -1

Package: linux-headers*
Pin: release *
Pin-Priority: -1

Package: linux-modules*
Pin: release *
Pin-Priority: -1
EOF
    echo "Kernel packages installation has been disabled."
}

install_docker() {
    # 检查是否已经安装 Docker
    if command -v docker &>/dev/null; then
        echo "Docker 已经安装，版本为 $(docker --version)"
        read -p "是否卸载现有版本并安装新版本？ (y/n): " answer
        case "$answer" in
            [Yy]* )
                sudo apt-get remove -y docker-ce docker-ce-cli containerd.io
                echo "已卸载现有版本";;
            * ) echo "已取消安装"; return;;
        esac
    fi

    # 备份并覆盖 Docker 官方 GPG 密钥
    if [ -e "/usr/share/keyrings/docker-archive-keyring.gpg" ]; then
        sudo mv /usr/share/keyrings/docker-archive-keyring.gpg /usr/share/keyrings/docker-archive-keyring.gpg.bak
        echo "已备份原有密钥"
    fi

    # 更新 apt 软件包索引并安装依赖项
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

    # 添加 Docker 官方 GPG 密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # 添加 Docker 软件仓库
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 安装 Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    # 验证安装
    echo "Docker 已安装，版本为 $(docker --version)"

    # 添加当前用户到 Docker 用户组
    sudo usermod -aG docker $USER
    echo "已将当前用户加入 Docker 用户组"

    # 重新登录或重启
    echo "请重新登录或重启系统，以便使用户组更改生效"
}

install_chsrc() {
    # 下载最新版本
    curl -L https://gitee.com/RubyMetric/chsrc/releases/download/pre/chsrc-x64-linux -o /tmp/chsrc
    chmod +x /tmp/chsrc
    # 检查本地版本是否存在
    if command -v chsrc &>/dev/null; then
        local_version=$(chsrc --version | awk '{print substr($0, 8)}')
        new_version=$(TMPDIR=/tmp /tmp/chsrc --version | awk '{print substr($0, 8)}')

        # 对比本地版本和新版本是否一致
        if [[ $local_version != $new_version ]]; then
            echo "当前安装的 chsrc 版本为: $local_version"
            echo "新版本的 chsrc 版本为: $new_version"

            # 询问用户是否替换
            read -p "是否替换当前版本？(y/n): " replace_choice
            if [[ $replace_choice == "y" ]]; then
                mv /tmp/chsrc /usr/local/bin/chsrc
                echo "chsrc 更新完成."
            else
                rm /tmp/chsrc
                echo "已取消更新."
            fi
        else
            echo "当前安装的 chsrc 版本已经是最新版本：$local_version"
            rm /tmp/chsrc
        fi
    else
        mv /tmp/chsrc /usr/local/bin/chsrc
        echo "chsrc 安装完成."
    fi
}

toggle_ipv6() {
    echo "请选择一个选项："
    echo "1. 禁用IPv6"
    echo "2. 启用IPv6"
    read -p "请输入你的选择 [1 或 2]: " choice

    case $choice in
        1)
            echo "正在禁用IPv6..."
            echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
            echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
            echo "net.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
            ;;
        2)
            echo "正在启用IPv6..."
            sudo sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
            sudo sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
            sudo sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.conf
            ;;
        *)
            echo "无效的选择。请输入1或2。"
            return 1
            ;;
    esac

    sudo sysctl -p
}

setup_machine_id() {
    local machine_id_file="/etc/machine-id"
    local cron_file="/etc/crontab"
    local cron_task="@reboot [ -f /etc/machine-id ] || systemd-machine-id-setup"
    local temp_file=$(mktemp)

    # 删除 /etc/machine-id 文件
    if [ -f "$machine_id_file" ]; then
        sudo rm "$machine_id_file"
        echo "已删除 $machine_id_file"
    else
        echo "$machine_id_file 不存在，无需删除"
    fi

    # 检查并去重添加 cron 任务
    sudo crontab -l | grep -v "$cron_task" > "$temp_file"
    echo "$cron_task" >> "$temp_file"
    sudo crontab "$temp_file"
    rm "$temp_file"
    echo "已添加 cron 任务到 crontab"

    # 询问是否要重启
    echo -e "\e[31m是否要立即重启？(y/n):\e[0m"
    read -p "" answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo "正在重启..."
        sudo reboot
    else
        echo "已取消重启"
    fi
}

# 主菜单循环
while true; do
    echo "选择要执行的操作 (可用逗号分隔多个选项，或输入范围如1-15):"
    echo "1) 配置历史格式和终端提示符样式"
    echo "2) 将时区设置为北京时间"
    echo "3) 安装常用软件"
    echo "4) 安装 Go"
    echo "5) 安装 Node.js 和 Yarn"
    echo "6) 安装 chsrc 命令行换源工具"
    echo "7) 安装 Docker"
    echo "8) 安装 Rust"
    echo "9) 安装 Xray"
    echo "10) 安装 Gost"
    echo "11) 安装 VNC 服务器"
    echo "12) 安装 Chrome 浏览器"
    echo "13) 禁用并移除 Snapd"
    echo "14) 禁止 Ubuntu 自动更新"
    echo "15) 禁止 Ubuntu 更新内核"
    echo "16) 禁用/启用IPv6"
    echo "17) 重新生成主机的machine-id"
    echo "q) 退出"
    read -p "请输入选项: " choice

    # 检查是否选择退出
    if [[ $choice = "q" ]]; then
        exit 0
    fi

    expanded_choices=()

    # 检查是否为范围
    if [[ $choice =~ ^[0-9]+-[0-9]+$ ]]; then
        IFS='-' read -ra RANGE <<< "$choice"
        start=${RANGE[0]}
        end=${RANGE[1]}
        # 检查范围是否有效
        if (( start <= end )); then
            for (( j=start; j<=end; j++ )); do
                expanded_choices+=($j)
            done
        else
            echo "范围输入无效，请重新输入。"
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
            1) configure_history_settings ;;
            2) set_timezone_to_gmt8 ;;
            3) install_common_software ;;
            4) install_go ;;
            5) install_node_and_yarn ;;
            6) install_chsrc ;;
            7) install_docker ;;
            8) install_rust ;;
            9) install_xray ;;
            10) install_gost ;;
            11) install_vnc_server ;;
            12) install_chrome ;;
            13) disable_and_remove_snapd ;;
            14) disable_automatic_updates ;;
            15) disable_kernel_package_installation ;;
            16) toggle_ipv6 ;;
            17) setup_machine_id ;;
            *) echo "无效的选项: $i" ;;
        esac
    done
done
