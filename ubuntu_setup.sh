#!/bin/bash

# 在脚本开头添加颜色定义
print_success() {
    echo -e "\e[1;32m✔ $1\e[0m"  # 粗体绿色
}

print_info() {
    echo -e "\e[1;34m➜ $1\e[0m"  # 粗体蓝色
}

print_error() {
    echo -e "\e[1;31m✘ $1\e[0m"  # 粗体红色
}

print_separator() {
    echo -e "\e[1;35m----------------------------------------\e[0m"  # 粗体紫色分隔线
}

# 检查操作系统是否为 Debian 或 Ubuntu
if [[ -z "$(grep 'debian\|ubuntu' /etc/os-release)" ]]; then
    echo "此脚本只适用于 Debian 或 Ubuntu 系统。"
    exit 1
fi

# 获取系统架构
# 参数: $1 - 目标程序名称 (go/gost/等)
# 返回: 输出转换后的架构名称，如果不支持则返回1
get_arch() {
    local program=$1
    local system_arch=$(uname -m)
    local target_arch=""

    case $system_arch in
        x86_64)
            target_arch="amd64"
            ;;
        aarch64)
            target_arch="arm64"
            ;;
        armv7l)
            case $program in
                "go")
                    target_arch="armv6l"
                    ;;
                "gost")
                    target_arch="armv7"
                    ;;
                *)
                    target_arch="armv7l"
                    ;;
            esac
            ;;
        *)
            echo "不支持的架构: $system_arch" >&2
            return 1
            ;;
    esac

    echo "$target_arch"
    return 0
}

# 询问用户是否在中国大陆
read -p "您是否在中国大陆？(y/n): " in_china
in_china=${in_china,,}  # 转换为小写

# 功能函数
configure_history_settings() {
    # 配置 HISTTIMEFORMAT
    if ! grep -q "HISTTIMEFORMAT" ~/.bashrc; then
        echo 'export HISTTIMEFORMAT="%F %T "' >> ~/.bashrc
    fi

    # 配置 HISTSIZE 和 HISTFILESIZE
    if ! grep -q "HISTSIZE" ~/.bashrc; then
        echo 'export HISTSIZE=10000' >> ~/.bashrc
        echo 'export HISTFILESIZE=20000' >> ~/.bashrc
    fi

    # 配置 PS1
    if ! grep -q "PS1=" ~/.bashrc; then
        echo 'export PS1="\[\e[32m\][\[\e[m\]\[\e[31m\]\u\[\e[m\]\[\e[33m\]@\[\e[m\]\[\e[32m\]\h\[\e[m\]:\[\e[36m\]\w\[\e[m\]\[\e[32m\]]\[\e[m\]\[\e[32;47m\]\\$\[\e[m\] "' >> ~/.bashrc
    fi

    # 配置命令补全
    if ! grep -q "^# enable bash completion" ~/.bashrc; then
        echo -e "\n# enable bash completion in interactive shells" >> ~/.bashrc
        echo 'if ! shopt -oq posix; then' >> ~/.bashrc
        echo '  if [ -f /usr/share/bash-completion/bash_completion ]; then' >> ~/.bashrc
        echo '    . /usr/share/bash-completion/bash_completion' >> ~/.bashrc
        echo '  elif [ -f /etc/bash_completion ]; then' >> ~/.bashrc
        echo '    . /etc/bash_completion' >> ~/.bashrc
        echo '  fi' >> ~/.bashrc
        echo 'fi' >> ~/.bashrc
    fi

    print_separator
    print_success "历史记录和终端提示符设置已完成！"
    print_info "请重新登录以使设置生效"
    print_separator
}

set_timezone_to_gmt8() {
    # 设置时区为 Asia/Shanghai
    sudo timedatectl set-timezone Asia/Shanghai
    
    # 同步硬件时钟
    sudo hwclock --systohc

    print_separator
    print_success "时区已设置为北京时间！"
    print_info "当前时间: $(date '+%Y-%m-%d %H:%M:%S')"
    print_separator
}

