#!/bin/bash

# 脚本简介:
# 该脚本用于在Ubuntu系统上自动安装和配置vsftpd FTP服务器。
# 它将执行以下操作：
# 1. 检查vsftpd是否已安装，如果未安装，则自动安装。
# 2. 询问用户设置FTP的用户名和密码。
# 3. 确保指定的FTP用户家目录存在，如果该目录不存在则创建。
# 4. 设置FTP家目录的适当权限，并确保有一个可上传文件的子目录。
# 5. 修改vsftpd的配置以满足特定需求，包括启用基于chroot的用户隔离。
# 6. 备份原始的vsftpd配置文件，应用新的配置设置。
# 7. 重启vsftpd服务，使更改生效。
# 注意：运行此脚本需要具有root权限。

# 显示简介
echo "开始执行vsftpd安装与配置脚本..."
echo "请按提示操作，以设置FTP服务。"

# 检查并安装vsftpd
if ! command -v vsftpd >/dev/null 2>&1; then
    echo "未发现vsftpd，正在安装..."
    apt-get update
    apt-get install -y vsftpd
    echo "vsftpd 安装成功。"
else
    echo "vsftpd 已经安装。"
fi

# 交互式询问用户名和密码
read -p "请输入FTP用户名: " FTP_USER
read -s -p "请输入FTP密码: " FTP_PASSWORD
echo # 新行

FTP_HOME="/data/$FTP_USER"
UPLOAD_DIR="$FTP_HOME/upload"

# 检查并创建用户
if id "$FTP_USER" &>/dev/null; then
    echo "用户 $FTP_USER 已经存在，更新密码。"
    echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
else
    useradd -m -d $FTP_HOME $FTP_USER
    echo "$FTP_USER:$FTP_PASSWORD" | chpasswd
    echo "用户 $FTP_USER 创建成功。"
fi

# 创建和设置目录
if [ ! -d "$FTP_HOME" ]; then
    mkdir -p $FTP_HOME
    echo "$FTP_HOME 目录创建成功。"
fi

chown root:root $FTP_HOME
chmod 755 $FTP_HOME

if [ ! -d "$UPLOAD_DIR" ]; then
    mkdir -p $UPLOAD_DIR
    echo "$UPLOAD_DIR 目录创建成功。"
fi

# 这里是改变的部分，确保upload目录可写
chown $FTP_USER:$FTP_USER $UPLOAD_DIR
chmod 755 $UPLOAD_DIR

# 更新vsftpd配置
VSFTPD_CONF="/etc/vsftpd.conf"
CHROOT_LIST="/etc/vsftpd.chroot_list"

# 确保配置正确
if [ -f "$VSFTPD_CONF" ]; then
    cp $VSFTPD_CONF "${VSFTPD_CONF}.bak" # 备份原始配置文件
    sed -i '/^chroot_local_user/d' $VSFTPD_CONF
    echo "chroot_local_user=YES" >> $VSFTPD_CONF
    
    sed -i '/^chroot_list_enable/d' $VSFTPD_CONF
    echo "chroot_list_enable=YES" >> $VSFTPD_CONF
    
    sed -i '/^chroot_list_file/d' $VSFTPD_CONF
    echo "chroot_list_file=$CHROOT_LIST" >> $VSFTPD_CONF
    
    sed -i '/^allow_writeable_chroot/d' $VSFTPD_CONF
    echo "allow_writeable_chroot=YES" >> $VSFTPD_CONF

    sed -i '/^write_enable=/d' $VSFTPD_CONF
    echo 'write_enable=YES' >> $VSFTPD_CONF

else
    echo "错误：$VSFTPD_CONF 文件不存在。"
fi

# 创建chroot_list
if [ ! -f "$CHROOT_LIST" ]; then
    touch $CHROOT_LIST
    chown root:root $CHROOT_LIST
    chmod 644 $CHROOT_LIST
    echo "chroot_list 创建成功。"
fi

# 重启vsftpd服务
systemctl restart vsftpd
systemctl status vsftpd
echo "vsftpd 设置完成。"
