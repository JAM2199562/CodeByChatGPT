#!/bin/bash

# 通用工具函数
print_success() {
    echo -e "\e[1;32m✔ $1\e[0m"  # 粗体绿色
}

print_info() {
    echo -e "\e[1;34m➜ $1\e[0m"  # 粗体蓝色
}

print_warn() {
    echo -e "\e[1;33m⚠ $1\e[0m"  # 粗体黄色
}

print_error() {
    echo -e "\e[1;31m✘ $1\e[0m"  # 粗体红色
}

print_separator() {
    echo -e "\e[1;35m----------------------------------------\e[0m"  # 粗体紫色分隔线
}

# 服务管理函数
service_manager() {
    local action=$1
    local service=$2
    
    # 检查系统使用的是 systemd 还是 service
    if command -v systemctl >/dev/null 2>&1; then
        case "$action" in
            start)
                sudo systemctl start "$service"
                ;;
            stop)
                sudo systemctl stop "$service"
                ;;
            restart)
                sudo systemctl restart "$service"
                ;;
            enable)
                sudo systemctl enable "$service"
                ;;
            disable)
                sudo systemctl disable "$service"
                ;;
            status)
                systemctl is-active "$service"
                ;;
            *)
                print_error "未知的服务操作: $action"
                return 1
                ;;
        esac
    else
        case "$action" in
            start)
                sudo service "$service" start
                ;;
            stop)
                sudo service "$service" stop
                ;;
            restart)
                sudo service "$service" restart
                ;;
            enable)
                sudo chkconfig "$service" on
                ;;
            disable)
                sudo chkconfig "$service" off
                ;;
            status)
                service "$service" status
                ;;
            *)
                print_error "未知的服务操作: $action"
                return 1
                ;;
        esac
    fi
}

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
        OS_FAMILY="unknown"
        
        case $ID in
            ubuntu|debian|linuxmint|pop)
                OS_FAMILY="debian"
                PACKAGE_MANAGER="apt-get"
                ;;
            rhel|centos|fedora|rocky|almalinux)
                OS_FAMILY="redhat"
                if command -v dnf &> /dev/null; then
                    PACKAGE_MANAGER="dnf"
                else
                    PACKAGE_MANAGER="yum"
                fi
                ;;
            *)
                print_error "不支持的操作系统: $ID"
                exit 1
                ;;
        esac

        # 版本检测
        case $ID in
            debian)
                if [ "${VERSION_ID%%.*}" -lt 10 ]; then
                    print_error "不支持的 Debian 版本。需要 Debian 10 或更高版本。"
                    exit 1
                fi
                ;;
            ubuntu)
                if [ "${VERSION_ID%%.*}" -lt 18 ]; then
                    print_error "不支持的 Ubuntu 版本。需要 Ubuntu 18.04 或更高版本。"
                    exit 1
                fi
                ;;
            centos)
                if [ "${VERSION_ID%%.*}" -lt 7 ]; then
                    print_error "不支持的 CentOS 版本。需要 CentOS 7 或更高版本。"
                    exit 1
                fi
                ;;
        esac
    else
        print_error "无法检测操作系统类型"
        exit 1
    fi
}

get_arch() {
    local program=$1
    local arch=$(uname -m)
    
    case $arch in
        x86_64)
            if [ "$program" = "gost" ]; then
                echo "amd64"
            else
                echo "amd64"
            fi
            ;;
        aarch64)
            if [ "$program" = "gost" ]; then
                echo "arm64"
            else
                echo "arm64"
            fi
            ;;
        *)
            print_error "不支持的架构: $arch"
            return 1
            ;;
    esac
}

function install_package() {
    local package_name=$1
    local apt_name=${2:-$package_name}  # 如果没有指定apt包名，使用第一个参数
    local yum_name=${3:-$package_name}  # 如果没有指定yum包名，使用第一个参数

    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y "$apt_name"
    elif command -v yum &> /dev/null; then
        sudo yum install -y "$yum_name"
    else
        echo "不支持的包管理器，请手动安装 $package_name。"
        return 1
    fi
}

# 在脚本开始时立即检测系统
detect_os

# 询问用户是否在中国大陆
read -p "您是否在中国大陆？(y/n): " in_china
in_china=${in_china,,}  # 转换为小写

# 按菜单顺序排列的功能函数
# 1) 配置历史格式和终端提示符样式
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

# 2) 将时区设置为北京时间
set_timezone_to_gmt8() {
    # 设置时区为 Asia/Shanghai
    sudo timedatectl set-timezone Asia/Shanghai
    
    # 步硬件时钟
    sudo hwclock --systohc

    print_separator
    print_success "时区已设置为北京时间！"
    print_info "当前时间: $(date '+%Y-%m-%d %H:%M:%S')"
    print_separator
}

