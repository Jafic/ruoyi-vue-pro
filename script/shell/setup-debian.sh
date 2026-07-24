#!/bin/bash
# Debian 11/12：从 0 到 1 安装本机构建/运行组件
# 不安装本机 MySQL / Redis / Apollo（使用远程）
# 用法（需 root）:
#   sudo bash script/shell/setup-debian.sh
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
NGINX_CONF_SRC="$REPO_ROOT/script/nginx/yudao-admin.conf"
BACKEND_BASE=${BACKEND_BASE:-/work/projects/yudao-server}
UI_DEPLOY_DIR=${UI_DEPLOY_DIR:-/work/projects/yudao-ui-admin}
NODE_MAJOR=${NODE_MAJOR:-20}

if [ "$(id -u)" -ne 0 ]; then
  echo "[error] 请使用 root 执行: sudo bash $0"
  exit 1
fi

if [ ! -f /etc/debian_version ]; then
  echo "[error] 当前系统不是 Debian（未找到 /etc/debian_version）"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "==== [1/8] apt 基础包 ===="
apt-get update -y
apt-get install -y \
  curl wget git ca-certificates gnupg unzip \
  apt-transport-https software-properties-common \
  netcat-openbsd fontconfig

echo "==== [2/8] OpenJDK 17 ===="
apt-get install -y openjdk-17-jdk
java -version

echo "==== [3/8] Maven ===="
apt-get install -y maven
mvn -v

echo "==== [4/8] Node.js ${NODE_MAJOR} LTS + pnpm ===="
if ! command -v node >/dev/null 2>&1 || ! node -v | grep -qE "v${NODE_MAJOR}\\."; then
  mkdir -p /etc/apt/keyrings
  curl -fsSL "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
  apt-get update -y
  apt-get install -y nodejs
fi
npm install -g pnpm@9
node -v
pnpm -v

echo "==== [5/8] Nginx ===="
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx
nginx -v

echo "==== [6/8] Jenkins ===="
if ! command -v jenkins >/dev/null 2>&1 && [ ! -f /usr/share/jenkins/jenkins.war ]; then
  curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
    | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list
  apt-get update -y
  # Jenkins 官方包依赖 Java；已装 17，满足运行要求
  apt-get install -y jenkins
fi
systemctl enable jenkins
systemctl start jenkins || true
sleep 2
systemctl is-active jenkins || echo "[warn] Jenkins 可能仍在启动，稍后 systemctl status jenkins"

echo "==== [7/8] 部署目录与权限 ===="
bash "$SCRIPT_DIR/setup-dirs.sh"
# Pipeline 默认以 jenkins 用户跑 Agent 任务
if id jenkins >/dev/null 2>&1; then
  chown -R jenkins:jenkins /work/projects
  # 允许 jenkins 使用本机 java/mvn/node（PATH 已全局）
  echo "[setup] /work/projects 属主已设为 jenkins:jenkins"
else
  echo "[warn] 未找到 jenkins 用户，请手动 chown 部署目录给构建用户"
fi

echo "==== [8/8] Nginx 站点配置 ===="
if [ -f "$NGINX_CONF_SRC" ]; then
  cp -f "$NGINX_CONF_SRC" /etc/nginx/conf.d/yudao-admin.conf
  # Debian 默认站点可能抢占 80，避免冲突则禁用
  if [ -L /etc/nginx/sites-enabled/default ]; then
    rm -f /etc/nginx/sites-enabled/default
    echo "[setup] 已禁用 sites-enabled/default"
  fi
  nginx -t
  systemctl reload nginx
  echo "[setup] 已安装 /etc/nginx/conf.d/yudao-admin.conf"
else
  echo "[warn] 未找到 $NGINX_CONF_SRC，跳过 Nginx 站点拷贝"
fi

echo ""
echo "======== 安装完成：版本自检 ========"
java -version 2>&1 | head -n 1
mvn -v 2>&1 | head -n 1
echo "node $(node -v)  pnpm $(pnpm -v)"
nginx -v 2>&1
git --version
systemctl is-active nginx && echo "nginx: active"
systemctl is-active jenkins && echo "jenkins: active" || echo "jenkins: 请稍后检查"

if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
  echo ""
  echo "[Jenkins] 初始管理员密码:"
  cat /var/lib/jenkins/secrets/initialAdminPassword
  echo ""
  echo "[Jenkins] 浏览器访问: http://$(hostname -I 2>/dev/null | awk '{print $1}'):8080"
fi

echo ""
echo "======== 后续手工步骤（远程中间件）========"
echo "1. 确认本机可访问远程 Apollo Meta / MySQL:3306 / Redis:6379"
echo "2. 远程库初始化:"
echo "     export MYSQL_HOST=<远程IP> MYSQL_USER=root MYSQL_PASSWORD=<密码>"
echo "     bash $SCRIPT_DIR/init-db.sh"
echo "3. Apollo Portal 配置 datasource/redis/server.port，Jenkins 参数填 APOLLO_META / APOLLO_ENV"
echo "4. 新建 Pipeline Job，脚本路径: script/jenkins/Jenkinsfile"
echo "5. 防火墙放行: 80(站点) 8080(Jenkins)；48080 仅本机反代可不对外"
echo "详情见: $SCRIPT_DIR/SETUP-DEBIAN.md"
