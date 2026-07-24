# Jenkins 传统部署说明（JAR + Nginx + Apollo）

> **Debian 从 0 到 1 装机**：见 [SETUP-DEBIAN.md](./SETUP-DEBIAN.md)（一键脚本 [`setup-debian.sh`](./setup-debian.sh)）。  
> 本机不装 MySQL/Redis/Apollo 时，按该文档检查远程连通后再继续下面步骤。

## 1. 一次性环境准备

```bash
# Debian 推荐：一键安装 JDK/Maven/Node/pnpm/Nginx/Jenkins + 目录 + Nginx 站点
sudo bash script/shell/setup-debian.sh

# 或仅创建部署目录并自检工具链
bash script/shell/setup-dirs.sh

# 首次初始化数据库（远程库示例）
export MYSQL_HOST=<远程IP> MYSQL_USER=root MYSQL_PASSWORD=你的密码
bash script/shell/init-db.sh
```

Apollo Portal 确认：

- `app.id` = `qCdREtShftb8BS5vlllIODvlTf7TNyMn`
- namespace = `application`
- 已配置 datasource / redis / `server.port`（建议 `48080`）

安装 Nginx 站点：

```bash
sudo cp script/nginx/yudao-admin.conf /etc/nginx/conf.d/yudao-admin.conf
# 按需修改 server_name
sudo nginx -t && sudo systemctl reload nginx
```

## 2. Jenkins Job

1. 新建 Pipeline Job
2. Pipeline script from SCM，或直接使用仓库内 [`script/jenkins/Jenkinsfile`](../jenkins/Jenkinsfile)
3. Agent 需具备：JDK17、Maven、Node、pnpm，且可写 `/work/projects/`
4. 构建参数：
   - `GIT_URL` / `GIT_BRANCH`
   - `DEPLOY_SCOPE`：`all` | `backend` | `frontend`
   - `APOLLO_META` / `APOLLO_ENV`
   - `VITE_BASE_URL`（可选，覆盖生产前端基址）

## 3. 目录约定

| 用途 | 路径 |
|------|------|
| 后端 | `/work/projects/yudao-server` |
| 前端静态 | `/work/projects/yudao-ui-admin` |
| 后端日志 | `/work/projects/yudao-server/logs/nohup.out` |

## 4. 验收清单

Jenkins 构建成功后，在部署机执行：

```bash
bash script/shell/verify-deploy.sh
# 或自定义:
# UI_URL=http://your.domain.com/ bash script/shell/verify-deploy.sh
```

人工确认：

- [ ] Jenkins 阶段全部成功
- [ ] `curl -I http://127.0.0.1:48080/actuator/health/` 返回 200
- [ ] 后端日志无 Apollo Meta 连接失败
- [ ] 浏览器打开 Nginx 地址可进入登录页
- [ ] `/admin-api` 接口正常

## 5. 相关脚本

- [`SETUP-DEBIAN.md`](./SETUP-DEBIAN.md) / [`setup-debian.sh`](./setup-debian.sh) — Debian 从 0 到 1 环境
- [`setup-dirs.sh`](./setup-dirs.sh) — 创建部署目录
- [`init-db.sh`](./init-db.sh) — 初始化 MySQL（可连远程）
- [`deploy.sh`](./deploy.sh) — 后端热替换与重启（含 Apollo 参数）
- [`verify-deploy.sh`](./verify-deploy.sh) — 部署后冒烟验收
- [`../nginx/yudao-admin.conf`](../nginx/yudao-admin.conf) — Nginx 样例
- [`../jenkins/Jenkinsfile`](../jenkins/Jenkinsfile) — 流水线