# 3) 安装常用软件
install_common_software() {
    print_info "开始安装常用软件..."
    print_separator

    # 基础包列表（通用名称）
    local common_packages=(
        "curl"
        "vim"
        "wget"
        "nload"
        "net-tools"
        "screen"
        "git"
        "autoconf"
        "libtool"
        "automake"
        "jq"
        "bash-completion"
        "axel"
        "lsof"
        "zip"
        "unzip"
        "htop"
        "net-tools"
    )

    # 特定发行版包名映射
    declare -A debian_packages=(
        ["build-essential"]="build-essential"
        ["dnsutils"]="dnsutils"
        ["libgmp-dev"]="libgmp-dev"
        ["sysstat"]="sysstat"
    )

    declare -A redhat_packages=(
        ["build-essential"]="gcc gcc-c++ make"  # RedHat 系统中 build-essential 的替代包
        ["dnsutils"]="bind-utils"               # RedHat 系统中 dnsutils 的替代包
        ["libgmp-dev"]="gmp-devel"             # RedHat 系统中 libgmp-dev 的替代包
        ["sysstat"]="sysstat"
    )

    # EPEL 仓库（仅用于 RedHat 系列）
    if [ "$OS_FAMILY" = "redhat" ]; then
        print_info "正在安装 EPEL 仓库..."
        if [ "$PACKAGE_MANAGER" = "dnf" ]; then
            sudo dnf install -y epel-release
        else
            sudo yum install -y epel-release
        fi
    fi

    # 对于 Debian 系列，添加 build-essential 等开发工具
    if [ "$OS_FAMILY" = "debian" ]; then
        common_packages+=("build-essential" "dnsutils" "libgmp-dev" "sysstat")
    fi

    # 对于 RedHat 系列，添加对应的开发工具
    if [ "$OS_FAMILY" = "redhat" ]; then
        common_packages+=("gcc" "gcc-c++" "make" "bind-utils" "gmp-devel" "sysstat")
    fi

    # 一次性安装所有软件包
    case $OS_FAMILY in
        debian)
            sudo apt-get update
            sudo apt-get install -y "${common_packages[@]}"
            ;;
        redhat)
            if [ "$PACKAGE_MANAGER" = "dnf" ]; then
                sudo dnf install -y "${common_packages[@]}"
            else
                sudo yum install -y "${common_packages[@]}"
            fi
            ;;
    esac

    print_separator
    print_success "所有软件包安装完成！"
    print_separator
}

# 4) 安装 chsrc 命令行换源工具
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

# 5) 安装 Golang
install_golang() {
    # 检查是否已经安装 Go
    if command -v go >/dev/null 2>&1; then
        INSTALLED_GO_VERSION=$(go version | awk '{print $3}')
        print_separator
        print_success "Go 已安装！"
        print_info "当前版本: ${INSTALLED_GO_VERSION}"
        print_separator
        return
    fi

    # 安装依赖（curl 和 jq 在两个系统族中的包名相同）
    print_info "正在检查并安装必要的赖 (curl, jq)..."
    case $OS_FAMILY in
        debian|redhat)
            install_package "curl" || return 1
            install_package "jq" || return 1
            ;;
        *)
            print_error "不支持的操作系统族: $OS_FAMILY"
            return 1
            ;;
    esac

    # 获取架构
    ARCH=$(get_arch "go") || return 1

    # 根据地区选择下载源
    if [ "$in_china" = "y" ]; then
        DOWNLOAD_BASE="https://golang.google.cn/dl"
    else
        DOWNLOAD_BASE="https://go.dev/dl"
    fi

    # 获取全部 Go 版本清单
    GO_VERSIONS_JSON=$(curl -s "${DOWNLOAD_BASE}/?mode=json")
    GO_VERSIONS=$(echo "$GO_VERSIONS_JSON" | jq -r '.[].version' | sort -V | tail -n 3)

    if [ -z "$GO_VERSIONS" ]; then
        print_error "无法获取 Go 版本列表，请检查网络连接"
        return 1
    fi

    # 打印最新的3个 Go 版本供用户选择
    print_info "可用的 Go 版本如下："
    echo "$GO_VERSIONS" | nl -w 2 -s '. '

    # 让用户选择 Go 版本
    read -p "请输入要安装的 Go 版本号前的序号 (1-3): " VERSION_INDEX

    # 获取用户选择的版本号
    GO_VERSION=$(echo "$GO_VERSIONS" | sed -n "${VERSION_INDEX}p")

    if [ -z "$GO_VERSION" ]; then
        print_error "无效的选择。"
        return 1
    fi

    # 下载 Go
    print_info "开始下载 ${GO_VERSION}..."
    wget "${DOWNLOAD_BASE}/${GO_VERSION}.linux-amd64.tar.gz"
    if [ ! -f "${GO_VERSION}.linux-amd64.tar.gz" ]; then
        print_error "下载 Go 失败"
        return 1
    fi

    # 解压 Go
    sudo tar -C /usr/local -xzf "${GO_VERSION}.linux-amd64.tar.gz"

    # 删除安装包
    rm -rf "${GO_VERSION}.linux-amd64.tar.gz"

    # 添加到环境变量
    if ! grep -q "/usr/local/go/bin" /etc/profile; then
        echo "export PATH=\$PATH:/usr/local/go/bin" | sudo tee -a /etc/profile
    fi

    print_separator
    print_success "Go 安装完成！"
    print_info "版本: ${GO_VERSION}"
    print_info "请运行 'source /etc/profile' 或重新登录以使 Go 在您的环境中可用"
    print_separator
}

