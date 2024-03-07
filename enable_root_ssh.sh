#!/bin/bash

# 脚本: enable_root_ssh.sh

# 询问并设置 root 用户的密码
echo "请输入您想为 root 用户设置的新密码:"
read -s rootpasswd

# 更改 root 用户的密码
echo "root:$rootpasswd" | chpasswd

# 更新 /etc/ssh/sshd_config 来允许 root 用户通过密码进行远程登录
# 备份原始的 sshd_config 文件
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# 允许密码认证
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 允许 root 用户通过 SSH 登录
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# 重新启动 SSH 服务以应用更改
systemctl restart sshd

# 输出完成信息
echo "SSH configuration updated. Root login over SSH with password is enabled."
