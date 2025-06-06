#!/bin/bash

# 确保以 root 权限运行 (仅限 Linux)
# macOS 下不建议直接以 root 运行 npm/pm2 安装
if [ "$(uname)" == "Linux" ]; then
    if [ "$(id -u)" -ne 0 ]; then
        echo "请使用 root 权限运行此脚本（例如使用 sudo）。"
        exit 1
    fi
fi

# 检测操作系统
OS="$(uname -s)"

case "${OS}" in
    Linux*)
        # Linux 安装步骤
        echo "检测到 Linux 系统..."

        # 更新系统
        echo "更新系统中..."
        apt update && apt upgrade -y

        # 安装 Node.js 18.x
        echo "安装 Node.js 18.x 中..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt install nodejs -y

        # 安装 pm2
        echo "安装 pm2 中..."
        npm install -g pm2
        ;;
    Darwin*)
        # macOS 安装步骤
        echo "检测到 macOS 系统..."

        # 检查或安装 Homebrew
        if ! command -v brew &> /dev/null
        then
            echo "未检测到 Homebrew，正在安装..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi

        # 安装 Node.js
        echo "安装 Node.js 中..."
        brew install node

        # 安装 pm2
        echo "安装 pm2 中..."
        npm install -g pm2
        ;;
    *)
        echo "不支持的操作系统: ${OS}"
        exit 1
        ;;
esac

# 验证安装
echo "验证安装..."
node -v && npm -v && pm2 --version

echo "所有操作完成！"
