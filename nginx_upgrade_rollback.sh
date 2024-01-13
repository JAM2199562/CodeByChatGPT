#!/bin/bash

upgrade_nginx() {
    # 备份当前的Nginx配置
    echo "Backing up current Nginx configuration..."
    sudo cp -r /etc/nginx /etc/nginx-backup

    # 停止当前的Nginx服务
    echo "Stopping Nginx..."
    sudo service nginx stop

    # 移除旧版本的Nginx
    echo "Removing old Nginx version..."
    sudo yum -y remove nginx

    # 安装新版本的Nginx
    echo "Installing new Nginx version..."
    sudo cp /opt/software/nginx-1.25.2/objs/nginx /usr/sbin/nginx
    sudo chmod +x /usr/sbin/nginx

    # 启动新版本的Nginx
    echo "Starting new Nginx version..."
    sudo service nginx start

    # 验证Nginx版本
    nginx -v

    echo "Nginx version upgrade completed."

    # 设置Nginx开机自启
    sudo chkconfig nginx on
}

rollback_nginx() {
    # 停止当前的Nginx服务
    echo "Stopping Nginx..."
    sudo service nginx stop

    # 移除新版本的Nginx
    echo "Removing new Nginx version..."
    sudo yum -y remove nginx

    # 恢复旧版本的Nginx配置
    echo "Restoring old Nginx configuration..."
    sudo cp -r /etc/nginx-backup /etc/nginx

    # 启动旧版本的Nginx
    echo "Starting old Nginx version..."
    sudo service nginx start

    echo "Nginx version rollback completed."
}

show_menu() {
    echo "1. 升级"
    echo "2. 回滚"
    echo "3. 退出"
    read -p "请选择一个操作： " choice

    case $choice in
        1) upgrade_nginx ;;
        2) rollback_nginx ;;
        3) exit 0 ;;
        *) echo "无效的选择，请重新选择。" && show_menu ;;
    esac
}

show_menu