install_common_software() {
    # 更新软件包列表
    sudo apt update

    # 安装通用软件包
    sudo apt install -y curl vim wget nload net-tools screen git autoconf dnsutils autoconf libtool automake build-essential libgmp-dev nload sysstat jq bash-completion axel

    # 安装 plocate 或 mlocate
    sudo apt install -y plocate || sudo apt install -y mlocate

    print_separator
    print_success "常用软件安装完成！"
    print_info "已安装: curl vim wget nload net-tools screen git 等"
    print_separator
}

install_go() {
    # 检查是否已经安装 Go
    if command -v go >/dev/null 2>&1; then
        INSTALLED_GO_VERSION=$(go version | awk '{print $3}')
        print_separator
        print_success "Go 已安装！"
        print_info "当前版本: ${INSTALLED_GO_VERSION}"
        print_separator
        return
    fi

    # 获取架构
    ARCH=$(get_arch "go") || return 1

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

    print_separator
    print_success "Go ${GO_VERSION_NUMBER} 已安装成功！"
    print_info "请注销并重新登录以确保 Go 在您的环境中可用"
    print_separator
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

    print_separator
    print_success "Xray 安装完成！"
    print_info "服务状态: $(systemctl is-active xray)"
    print_info "配置文件位置: /usr/local/etc/xray/"
    print_separator
}

install_gost() {
    # 检查并安装 curl、tar 和 gzip
    if ! command -v curl &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y curl screen telnet
    fi

    if ! command -v tar &> /dev/null || ! command -v gzip &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y tar gzip
    fi

    # 获取架构
    ARCH=$(get_arch "gost") || return 1

    # GOST 版本和下载链接
    GOST_VERSION="3.0.0-rc10"
    DOWNLOAD_URL="https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_${ARCH}.tar.gz"

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

    # 询问用户端口和密码
    read -p "请输入要开启的端口: " GOST_PORT
    read -p "请输入要设置的密码: " GOST_PASSWORD

    # 创建 /opt/gost.sh 并添加正确的 shebang
    cat <<EOF | sudo tee /opt/gost.sh > /dev/null
#!/bin/bash
gost -L="socks5://gost:${GOST_PASSWORD}@:${GOST_PORT}"
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
        sudo ufw allow ${GOST_PORT}/tcp
        sudo ufw reload
        echo "GOST 规则已添加到 ufw 防火墙。"
    elif sudo systemctl is-active --quiet firewalld; then
        echo "检测到 firewalld 防火墙启动，添加 GOST 规则..."
        sudo firewall-cmd --permanent --add-port=${GOST_PORT}/tcp
        sudo firewall-cmd --reload
        echo "GOST 规则已添加到 firewalld 防火墙。"
    else
        echo "未检测到已启用的防火墙服务。"
    fi

    print_separator
    print_success "GOST 服务配置完成"
    print_info "协议: socks5"
    print_info "端口: ${GOST_PORT}"
    print_info "密码: ${GOST_PASSWORD}"
    print_info "可以通过 'sudo systemctl start gost' 命令启动服务"
    print_separator
}

install_rust() {
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

  if command -v rustc >/dev/null 2>&1; then
      print_separator
      print_success "Rust 安装成功！"
      print_info "版本: $(rustc --version)"
      print_separator
  else
      print_error "Rust 安装失败"
      return 1
  fi
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

    print_separator
    print_success "Node.js 和 Yarn 安装完成！"
    print_info "Node.js 版本: $(node -v)"
    print_info "Yarn 版本: $(yarn -v)"
    print_separator
}

