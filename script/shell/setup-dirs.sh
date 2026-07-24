#!/bin/bash
# 一次性：在 Linux 部署机创建后端/前端目录结构
# 用法: sudo bash script/shell/setup-dirs.sh
set -e

BACKEND_BASE=${BACKEND_BASE:-/work/projects/yudao-server}
UI_DEPLOY_DIR=${UI_DEPLOY_DIR:-/work/projects/yudao-ui-admin}

echo "[setup] 创建后端目录: $BACKEND_BASE"
mkdir -p "$BACKEND_BASE"/{build,backup,heapError,logs}

echo "[setup] 创建前端发布目录: $UI_DEPLOY_DIR"
mkdir -p "$UI_DEPLOY_DIR"

echo "[setup] 目录就绪。请确认本机已安装:"
echo "  - JDK 17+"
echo "  - Maven 3.8+"
echo "  - Node.js >= 16.18 与 pnpm >= 8.6"
echo "  - Nginx"
echo "  - Jenkins（Agent 需能写上述目录）"
echo "  - 网络可达: Git / Apollo Meta / MySQL / Redis"
echo ""
echo "[setup] 版本自检（失败仅提示，不中断）:"
java -version 2>&1 | head -n 1 || echo "  [!] 未检测到 java"
mvn -v 2>&1 | head -n 1 || echo "  [!] 未检测到 mvn"
node -v 2>/dev/null || echo "  [!] 未检测到 node"
pnpm -v 2>/dev/null || echo "  [!] 未检测到 pnpm"
nginx -v 2>&1 || echo "  [!] 未检测到 nginx"
echo "[setup] 完成"