# 6) 安装 Node.js 和 Yarn
install_node_and_yarn() {
    # 检查 RHEL/CentOS 7.x 的情况
    if [ "$OS_FAMILY" = "redhat" ] && [[ "${VERSION_ID%%.*}" -eq 7 ]]; then
        print_separator
        print_error "Node.js LTS (v20) 不支持 RHEL/CentOS 7.x"
        print_info "请考虑使用其他方式安装 Node.js，或升级系统版本"
        print_separator
        return 1
    fi

    # 检查是否已经安装 Node.js
    if command -v node >/dev/null 2>&1; then
        INSTALLED_NODE_VERSION=$(node -v)
        print_info "Node.js 已安装，版本为 ${INSTALLED_NODE_VERSION}。跳过安装。"
    else
        # 安装 Node.js
        print_info "正在安装 Node.js..."
        case $OS_FAMILY in
            debian)
                # 添加 NodeSource 仓库
                curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
                install_package "nodejs"
                ;;
            redhat)
                # 添加 NodeSource 仓库
                curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
                install_package "nodejs"
                ;;
            *)
                print_error "不支持的操作系统族: $OS_FAMILY"
                return 1
                ;;
        esac
        print_success "Node.js 安装完成。"
    fi

    # 检查是否已经安装 Yarn
    if command -v yarn >/dev/null 2>&1; then
        INSTALLED_YARN_VERSION=$(yarn -v)
        print_info "Yarn 已安装，版本为 ${INSTALLED_YARN_VERSION}。跳过安装。"
    else
        # 安装 Yarn
        print_info "正在安装 Yarn..."
        case $OS_FAMILY in
            debian)
                curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
                echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
                sudo apt-get update
                install_package "yarn"
                ;;
            redhat)
                curl -sL https://dl.yarnpkg.com/rpm/yarn.repo | sudo tee /etc/yum.repos.d/yarn.repo
                install_package "yarn"
                ;;
            *)
                print_error "不支持操作系统家族: $OS_FAMILY"
                return 1
                ;;
        esac
        print_success "Yarn 安装完成。"
    fi

    print_separator
    print_success "Node.js 和 Yarn 安装完成！"
    print_info "Node.js 版本: $(node -v)"
    print_info "Yarn 版本: $(yarn -v)"
    print_separator
}

# 7) 安装 Docker
install_docker() {
    print_info "开始安装 Docker..."

    # 检查是否已安装
    if command -v docker &> /dev/null; then
        print_separator
        print_success "Docker 已安装！"
        print_info "版本信息：$(docker --version)"
        print_separator
        return 0
    fi

    # 安装必要的依赖
    case $OS_FAMILY in
        debian)
            # 安装依赖包
            local deps=(
                "apt-transport-https"
                "ca-certificates"
                "curl"
                "gnupg"
                "lsb-release"
                "software-properties-common"
            )
            
            for dep in "${deps[@]}"; do
                install_package "$dep"
            done

            # 添加 Docker 的官方 GPG 密钥
            curl -fsSL https://download.docker.com/linux/$OS_NAME/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

            # 添加 Docker 仓库
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS_NAME \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

            # 安装 Docker
            sudo apt-get update
            install_package "docker-ce"
            install_package "docker-ce-cli"
            install_package "containerd.io"
            ;;

        redhat)
            # 检查并安装 yum-utils
            if ! command -v yum-config-manager &> /dev/null; then
                print_info "正在安装必要的依赖包 yum-utils..."
                install_package "yum-utils" || return 1
            fi

            # 添加 Docker 仓库
            if [ "$OS_NAME" = "centos" ]; then
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            else
                # 对于 Rocky Linux 和 AlmaLinux，使用 CentOS 的仓库
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                # 替换仓库 URL 中的 centos 为实际的系统
                sudo sed -i 's/centos/rhel/g' /etc/yum.repos.d/docker-ce.repo
            fi

            # 安装 Docker
            install_package "docker-ce"
            install_package "docker-ce-cli"
            install_package "containerd.io"
            ;;
    esac

    # 启动 Docker 服务
    service_manager start docker
    service_manager enable docker

    # 创建 docker 组并添加当前用户
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker $USER

    # 配置 Docker 镜像加速（可选，基于用户选择）
    # read -p "是否配置 Docker 镜像加速？(y/n): " setup_mirror
    if [[ "$setup_mirror" =~ ^[Yy]$ ]]; then
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com",
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com"
    ]
}
EOF
        service_manager restart docker
    fi

    print_separator
    print_success "Docker 安装完成！"
    print_info "版本信息：$(docker --version)"
    print_info "服务状态：$(service_manager status docker)"
    print_info "请注销并重新登录以用 docker 组更改"
    print_separator

    # 安装 Docker Compose（可选）
    read -p "是否安装 Docker Compose？(y/n): " install_compose
    if [[ "$install_compose" =~ ^[Yy]$ ]]; then
        install_docker_compose
    fi
}

# Docker Compose 安装函数
install_docker_compose() {
    print_info "开始安装 Docker Compose..."

    # 检查是否已安装
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose 已安装！"
        print_info "版本信息：$(docker-compose --version)"
        return 0
    fi

    # 获取最新版本号
    local latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    # 下载并安装 Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/${latest_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # 创建软链接
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

    print_separator
    print_success "Docker Compose 安装完成！"
    print_info "版本信息：$(docker-compose --version)"
    print_separator
}