install_vnc_server() {
    # 指定 VNC 用户的用户名
    VNC_USER="vnc"

    # 创建 VNC 用户
    echo "创建 VNC 用户: $VNC_USER"
    sudo adduser --gecos "" $VNC_USER --disabled-password

    # 判断并安装合适的桌面环境
    if command -v startxfce4 &> /dev/null; then
        echo "检测到 XFCE 桌面环境。"
        DESKTOP_ENV="xfce"
    elif command -v gnome-session &> /dev/null; then
        echo "检测到 GNOME 桌面环境。"
        DESKTOP_ENV="gnome"
    else
        echo "未检测到桌面环境，正在安装 XFCE..."
        sudo apt install -y xfce4 xfce4-goodies dbus-x11
        DESKTOP_ENV="xfce"
    fi

    # 安装 tightvncserver
    sudo apt install -y tightvncserver

    # 设置 VNC 配置文件
    sudo mkdir -p "/home/$VNC_USER/.vnc"
    sudo chmod 600 "/home/$VNC_USER/.vnc/passwd"

    # 配置 xstartup 文件
    cat <<EOF > "/home/$VNC_USER/.vnc/xstartup"
#!/bin/sh

xrdb \$HOME/.Xresources
xsetroot -solid grey
#x-terminal-emulator -geometry 80x24+10+10 -ls -title "\$VNCDESKTOP Desktop" &
x-window-manager &
vncconfig -iconic &

# Fix to make GNOME work
export XKL_XMODMAP_DISABLE=1
/etc/X11/Xsession

startxfce4
EOF

    # 确保 xstartup 文件有可执行权限
    sudo chmod +x "/home/$VNC_USER/.vnc/xstartup"
    sudo chown $VNC_USER:$VNC_USER "/home/$VNC_USER/.vnc/xstartup"

    # 提供分辨率选择菜单
    echo "请选择 VNC 会话的分辨率："
    echo "1) 1024x768"
    echo "2) 1440x900"
    echo "3) 1920x1080"
    read -p "输入选项编号 [1-3]: " RESOLUTION_OPTION

    case $RESOLUTION_OPTION in
        1)
            RESOLUTION="1024x768"
            ;;
        2)
            RESOLUTION="1440x900"
            ;;
        3)
            RESOLUTION="1920x1080"
            ;;
        *)
            echo "无效的选项，使用默认分辨率 1920x1080。"
            RESOLUTION="1920x1080"
            ;;
    esac

    # 创建 VNC 用户的 vnc.sh 脚本
    cat <<EOF > /home/$VNC_USER/vnc.sh
#!/bin/bash
vncserver -kill :1 > /dev/null 2>&1
vncserver -geometry $RESOLUTION :1
EOF

    sudo chmod +x "/home/$VNC_USER/vnc.sh"
    sudo chown $VNC_USER:$VNC_USER "/home/$VNC_USER/vnc.sh"

    # 如果当前是 root 用户，创建 root 的 vnc.sh 脚本
    if [ "$(whoami)" = "root" ]; then
        cat <<EOF > /root/vnc.sh
#!/bin/bash
vncserver -kill :1 > /dev/null 2>&1
vncserver -geometry $RESOLUTION :1
EOF

        sudo chmod +x /root/vnc.sh
        echo "root 用户的 vnc.sh 脚本已创建。"
    fi
    # 将 xstartup 文件复制到 root 用户的 .vnc 目录中并设置权限
    sudo mkdir -p /root/.vnc
    sudo cp "/home/$VNC_USER/.vnc/xstartup" "/root/.vnc/xstartup"
    sudo chmod +x /root/.vnc/xstartup
    sudo chown root:root /root/.vnc/xstartup

    echo "xstartup 文件已复制到 /root/.vnc 并设置权限。"
    # 提示用户如何启动 VNC 服务器
    print_separator
    print_success "VNC 服务器安装和配置完成"
    print_info "分辨率: $RESOLUTION"
    print_info "用户: $VNC_USER"
    print_info "启动命令: ~/vnc.sh"
    print_separator
}

install_chrome() {
    # 下载 Chrome 浏览器
    curl -sSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o google-chrome-stable_current_amd64.deb

    # 安装 Chrome 浏览器
    sudo dpkg -i google-chrome-stable_current_amd64.deb

    # 清理下载的 deb 文件
    rm -f google-chrome-stable_current_amd64.deb

    if command -v google-chrome >/dev/null 2>&1; then
        print_separator
        print_success "Chrome 浏览器安装成功！"
        print_info "版本: $(google-chrome --version)"
        print_separator
    else
        print_error "Chrome 浏览器安装失败"
        return 1
    fi
}

