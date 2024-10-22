#!/bin/bash

# 检查系统是否为 CentOS 7
if [[ ! -f /etc/centos-release ]]; then
  echo "此脚本仅适用于 CentOS 7。"
  exit 1
fi

# 提取 CentOS 完整的版本号并去除后缀（例如 7.7.1908）
CENTOS_VERSION=$(rpm -q --qf "%{VERSION}.%{RELEASE}\n" centos-release)
CENTOS_MAJOR=$(echo $CENTOS_VERSION | cut -d "." -f1)   # 提取主版本号 (例如 7)
CENTOS_FULL=$(echo $CENTOS_VERSION | cut -d "." -f1,2,3)  # 提取主版本号和年月编码 (例如 7.7.1908)

echo "检测到的 CentOS 版本为: $CENTOS_FULL"

# 确认版本是否为 CentOS 7 系列
if [[ "$CENTOS_MAJOR" != "7" ]]; then
  echo "此脚本仅适用于 CentOS 7 系列系统。"
  exit 1
fi

# 询问是否在中国大陆
read -p "你是否在中国大陆？(y/n): " IS_CHINA

# 设置 vault URL，根据检测到的版本号设置精确路径
if [[ "$IS_CHINA" == "y" || "$IS_CHINA" == "Y" ]]; then
  VAULT_BASE_URL="http://mirrors.tuna.tsinghua.edu.cn/centos-vault/$CENTOS_FULL/"
else
  VAULT_BASE_URL="https://vault.centos.org/$CENTOS_FULL/"
fi

echo "使用的 Vault 源为: $VAULT_BASE_URL"

# 创建备份目录
BACKUP_DIR="/etc/yum.repos.d/bak"
mkdir -p $BACKUP_DIR

# 备份失效的 .repo 文件
for repo in /etc/yum.repos.d/*.repo; do
  if ! curl -s --head $(grep -E '^baseurl=' "$repo" | cut -d= -f2 | head -n1) | grep "200 OK" > /dev/null; then
    mv "$repo" "$BACKUP_DIR/"
    echo "$repo 已备份至 $BACKUP_DIR"
  fi
done

# 创建新的 CentOS Vault repo 文件，按分类设置
cat <<EOL > /etc/yum.repos.d/CentOS-Vault.repo
[Vault-base]
name=Vault - CentOS-\$releasever - Base
baseurl=$VAULT_BASE_URL/os/\$basearch/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[Vault-updates]
name=Vault - CentOS-\$releasever - Updates
baseurl=$VAULT_BASE_URL/updates/\$basearch/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[Vault-extras]
name=Vault - CentOS-\$releasever - Extras
baseurl=$VAULT_BASE_URL/extras/\$basearch/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[Vault-centosplus]
name=Vault - CentOS-\$releasever - Plus
baseurl=$VAULT_BASE_URL/centosplus/\$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOL

# 创建 EPEL 的 repo 文件（过时的 EPEL 源）
cat <<EOL > /etc/yum.repos.d/epel-vault.repo
[epel-vault]
name=Extra Packages for Enterprise Linux 7 - \$basearch
baseurl=https://archives.fedoraproject.org/pub/archive/epel/7/\$basearch/
failovermethod=priority
enabled=1
gpgcheck=0
gpgkey=https://archives.fedoraproject.org/pub/archive/epel/RPM-GPG-KEY-EPEL
EOL

# 禁用 yum 插件（将 plugins 设置为 0）
sed -i 's/^plugins=.*/plugins=0/' /etc/yum.conf

# 测试配置是否生效
echo "正在测试新配置..."

yum clean all

if yum --noplugins repolist | grep -q "^Vault-base"; then
  echo "仓库配置成功！"
else
  echo "仓库配置失败，请检查网络连接或配置。"
  exit 1
fi

