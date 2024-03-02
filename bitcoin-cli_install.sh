#!/bin/bash

# 定义 Bitcoin Core 版本和相关文件路径
BITCOIN_VERSION=25.0
BITCOIN_ARCHIVE=bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz
BITCOIN_URL=https://bitcoin.org/bin/bitcoin-core-${BITCOIN_VERSION}/${BITCOIN_ARCHIVE}

# 下载 Bitcoin Core
if command -v axel >/dev/null; then
    echo "正在使用 axel 下载 Bitcoin Core $BITCOIN_VERSION..."
    axel -n 10 $BITCOIN_URL || {
        echo "使用 axel 下载失败，尝试 wget..."
        wget $BITCOIN_URL || {
            echo "下载失败"
            exit 1
        }
    }
elif command -v wget >/dev/null; then
    echo "正在使用 wget 下载 Bitcoin Core $BITCOIN_VERSION..."
    wget $BITCOIN_URL || {
        echo "下载失败"
        exit 1
    }
else
    echo "未找到 axel 或 wget，无法下载"
    exit 1
fi

# 解压 Bitcoin Core
echo "正在解压 Bitcoin Core..."
tar -xvf $BITCOIN_ARCHIVE && {
    echo "解压成功"
    # 删除下载的压缩文件
    echo "正在删除下载的文件..."
    rm $BITCOIN_ARCHIVE
} || {
    echo "解压失败"
    exit 1
}

# 安装 Bitcoin Core
BITCOIN_DIR=$(tar -tf $BITCOIN_ARCHIVE | head -1 | cut -d "/" -f 1)
echo "正在安装 Bitcoin Core..."
sudo install -m 0755 -o root -g root -t /usr/local/bin $BITCOIN_DIR/bin/* || {
    echo "安装失败"
    exit 1
}

# 设置 bitcoin 用户和配置
echo "正在设置 bitcoin 用户和配置..."
sudo adduser --system --group bitcoin || {
    echo "创建用户失败"
    exit 1
}
sudo mkdir -p /home/bitcoin/.bitcoin || {
    echo "创建目录失败"
    exit 1
}

# 创建并写入配置文件
echo "正在创建配置文件..."
sudo tee /home/bitcoin/.bitcoin/bitcoin.conf > /dev/null << EOF
signet=1
server=1
[signet]
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
rpcport=38332
rpcuser=nextdao
rpcpassword=nextdao
EOF

# 改变配置文件和目录的所有者
sudo chown -R bitcoin:bitcoin /home/bitcoin/.bitcoin

# 设置并启动 Bitcoin Core 服务
echo "正在设置并启动 Bitcoin Core 服务..."
sudo tee /etc/systemd/system/bitcoind.service > /dev/null << EOF
[Unit]
Description=Bitcoin daemon
After=network.target

[Service]
User=bitcoin
Group=bitcoin

Type=forking
ExecStart=/usr/local/bin/bitcoind -daemon -conf=/home/bitcoin/.bitcoin/bitcoin.conf -pid=/home/bitcoin/.bitcoin/bitcoind.pid

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable bitcoind || {
    echo "设置服务失败"
    exit 1
}
sudo systemctl start bitcoind || {
    echo "启动服务失败"
    exit 1
}

echo "安装完成。你现在可以使用 bitcoin-cli 来管理 Bitcoin Core。"