# 8) 安装 Rust(cargo)
install_rust() {
    if [ "$in_china" = "y" ]; then
        export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
        export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
    fi

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # 加载 Rust 环境变量
    . "$HOME/.cargo/env"

    # 如果在中国，配置 USTC 镜像
    if [ "$in_china" = "y" ]; then
        mkdir -p ~/.cargo
        cat > ~/.cargo/config.toml <<EOF
[source]
ustc = { registry = "git://mirrors.ustc.edu.cn/crates.io-index" }
[registry]
default = "ustc"
EOF
    fi

    # 验证安装
    if command -v cargo >/dev/null 2>&1; then
        print_separator
        print_success "Rust 安装成功！"
        print_info "Cargo 版本: $(cargo --version)"
        print_info "Rustc 版本: $(rustc --version)"
        if [ "$in_china" = "y" ]; then
            print_info "已配置中科大(USTC)镜像源"
        fi
        print_separator
    else
        print_error "Rust 安装失败"
        return 1
    fi
}

# 9) 安装 Xray
install_xray() {
    # 获取最新版本号 - 直接获取 tag_name
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)

    if [ -z "$LATEST_VERSION" ]; then
        LATEST_VERSION="v24.9.30"  # 如果无法获取，使用一个已知的稳定版本
        print_warn "无法获取最新版本信息，将使用默认版本 ${LATEST_VERSION}"
    fi

    print_info "请选择要安装的 Xray 版本："
    echo "1) ${LATEST_VERSION} (最新版)"
    echo "2) v1.8.24 (稳定版)"
    read -p "请输入选项 [1-2]: " version_choice

    # 根据选择构建安装命令
    case $version_choice in
        1)
            INSTALL_CMD="bash -c \"\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)\" @ install"
            ;;
        2)
            INSTALL_CMD="bash -c \"\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)\" @ install --version 1.8.24"
            ;;
        *)
            print_error "无效的选项"
            return 1
            ;;
    esac

    # 仅在安装时使用 ghproxy
    if [ "$in_china" = "y" ]; then
        INSTALL_CMD=${INSTALL_CMD/github.com/ghproxy.nyxyy.org\/https:\/\/github.com}
    fi

    # 执行安装
    eval $INSTALL_CMD

    # 验证安装
    if command -v xray >/dev/null 2>&1; then
        print_separator
        print_success "Xray 安装完成！"
        print_info "版本: $(xray version)"
        print_info "服务状态: $(service_manager status xray)"
        print_info "配置文件位置: /usr/local/etc/xray/"
        print_separator
    else
        print_error "Xray 安装失败"
        return 1
    fi
}

# 10) 安装 Gost
install_gost() {
    print_info "开始安装 GOST..."

    # 安装必要的依赖
    case $OS_FAMILY in
        debian)
            install_package "curl"
            install_package "tar"
            install_package "gzip"
            install_package "screen"
            install_package "telnet"
            ;;
        redhat)
            install_package "curl"
            install_package "tar"
            install_package "gzip"
            install_package "screen"
            install_package "telnet"
            ;;
        *)
            print_error "不支持的操作系统族: $OS_FAMILY"
            return 1
            ;;
    esac

    # 获取架构
    ARCH=$(get_arch "gost") || return 1

    # GOST 版本和下载链接
    GOST_VERSION="3.0.0-rc10"
    
    # 根据地区选择下载源
    if [ "$in_china" = "y" ]; then
        DOWNLOAD_BASE="https://ghproxy.nyxyy.org/https://github.com"
    else
        DOWNLOAD_BASE="https://github.com"
    fi
    
    DOWNLOAD_URL="${DOWNLOAD_BASE}/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_${ARCH}.tar.gz"

    print_info "正在下载 GOST..."
    if ! curl -L "$DOWNLOAD_URL" -o gost.tar.gz; then
        print_error "下载 GOST 失败"
        return 1
    fi

    # 解压 GOST
    if ! tar -xzf gost.tar.gz; then
        print_error "解压 GOST 失败"
        rm -f gost.tar.gz
        return 1
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

    # 创建 systemd 服务
    cat <<EOF | sudo tee /etc/systemd/system/gost.service > /dev/null
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

    # 启用 GOST 服务
    sudo systemctl enable gost.service

    # 检查防火墙状态并添加规则
    if command -v ufw >/dev/null 2>&1 && sudo systemctl is-active --quiet ufw; then
        print_info "检测到 ufw 防火墙，添加端口规则..."
        sudo ufw allow ${GOST_PORT}/tcp
        sudo ufw reload
    elif command -v firewall-cmd >/dev/null 2>&1 && sudo systemctl is-active --quiet firewalld; then
        print_info "检测到 firewalld 防火墙，添加端口规则..."
        sudo firewall-cmd --permanent --add-port=${GOST_PORT}/tcp
        sudo firewall-cmd --reload
    else
        print_info "未检测到活动的防火墙服务"
    fi

    print_separator
    print_success "GOST 服务配置完成"
    print_info "协议: socks5"
    print_info "端口: ${GOST_PORT}"
    print_info "密码: ${GOST_PASSWORD}"
    print_info "可以通过 'sudo systemctl start gost' 命令启动服务"
    print_separator
}

