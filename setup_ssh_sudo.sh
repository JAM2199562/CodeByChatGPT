#!/bin/bash

# 用户名和密码变量
USERNAME="albertjenehyonah"
PASSWORD="Password2023###"

# 更新SSH配置以允许密码访问
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config

# 重启SSH服务以应用更改
sudo systemctl restart sshd

# 添加用户（如果用户不存在）并设置密码
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists."
else
    sudo useradd $USERNAME
fi

echo "$USERNAME:$PASSWORD" | sudo chpasswd

echo "SSH password authentication has been enabled and password for user $USERNAME has been set."
