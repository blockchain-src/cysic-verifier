
# Cysic-verifier 安装与启动指南

## 🖥️ **支持平台**

- ![macOS](https://img.shields.io/badge/-macOS-000000?logo=apple&logoColor=white)
- ![Linux](https://img.shields.io/badge/-Linux-FCC624?logo=linux&logoColor=black)


## 1️⃣克隆 github 仓库
```bash
git clone https://github.com/blockchain-src/cysic-verifier.git && cd cysic-verifier
```
---
## 2️⃣安装 Node.js 和 pm2（如已安装可跳过）
```bash
chmod +x install.sh && sudo ./install.sh
```
---
## 3️⃣安装交互式脚本
- 首次安装与启动
```bash
chmod +x cysic.sh && sudo ./cysic.sh
```

- 后续启动
```bash
./cysic.sh
```