# Debian 从 0 到 1 环境配置

适用于 **Debian 11 / 12**。本机只装构建与运行组件；**不安装**本机 MySQL / Redis / Apollo（使用远程）。

## 1. 系统要求

- root 或 sudo
- 可访问外网（apt、NodeSource、Jenkins 官方源）
- 网络可达：Git 仓库、远程 Apollo Meta、远程 MySQL、远程 Redis

## 2. 一键安装（推荐）

在已克隆的仓库根目录执行：

```bash
sudo bash script/shell/setup-debian.sh
```

脚本会安装并配置：

| 组件 | 说明 |
|------|------|
| OpenJDK 17 | 编译 / 运行后端 |
| Maven | `mvn package` |
| Node.js 20 + pnpm 9 | 前端构建 |
| Nginx | 静态站点 + `/admin-api` 反代 |
| Jenkins | CI 拉代码编译部署 |
| Git / curl | 检出与健康检查 |
| `/work/projects/...` | 部署目录，属主 `jenkins` |
| `yudao-admin.conf` | 拷到 `/etc/nginx/conf.d/` |

安装结束后按屏幕提示查看 Jenkins 初始密码，浏览器打开 `http://服务器IP:8080`。

## 3. 分步手工命令（与脚本一致，便于排错）

### 3.1 基础包

```bash
sudo apt-get update -y
sudo apt-get install -y curl wget git ca-certificates gnupg unzip \
  apt-transport-https software-properties-common netcat-openbsd fontconfig
```

### 3.2 OpenJDK 17

```bash
sudo apt-get install -y openjdk-17-jdk
java -version
```

### 3.3 Maven

```bash
sudo apt-get install -y maven
mvn -v
```

### 3.4 Node.js 20 + pnpm

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
  | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update -y
sudo apt-get install -y nodejs
sudo npm install -g pnpm@9
node -v && pnpm -v
```

### 3.5 Nginx

```bash
sudo apt-get install -y nginx
sudo systemctl enable --now nginx
# 仓库内执行：
sudo cp script/nginx/yudao-admin.conf /etc/nginx/conf.d/yudao-admin.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

### 3.6 Jenkins

```bash
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list
sudo apt-get update -y
sudo apt-get install -y jenkins
sudo systemctl enable --now jenkins
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 3.7 部署目录

```bash
sudo bash script/shell/setup-dirs.sh
sudo chown -R jenkins:jenkins /work/projects
```

## 4. 远程中间件连通检查

将下面地址换成实际值：

```bash
# Apollo Meta（HTTP）
curl -I -m 5 http://<APOLLO_META_HOST>:<PORT>/

# MySQL 端口
nc -vz <MYSQL_HOST> 3306

# Redis 端口
nc -vz <REDIS_HOST> 6379
```

全部通后再做库初始化与首次部署。

## 5. 远程库初始化

本机不装 MySQL，对远程库执行：

```bash
export MYSQL_HOST=<远程IP>
export MYSQL_PORT=3306
export MYSQL_USER=root
export MYSQL_PASSWORD=<密码>
export MYSQL_DATABASE=ruoyi-vue-pro
bash script/shell/init-db.sh
```

Apollo Portal 核对：

- `app.id` = `qCdREtShftb8BS5vlllIODvlTf7TNyMn`
- namespace = `application`
- datasource / redis / `server.port`（建议 `48080`）与远程一致

## 6. Jenkins Job

1. 打开 `http://服务器IP:8080`，装推荐插件，建管理员
2. New Item → Pipeline
3. Pipeline script from SCM：指向本仓库，脚本路径 `script/jenkins/Jenkinsfile`  
   或直接粘贴仓库内 Jenkinsfile 内容
4. 首次构建参数填写：
   - `GIT_URL` / `GIT_BRANCH`
   - `APOLLO_META` = 远程 Meta 地址
   - `APOLLO_ENV` = `DEV` / `UAT` / `PRO`
   - `VITE_BASE_URL` = 站点对外地址（如 `http://服务器IP`）
5. Agent 需能执行 `java`/`mvn`/`node`/`pnpm`，且可写 `/work/projects/`（脚本已 chown 给 `jenkins`）

若 Pipeline 找不到 `pnpm`，在 Jenkins 节点环境变量 PATH 中加入 npm 全局 bin（常见 `/usr/bin` 或 `/usr/local/bin`）。

## 7. 防火墙

放行：

| 端口 | 用途 |
|------|------|
| 80 | Nginx 管理后台 |
| 8080 | Jenkins |

后端 `48080` 仅本机 Nginx 反代访问，**可不对公网开放**。

ufw 示例：

```bash
sudo ufw allow 80/tcp
sudo ufw allow 8080/tcp
sudo ufw enable
```

## 8. 验收

```bash
java -version
mvn -v
node -v && pnpm -v
nginx -v
git --version
systemctl is-active nginx jenkins
ls /work/projects/yudao-server /work/projects/yudao-ui-admin
sudo nginx -t
```

首次业务部署成功后：

```bash
bash script/shell/verify-deploy.sh
```

更完整的发布说明见 [DEPLOY.md](./DEPLOY.md)。