# 11) 安装 VNC 服务器
install_vnc_server() {
    # 检查操作系统类型
    if [ "$OS_FAMILY" = "redhat" ]; then
        print_separator
        print_error "VNC 服务器安装脚本暂不支持 RedHat 系列系统"
        print_info "请参考以下步骤手动安装："
        print_info "1. 安装 XFCE 桌面环境："
        print_info "   sudo dnf groupinstall 'Xfce Desktop'"
        print_info "2. 安装 TigerVNC 服务器："
        print_info "   sudo dnf install tigervnc-server"
        print_info "3. 配置 VNC 服务："
        print_info "   vncserver :1"
        print_info "4. 编辑 ~/.vnc/xstartup 文件配置桌面环境"
        print_separator
        return 1
    fi

    # 原有的 Debian/Ubuntu 安装逻辑保持不变
    # 指定 VNC 用户的用户名
    VNC_USER="vnc"

    # 创建 VNC 用
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

    # 果当前是 root 用户，创建 root 的 vnc.sh 脚本
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

# 12) 安装 Chrome 浏览器
install_chrome() {
    # 检查操作系统类型
    if [ "$OS_FAMILY" = "redhat" ]; then
        print_separator
        print_error "Chrome 浏览器安装脚本暂不支持 RedHat 系列系统"
        print_info "请参考以下步骤手动安装："
        print_info "1. 添加 Chrome 仓库："
        print_info "   sudo dnf config-manager --set-enabled google-chrome"
        print_info "   或手动创建文件："
        print_info "   sudo tee /etc/yum.repos.d/google-chrome.repo << EOF"
        print_info "   [google-chrome]"
        print_info "   name=google-chrome"
        print_info "   baseurl=http://dl.google.com/linux/chrome/rpm/stable/\$basearch"
        print_info "   enabled=1"
        print_info "   gpgcheck=1"
        print_info "   gpgkey=https://dl.google.com/linux/linux_signing_key.pub"
        print_info "   EOF"
        print_info "2. 安装 Chrome 浏览器："
        print_info "   sudo dnf install google-chrome-stable"
        print_separator
        return 1
    fi

    # 原有的 Debian/Ubuntu 安装逻辑保持不变
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

# 13) 禁用并移除 Snapd
disable_and_remove_snapd() {
    # 检查是否为 Ubuntu
    if [ "$OS_NAME" != "ubuntu" ]; then
        print_separator
        print_error "此功能仅支持 Ubuntu 系统"
        print_separator
        return 1
    fi

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

# 14) 禁止系统自动更新
disable_automatic_updates() {
    # 检查是否为 Ubuntu
    if [ "$OS_NAME" != "ubuntu" ]; then
        print_separator
        print_error "此功能仅支持 Ubuntu 系统"
        print_separator
        return 1
    fi

    CONFIG_FILE="/etc/apt/apt.conf.d/10periodic"

    # 检查件是否存在，如果不存在则创建
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

# 15) 禁止系统更新内核
disable_kernel_package_installation() {
    # 检查是否为 Ubuntu
    if [ "$OS_NAME" != "ubuntu" ]; then
        print_separator
        print_error "此功能仅支持 Ubuntu 系统"
        print_separator
        return 1
    fi

    cat <<EOF | sudo tee /etc/apt/preferences.d/disable-kernel-packages >/dev/null
Package: linux-image*
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

# 16) 禁用/启用IPv6
toggle_ipv6() {
    print_info "当前 IPv6 状态检测中..."
    
    # 检查当前状态
    current_status=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
    
    if [ "$current_status" = "1" ]; then
        status_text="已禁用"
        action_text="启用"
        new_value=0
    else
        status_text="已启用"
        action_text="禁用"
        new_value=1
    fi
    
    print_info "IPv6 当前状态: $status_text"
    read -p "是否${action_text} IPv6？(y/n): " choice
    
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        # 修改 sysctl 配置
        if [ "$OS_FAMILY" = "debian" ]; then
            # Debian/Ubuntu 系统的配置文件位置
            config_file="/etc/sysctl.d/99-disable-ipv6.conf"
        else
            # RedHat 系列的配置文件位置
            config_file="/etc/sysctl.d/99-disable-ipv6.conf"
        fi

        # 创建或更新配置文件
        echo "net.ipv6.conf.all.disable_ipv6 = $new_value" | sudo tee $config_file
        echo "net.ipv6.conf.default.disable_ipv6 = $new_value" | sudo tee -a $config_file
        echo "net.ipv6.conf.lo.disable_ipv6 = $new_value" | sudo tee -a $config_file

        # 应用更改
        sudo sysctl -p $config_file

        # 验证更改
        new_status=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
        if [ "$new_status" = "$new_value" ]; then
            if [ "$new_value" = "1" ]; then
                print_success "IPv6 已成功禁用"
            else
                print_success "IPv6 已成功启用"
            fi
            print_info "系统需要重启才能完全应用更改"
            read -p "是否现在重启系统？(y/n): " reboot_choice
            if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
                sudo reboot
            fi
        else
            print_error "IPv6 状态更改失败"
        fi
    else
        print_info "操作已取消"
    fi
}

# 17) 重新生成主机的machine-id
setup_machine_id() {
    # 检查是否使用 systemd
    if ! command -v systemd-machine-id-setup &> /dev/null; then
        print_error "此系统不支持 machine-id 设置（需要 systemd）"
        return 1
    fi

    local machine_id_file="/etc/machine-id"
    local dbus_machine_id_file="/var/lib/dbus/machine-id"
    local cron_task="@reboot [ -f /etc/machine-id ] || systemd-machine-id-setup"
    local temp_file=$(mktemp)

    print_info "开始配置 machine-id..."

    # 删除 machine-id 文件
    if [ -f "$machine_id_file" ]; then
        sudo rm -f "$machine_id_file"
        print_success "已删除 $machine_id_file"
    fi

    # 处理 D-Bus machine-id
    if [ -f "$dbus_machine_id_file" ]; then
        sudo rm -f "$dbus_machine_id_file"
        print_success "已删除 $dbus_machine_id_file"
    fi

    # 检查并添加 cron 任务
    if ! sudo crontab -l 2>/dev/null | grep -q "$cron_task"; then
        (sudo crontab -l 2>/dev/null; echo "$cron_task") | sudo crontab -
        print_success "已添加开机自动生成 machine-id 的 cron 任务"
    else
        print_info "开机自动生成 machine-id 的 cron 任务已存在"
    fi

    print_separator
    print_success "Machine-ID 配置完成！"
    print_info "系统需要重启才能生成新的 Machine-ID"
    read -p "是否现在重启系统？(y/n): " reboot_choice
    
    if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
        print_info "系统将在 3 秒后重启..."
        sleep 3
        sudo reboot
    else
        print_info "请记得稍后重启系统以生成新的 Machine-ID"
    fi
}

# 18) 安装Miniconda 3
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

    # 清安装脚本
    rm -f Miniconda3-latest-Linux-*.sh

    print_separator
    print_success "Miniconda3 安装完成！"
    print_info "安装路径: $INSTALL_PATH"
    print_info "版本: $(conda --version)"
    print_info "请重新登录以使环境变量生效"
    print_separator
}

# 19) 安装1panel面板
install_1panel() {
    print_info "开始安装 1Panel..."
    
    # 检查是否已安装
    if systemctl is-active 1panel &>/dev/null; then
        print_error "1Panel 已经安装并正在运行"
        return 1
    fi

    # 下载安装脚本
    print_info "正在下载安装脚本..."
    if ! curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh; then
        print_error "下载安装脚本失败"
        return 1
    fi

    # 检查脚本是否下载成功
    if [ ! -f quick_start.sh ]; then
        print_error "安装脚本下载不完整"
        return 1
    fi

    # 执行安装脚本
    print_info "正在安装 1Panel..."
    if sudo bash quick_start.sh; then
        print_separator
        print_success "1Panel 安装成功！"
        print_info "请查看上方输出获取管理员密码和访问地址"
        print_separator
    else
        print_error "1Panel 安装失败，请检查错误信息"
        rm -f quick_start.sh
        return 1
    fi

    # 清理安装脚本
    rm -f quick_start.sh
    return 0
}

# 20) 禁用systemd-resolved
disable_systemd_resolved() {
    # 检查 Ubuntu 版本
    UBUNTU_VERSION=$(lsb_release -rs)

    if [[ "$UBUNTU_VERSION" == "24."* ]]; then
        print_error "该脚本不兼容 Ubuntu 24 版本，退出。"
        return 1
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
        print_error "未在 $NETPLAN_DIR 中找到 Netplan 配置文件"
        return 1
    fi

    # 如果只有一 netplan 配置文件，直接备份并修改
    if [ ${#NETPLAN_FILES[@]} -eq 1 ]; then
        NETPLAN_CONFIG="${NETPLAN_FILES[0]}"
        echo "找到单一的 Netplan 配置文件: $NETPLAN_CONFIG"
    else
        # 果有多个配置文件，列出文件并提示用户选择
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
    sudo cp "$NETPLAN_CONFIG" "${NETPLAN_CONFIG}.bak"

    # 修改文件权限为600
    sudo chmod 600 "$NETPLAN_CONFIG"

    # 创建临时文件
    TEMP_FILE=$(mktemp)

    # 读取现有配置并保持缩进
    while IFS= read -r line; do
        if [[ $line =~ "dhcp4: true" ]]; then
            echo "$line" >> "$TEMP_FILE"
            echo "            dhcp4-overrides:" >> "$TEMP_FILE"
            echo "                use-dns: true" >> "$TEMP_FILE"
        else
            echo "$line" >> "$TEMP_FILE"
        fi
    done < "$NETPLAN_CONFIG"

    # 将修改后的配置写回原文件
    sudo mv "$TEMP_FILE" "$NETPLAN_CONFIG"

    # 确保文件权限正确
    sudo chmod 600 "$NETPLAN_CONFIG"
    sudo chown root:root "$NETPLAN_CONFIG"

    # 验证配置
    if ! sudo netplan try; then
        print_error "Netplan 配置验证失败，正在恢复备份..."
        sudo mv "${NETPLAN_CONFIG}.bak" "$NETPLAN_CONFIG"
        sudo chmod 600 "$NETPLAN_CONFIG"
        return 1
    fi

    # 应用 Netplan 配置
    sudo netplan apply

    # 重新启动网络服务以获取新的 DHCP 配置
    sudo systemctl restart systemd-networkd
    sudo dhclient -r
    sudo dhclient

    print_separator
    print_success "systemd-resolved 已禁用！"
    print_info "53端口已释放"
    print_info "DNS 设置已更新为 DHCP 模式"
    print_separator
}

# 21) 清理 Docker 资源
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

# 22) 配置常用别名和函数
configure_aliases_and_functions() {
    # 定义别名和函数文件的路径
    local ALIASES_FILE="$HOME/.bash_aliases_custom"
    local TEMP_FILE=$(mktemp)
    
    # 创建临时文件
    cat > "$TEMP_FILE" <<'EOF'
# 目录操作别名
alias md='mkdir -p'

# 网络测试别名
alias pb='ping www.baidu.com'
alias pd='ping 10.130.32.31'
alias dnsb='nslookup bing.com'

# 网络端口查看别名
alias ntl='netstat -tlnp'
alias nul='netstat -ulnp'
alias ntul='netstat -tulnp'

# Docker操作别名
alias dkps='docker ps'
alias dkpsa='docker ps -a'
alias dkk='docker kill'
alias dkrm='docker rm -f'
alias dks='docker stop'
alias dkr='docker run -itd'

# 包安装函数
function install_package() {
    local package_name=$1
    local apt_name=${2:-$package_name}  # 如果没有指定apt包名，使用第一个参数
    local yum_name=${3:-$package_name}  # 如果没有指定yum包名，使用第一个参数

    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y "$apt_name"
    elif command -v yum &> /dev/null; then
        sudo yum install -y "$yum_name"
    else
        echo "不支持的包管理器，请手动安装 $package_name。"
        return 1
    fi
}

# 端口检测函数
function port() {
    local host=$1
    local port=$2

    if [ -z "$host" ] || [ -z "$port" ]; then
        echo "用法：port <主机> <端口>"
        return 1
    fi

    if ! command -v nc &> /dev/null; then
        echo "未找到 nc 命令，正在安装..."
        install_package nc netcat nc || return 1
    fi

    if ! command -v nmap &> /dev/null; then
        read -p "未找到 nmap 命令，是否要安装？(y/n): " install_nmap
        if [[ "$install_nmap" =~ ^[Yy]$ ]]; then
            install_package nmap || return 1
        else
            echo "继续运行，但不使用 nmap..."
        fi
    fi

    echo "正在检查 $host 的 $port 端口..."

    nc -zv -w 3 $host $port 2>&1 >/dev/null
    nc_result=$?

    if command -v nmap &> /dev/null; then
        nmap_result=$(nmap -p $port $host 2>&1 | grep "$port" | grep -oE "(open|closed|filtered)")
    else
        nmap_result="nmap未安装"
    fi

    if [ "$nc_result" -eq 0 ] || [ "$nmap_result" = "open" ]; then
        output_color="\033[0;32m"
    else
        output_color="\033[0;31m"
    fi

    echo -e "nc 检测结果: $([ $nc_result -eq 0 ] && echo -e "${output_color}开放\033[0m" || echo -e "${output_color}关闭\033[0m")"
    if [ "$nmap_result" = "nmap未安装" ]; then
        echo -e "nmap 检测结果: \033[0;33m$nmap_result\033[0m"
    else
        case "$nmap_result" in
            "open") nmap_result="开放" ;;
            "closed") nmap_result="关闭" ;;
            "filtered") nmap_result="被过滤" ;;
            *) nmap_result="无法访问" ;;
        esac
        echo -e "nmap 检测结果: ${output_color}${nmap_result}\033[0m"
    fi
}

# Docker容器执行函数
function dkexec() {
    container_id=$1
    if [ -z "$container_id" ]; then
        echo "用法：dkexec <容器ID>"
        return 1
    fi

    if docker exec -it $container_id /bin/bash -c 'exit' >/dev/null 2>&1; then
        echo "正在使用 bash 进入容器 $container_id"
        docker exec -it $container_id /bin/bash
    elif docker exec -it $container_id /bin/sh -c 'exit' >/dev/null 2>&1; then
        echo "正在用 sh 进入容器 $container_id"
        docker exec -it $container_id /bin/sh
    else
        echo "容器 $container_id 既没有 bash 没有 sh"
    fi
}

# 历史命令查看函数
function his() {
    local lines=${1:-50}
    history | tail -n $lines
}

# 文件备份函数
function bkk() {
    if [[ -n "$1" ]]; then
        local current_date=$(date +%Y%m%d%H%M)
        local backup_name="${1}.${current_date}"
        if [ -d "$1" ]; then
            cp -r "$1" "$backup_name"
        elif [ -f "$1" ]; then
            cp "$1" "$backup_name"
        else
            echo "错误：'$1' 不是有效的文件或目录"
            return 1
        fi
        echo "已创建 '$1' 的备份：'$backup_name'"
    else
        echo "用法：bkk <文件名/目录>"
    fi
}

# TCP抓包函数
function tcpd() {
    if [[ -z "$1" ]]; then
        sudo tcpdump -i any -nn
    elif [[ $1 =~ ^[0-9]+$ ]] && [ $1 -ge 0 ] && [ $1 -le 65535 ]; then
        sudo tcpdump -i any port $1 -nn
    else
        echo "错误：无效的端口号。请提供 0-65535 范围内的端口号。"
    fi
}

# Python简单HTTP服务器
function pys() {
    for ip in $(ip -4 a | grep inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1); do
        echo "http://$ip:1111"
    done
    if command -v python3 &> /dev/null; then
        python3 -m http.server 1111
    elif command -v python &> /dev/null && python -c "import sys; print(sys.version_info[0])" | grep -q "2"; then
        python -m SimpleHTTPServer 1111
    else
        echo "系统中未安装 Python 2 或 Python 3"
    fi
}
EOF

    # 根据发行版确定目标配置文件
    if [ "$OS_FAMILY" = "redhat" ]; then
        TARGET_RC_FILE="$HOME/.bash_profile"
    else
        TARGET_RC_FILE="$HOME/.bashrc"
    fi

    # 检查目标配置文件中是否存在引用
    if grep -q "source.*$ALIASES_FILE" "$TARGET_RC_FILE"; then
        # 检查实际文件是否存在
        if [ ! -f "$ALIASES_FILE" ]; then
            print_info "发现 ${TARGET_RC_FILE} 中的引用但配置文件不存在，将重新创建"
            mv "$TEMP_FILE" "$ALIASES_FILE"
            chmod 644 "$ALIASES_FILE"
            print_success "配置文件已重新创建：$ALIASES_FILE"
            return 0
        else
            # 文件存在，检查差异
            if ! diff -q "$ALIASES_FILE" "$TEMP_FILE" >/dev/null 2>&1; then
                print_info "发现现有配置文件与新配置存在差异"
                read -p "是否要覆盖现有配置？(y/n): " overwrite
                if [[ "$overwrite" =~ ^[Yy]$ ]]; then
                    mv "$TEMP_FILE" "$ALIASES_FILE"
                    chmod 644 "$ALIASES_FILE"
                    print_success "配置文件已更新"
                else
                    rm "$TEMP_FILE"
                    print_info "保留现有配置"
                fi
            else
                rm "$TEMP_FILE"
                print_info "配置文件内容相同，无需更新"
            fi
        fi
    else
        # 目标配置文件中没有引用，这是首次安装
        mv "$TEMP_FILE" "$ALIASES_FILE"
        chmod 644 "$ALIASES_FILE"
        
        # 添加到目标配置文件
        echo -e "\n# Load custom aliases and functions" >> "$TARGET_RC_FILE"
        echo "if [ -f \"$ALIASES_FILE\" ]; then" >> "$TARGET_RC_FILE"
        echo "    source \"$ALIASES_FILE\"" >> "$TARGET_RC_FILE"
        echo "fi" >> "$TARGET_RC_FILE"
        
        print_separator
        print_success "别名和函数配置完成！"
        print_info "配置文件已创建：$ALIASES_FILE"
        print_info "并已在 ${TARGET_RC_FILE} 中添加引用"
        print_info "请运行 'source ${TARGET_RC_FILE}' 或重新登录以使更改生效"
        print_separator
    fi
}

# 主菜单循环
while true; do
    echo "选择要执行的操作 (可用逗号分隔多个选项，或输入范围如1-22):"
    echo "1) 配置历史格式和终端提示符样式"
    echo "2) 将时区设置为北京时间"
    echo "3) 安装常用软件"
    echo "4) 安装 chsrc 命令行换源工具"
    echo "5) 安装 Golang"
    echo "6) 安装 Node.js 和 Yarn"
    echo "7) 安装 Docker"
    echo "8) 安装 Rust(cargo)"
    echo "9) 安装 Xray"
    echo "10) 安装 Gost"
    echo "11) 安装 VNC 服务器"
    echo "12) 安装 Chrome 浏览器"
    echo "13) 禁用并移除 Snapd (仅 Ubuntu)"
    echo "14) 禁止系统自动更新 (仅 Ubuntu)"
    echo "15) 禁止系统更新内核 (仅 Ubuntu)"
    echo "16) 禁用/启用IPv6"
    echo "17) 重新生成主机的machine-id"
    echo "18) 安装Miniconda 3"
    echo "19) 安装1panel面板"
    echo "20) 禁用systemd-resolved，释放53端口"
    echo "21) 清理 Docker 资源"
    echo "22) 配置常用别名和函数"
    echo "q) 退出"
    read -p "请输入选项: " choice

    # 检查是否选择退出
    if [[ $choice = "q" ]]; then
        exit 0
    fi

    expanded_choices=()

    # 检查输入值为围
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
            5) install_golang ;;
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
            22) configure_aliases_and_functions ;;
            *) echo "无效的选项: $i" ;;
        esac
    done
done