disable_and_remove_snapd() {
    echo "正在禁用 snapd 服务..."

    systemctl stop snapd.service
    systemctl disable snapd.service
    systemctl disable snapd.socket
    systemctl disable snapd.seeded.service

    echo "正在收集所有 snap 应用..."
    snap_packages=$(snap list | awk '{print $1}' | grep -v "Name" | tr '\n' ' ')

    if [ -n "$snap_packages" ]; then
        echo "正在删除 snap 应用..."
        snap remove $snap_packages
    else
        echo "没有发现任何 snap 应用，跳过删除步骤。"
    fi

    echo "正在删除残留文件..."
    rm -rf /var/cache/snapd/

    echo "正在卸载 snapd..."
    apt autoremove --purge -y snapd

    echo "设置 snapd 包为 hold 状态，防止重新安装..."
    apt-mark hold snapd

    echo "已成功禁用并移除 snapd 以及其残留文件。"

    print_separator
    print_success "Snapd 已成功禁用和移除！"
    print_separator
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

    print_separator
    print_success "Ubuntu 自动更新已禁用！"
    print_separator
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

    print_separator
    print_success "内核更新已禁用！"
    print_separator
}

install_docker() {
    # 获取最新的 Docker 版本
    local latest_version=$(curl -s https://api.github.com/repos/moby/moby/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

    # 检查是否已经安装 Docker
    if command -v docker &>/dev/null; then
        local current_version=$(docker --version | sed -E 's/.*version ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
        echo "当前安装的 Docker 版本为: ${current_version}"
        echo "最新的 Docker 版本为: ${latest_version}"
        read -p "是否卸载当前版本并安装新版本？ (y/n): " answer
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
    # 添加 Docker 的 GPG key
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7EA0A9C3F273FCD8

    # 添加 Docker 软件仓库
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 安装 Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    # 验证安装
    if docker --version >/dev/null 2>&1; then
        print_separator
        print_success "Docker 安装成功！"
        print_info "版本: $(docker --version)"
        print_info "请重新登录或重启系统，以便使用户组更改生效"
        print_separator
    else
        print_error "Docker 安装失败"
        return 1
    fi

    # 添加当前用户到 Docker 用户组
    sudo usermod -aG docker $USER
    echo "已将当前用户加入 Docker 用户组"

    # 询问是否安装 Docker Compose
    read -p "是否安装 Docker Compose？(y/n): " install_compose
    if [[ "$install_compose" =~ ^[Yy]$ ]]; then
        # 获取最新的 Docker Compose 版本
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        
        # 检查是否已安装 Docker Compose
        if command -v docker-compose &>/dev/null; then
            local current_compose_version=$(docker-compose --version | sed -E 's/.*version ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
            echo "当前安装的 Docker Compose 版本为: ${current_compose_version}"
            echo "最新的 Docker Compose 版本为: ${COMPOSE_VERSION#v}"  # 移除版本号前的 'v'
            read -p "是否更新到新版本？ (y/n): " update_compose
            if [[ ! "$update_compose" =~ ^[Yy]$ ]]; then
                echo "已取消安装"
                return
            fi
        fi

        # 如果在中国，使用镜像
        if [ "$in_china" = "y" ]; then
            COMPOSE_URL="https://ghproxy.nyxyy.org/https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
        else
            COMPOSE_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
        fi

        # 下载并安装 Docker Compose
        sudo curl -L "$COMPOSE_URL" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        # 验证安装
        if docker-compose --version >/dev/null 2>&1; then
            echo "Docker Compose 安装成功，版本为 $(docker-compose --version)"
        else
            echo "Docker Compose 安装失败"
            return 1
        fi
    fi

    echo "请重新登录或重启系统，以便使用户组更改生效"
}

install_chsrc() {
    echo "正在安装 chsrc..."
    curl -sSL https://chsrc.run/posix | sudo bash
    if command -v chsrc >/dev/null 2>&1; then
        print_separator
        print_success "chsrc 安装成功！"
        print_separator
    else
        print_error "chsrc 安装失败，请检查网络连接"
        return 1
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

    print_separator
    print_success "IPv6 设置已更新！"
    print_info "当前状态: $(sysctl -n net.ipv6.conf.all.disable_ipv6)"
    print_separator
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
        echo "$machine_id_file 不存在，需删除"
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

    print_separator
    print_success "Machine-ID 设置完成！"
    print_info "请重启系统以生成新的 Machine-ID"
    print_separator
}

install_conda_systemwide() {
    # 检查系统架构
    ARCH=$(uname -m)
    
    if [ "$ARCH" = "x86_64" ]; then
        if [ "$in_china" = "y" ]; then
            CONDA_URL="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh"
        else
            CONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
        fi
    elif [ "$ARCH" = "aarch64" ]; then
        if [ "$in_china" = "y" ]; then
            CONDA_URL="https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-aarch64.sh"
        else
            CONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"
        fi
    else
        echo "不支持的架构: $ARCH"
        exit 1
    fi

    # 询问用户输入安装路径
    read -p "请输入安装路径（默认 /opt/miniconda）: " INSTALL_PATH
    INSTALL_PATH=${INSTALL_PATH:-/opt/miniconda}

    # 检查安装路径是否存在
    if [ -d "$INSTALL_PATH" ]; then
        read -p "路径 $INSTALL_PATH 已存在，是否删除后重新安装？(y/n): " confirm
        confirm=${confirm,,}  # 转换为小写
        if [ "$confirm" = "y" ]; then
            sudo rm -rf "$INSTALL_PATH"
        else
            echo "安装已取消。"
            exit 0
        fi
    fi

    # 下载 Miniconda 安装脚本
    curl -LO "$CONDA_URL"

    # 赋予安装脚本可执行权限
    chmod +x Miniconda3-latest-Linux-*.sh

    # 运行安装脚本，自动同意协议并指定安装路径
    sudo ./Miniconda3-latest-Linux-*.sh -b -p "$INSTALL_PATH"

    # 初始化 Conda
    sudo "$INSTALL_PATH/bin/conda" init

    # 为所有用户添加 Conda 路径到环境变量
    echo "export PATH=$INSTALL_PATH/bin:\$PATH" | sudo tee /etc/profile.d/conda.sh

    # 重新加载环境变量
    source /etc/profile.d/conda.sh

    # 检查 Conda 版本并验证安装成功
    if conda --version >/dev/null 2>&1; then
        CONDA_VERSION=$(conda --version)
        echo "Conda 已成功安装在 $INSTALL_PATH，并且所有用户都可以使用！"
        echo "安装的 Conda 版本为: $CONDA_VERSION"
    else
        echo "Conda 安装失败，请检查错误信息。"
        exit 1
    fi

    # 清理安装脚本
    rm -f Miniconda3-latest-Linux-*.sh

    print_separator
    print_success "Miniconda3 安装完成！"
    print_info "安装路径: $INSTALL_PATH"
    print_info "版本: $(conda --version)"
    print_info "请重新登录以使环境变量生效"
    print_separator
}

install_1panel() {
    # 下载安装脚本
    curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh

    # 执行安装脚本
    sudo bash quick_start.sh

    # 检查安装是否成功
    if [ $? -eq 0 ]; then
        echo "1Panel 安装成功。"
    else
        echo "1Panel 安装失败，请检查错误信息。"
        exit 1
    fi

    # 删除安装脚本
    rm -f quick_start.sh

    print_separator
    print_success "1Panel 安装完成！"
    print_info "请查看安装日志获取登录信息"
    print_separator
}

disable_systemd_resolved() {
  # 检查 Ubuntu 版本
  UBUNTU_VERSION=$(lsb_release -rs)

  if [[ "$UBUNTU_VERSION" == "24."* ]]; then
    echo -e "\e[31m该脚本不兼容 Ubuntu 24 版本，退出。\e[0m"
    exit 1
  fi

  # 禁用并停止 systemd-resolved 服务
  sudo systemctl disable systemd-resolved.service
  sudo systemctl stop systemd-resolved.service

  # 删除现有的 /etc/resolv.conf 符号链接
  if [ -L /etc/resolv.conf ]; then
    sudo rm /etc/resolv.conf
  fi

  # 创建一个新的空的 /etc/resolv.conf 文件
  sudo touch /etc/resolv.conf

  # 列出 /etc/netplan/ 目录中的所有 .yaml 文件
  NETPLAN_DIR="/etc/netplan"
  NETPLAN_FILES=($(ls $NETPLAN_DIR/*.yaml))

  # 如果没有找到 netplan 配置文件，退出脚本
  if [ ${#NETPLAN_FILES[@]} -eq 0 ]; then
    echo "未在 $NETPLAN_DIR 中找到 Netplan 配置文件。"
    exit 1
  fi

  # 如果只有一个 netplan 配置文件，直接备份并修改
  if [ ${#NETPLAN_FILES[@]} -eq 1 ]; then
    NETPLAN_CONFIG="${NETPLAN_FILES[0]}"
    echo "找到单一的 Netplan 配置文件: $NETPLAN_CONFIG"
    echo "正在备份并修改该文件。"
  else
    # 如果有多个配置文件，列出文件并提示用户选择
    echo "找到多个 Netplan 配置文件:"
    select NETPLAN_CONFIG in "${NETPLAN_FILES[@]}"; do
      if [ -n "$NETPLAN_CONFIG" ]; then
        echo "你选择了: $NETPLAN_CONFIG"
        break
      else
        echo "选择无效。请重试。"
      fi
    done
  fi

  # 备份原配置文件
  sudo cp $NETPLAN_CONFIG ${NETPLAN_CONFIG}.bak

  # 读取现有的 Netplan 配置文件，查找已配置的网卡名称
  INTERFACES=$(awk '/ethernets:/,/^[^ ]/{ if ($1 ~ /^[^ ]/) print $1 }' $NETPLAN_CONFIG | sed 's/://g')

  # 修改 Netplan 配置文件，添加 DHCP DNS 配置
  for INTERFACE in $INTERFACES; do
    sudo sed -i "/$INTERFACE:/,/^[^ ]/s/\(dhcp4: true\)/\1\n      dhcp4-overrides:\n        use-dns: true/" $NETPLAN_CONFIG
  done

  # 应用 Netplan 配置
  sudo netplan apply

  # 重新启动网络服务以获取新的 DHCP 配置
  sudo dhclient -r
  sudo dhclient

  echo "配置完成。系统现在使用 DHCP 提供的 DNS 服务器。"

  print_separator
  print_success "systemd-resolved 已禁用！"
  print_info "53端口已释放"
  print_info "DNS 设置已更新为 DHCP 模式"
  print_separator
}

cleanup_docker() {
    echo "Docker 清理选项:"
    echo "1) 停止的容器"
    echo "2) 无用的镜像"
    echo "3) 未使用的卷"
    echo "4) 完整清理"
    read -p "请选择要清理的内容 (可用逗号分隔或1-3): " choice

    for opt in ${choice//,/ }; do
        case $opt in
            1) docker container prune -f ;;
            2) docker image prune -a -f ;;
            3) docker volume prune -f ;;
            4) read -p "确认完整清理？(y/n): " confirm
               [[ $confirm == [yY] ]] && docker system prune -a --volumes -f ;;
        esac
    done
    print_separator
    print_success "Docker 资源清理完成！"
    print_separator
}

# 主菜单循环
while true; do
    echo "选择要执行的操作 (可用逗号分隔多个选项，或输入范围如1-21):"
    echo "1) 配置历史格式和终端提示符样式"
    echo "2) 将时区设置为北京时间"
    echo "3) 安装常用软件"
    echo "4) 安装 chsrc 命令行换源工具"
    echo "5) 安装 Go"
    echo "6) 安装 Node.js 和 Yarn"
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
    echo "18) 安装Miniconda 3"
    echo "19) 安装1panel面板"
    echo "20) 禁用systemd-resolved，释放53端口"
    echo "21) 清理 Docker 资源"
    echo "q) 退出"
    read -p "请输入选项: " choice

    # 检查是否选择退出
    if [[ $choice = "q" ]]; then
        exit 0
    fi

    expanded_choices=()

    # 检查否为范围
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
            4) install_chsrc ;;
            5) install_go ;;
            6) install_node_and_yarn ;;
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
            18) install_conda_systemwide ;;
            19) install_1panel ;;
            20) disable_systemd_resolved ;;
            21) cleanup_docker ;;
            *) echo "无效的选项: $i" ;;
        esac
    done
done
