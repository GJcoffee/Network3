#!/bin/bash

set -e  # Exit on error
set -x

apt-get update
apt-get install -y curl jq

server_host="http://46.250.249.247:9670"
local_ip=$(curl -s ifconfig.me)
#local_ip=$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -vE '127\.0\.0\.1|172\.(1[6-9]|2[0-9]|3[0-1])' | head -n 1)

get_nexus_api="$server_host/get/nexus/hostip/?hostIP=$local_ip"

# Check Docker installation
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Get container data
data=$(curl -s -X GET "$get_nexus_api")
echo "数据：$data"
if [ -z "$data" ]; then
    echo "Failed to get container data from API"
    exit 1
fi
readarray -t containers < <(echo "$data" | jq -c '.[]')

echo "================================解析到数据================================="
echo "数据：$data"

# 创建要在容器内执行的脚本
create_container_script() {
    local prover_id="$1"
    cat > container_script.sh << EOF
#!/bin/sh

# 检查是否已经在 nohup 模式下运行
if [ "\$NOHUP_ACTIVE" != "true" ]; then
    # 设置环境变量标记 nohup 状态
    export NOHUP_ACTIVE=true
    
    # 创建日志目录
    NEXUS_HOME=\$HOME/.nexus
    LOG_DIR=\$NEXUS_HOME/logs
    mkdir -p \$LOG_DIR
    
    # 使用带时间戳的日志文件名
    LOG_FILE=\$LOG_DIR/nexus-prover-\$(date +%Y%m%d_%H%M%S).log
    
    # 将自身在后台运行
    echo "启动 Nexus prover 在后台..."
    echo "日志文件: \$LOG_FILE"
    nohup \$0 > "\$LOG_FILE" 2>&1 &
    exit 0
fi

# 以下是主程序逻辑
set -e

# 安装基本依赖
apt-get update
apt-get install -y git curl build-essential pkg-config libssl-dev protobuf-compiler

# 确保 OpenSSL 开发包已安装
if [ ! -f "/usr/include/openssl/ssl.h" ]; then
    echo "正在安装 OpenSSL 开发包..."
    apt-get install -y libssl-dev
fi

# 安装 Rust（如果未安装）
command -v rustc >/dev/null 2>&1 || {
    echo "正在安装 Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    . \$HOME/.cargo/env
}

# 设置环境变量
NEXUS_HOME=\$HOME/.nexus
mkdir -p \$NEXUS_HOME

# 写入 prover-id
echo "写入 prover-id: $prover_id"
echo "$prover_id" > \$NEXUS_HOME/prover-id

# 处理仓库
REPO_PATH=\$NEXUS_HOME/network-api
if [ -d "\$REPO_PATH" ]; then
    echo "更新已存在的仓库..."
    (cd \$REPO_PATH && git stash save && git fetch --tags)
else
    echo "克隆仓库..."
    (cd \$NEXUS_HOME && git clone https://github.com/nexus-xyz/network-api)
fi

# 检出最新标签
(cd \$REPO_PATH && git -c advice.detachedHead=false checkout \$(git rev-list --tags --max-count=1))

# 构建并运行 prover
echo "构建并运行 prover..."
cd \$REPO_PATH/clients/cli && . \$HOME/.cargo/env && cargo run --release --bin prover -- beta.orchestrator.nexus.xyz
EOF

    chmod +x container_script.sh
}

# Process containers
for record in "${containers[@]}"; do
    docker_name=$(echo "$record" | jq -r '.docker_name')
    address=$(echo "$record" | jq -r '.address')
    prover_id=$(echo "$record" | jq -r '.prover_id')  # 获取 prover_id

    if [ ! "$(docker ps -a -q -f name=$docker_name)" ]; then
        echo "Creating container $docker_name"
        
        echo "开始拉取ubuntu======================"

        create_container_script "$prover_id"  # 传入 prover_id
        # Create container
        docker run -d --name $docker_name ubuntu:22.04 tail -f /dev/null
        docker cp container_script.sh $docker_name:/root/
        docker exec $docker_name /bin/bash -c "cd /root && ./container_script.sh"
   
        echo "Container $docker_name created and running successfully 容器创建和运行成功，包括配置文件"
    else
        echo "Container $docker_name already exists, skipping 容器已经存在，无须执行"
    fi
done

docker_names=$(docker ps --format '{{.Names}}' | grep '^nexus')
docker_names_json=$(echo "$docker_names" | jq -R -s 'split("\n") | map(select(length > 0))')
curl -X PUT "$server_host/nexus/host/" \
    -H "Content-Type: application/json" \
    -d "{
        \"ip_host\": \"$local_ip\",
        \"docker_name\": $docker_names_json
    }"

# git clone https://github.com/GJcoffee/Network3.git .network3 && cd .network3 && docker compose up -d
