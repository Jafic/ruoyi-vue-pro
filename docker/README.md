# Docker Compose 部署说明

本目录包含用于快速部署 ruoyi-vue-pro 项目所需的 MySQL 和 Redis 服务的 Docker Compose 配置文件。

## 文件说明

- `docker-compose.yaml`: Docker Compose 配置文件
- `docker.env`: 环境变量配置文件

## 服务说明

### MySQL 8
- 端口: 3306
- 数据库名: ruoyi-vue-pro
- root 密码: 123456（可在 docker.env 中修改）
- 字符集: utf8mb4
- 排序规则: utf8mb4_general_ci
- 数据持久化: mysql_data 卷

### Redis 7
- 端口: 6379
- 密码: 123456（可在 docker.env 中修改）
- 数据持久化: redis_data 卷（开启 AOF 持久化）

## 快速开始

### 启动服务

```bash
# 进入 docker 目录
cd docker

# 启动所有服务（后台运行）
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看服务日志
docker-compose logs -f
```

### 停止服务

```bash
# 停止服务
docker-compose stop

# 停止并移除容器
docker-compose down

# 停止并移除容器及数据卷（慎用，会删除数据）
docker-compose down -v
```

### 管理单个服务

```bash
# 启动 MySQL
docker-compose up -d mysql

# 启动 Redis
docker-compose up -d redis

# 重启服务
docker-compose restart mysql
docker-compose restart redis
```

## 配置说明

可以通过修改 `docker.env` 文件来自定义配置：

```env
# MySQL 配置
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=123456
MYSQL_DATABASE=ruoyi-vue-pro
MYSQL_ROOT_HOST=%
TZ=Asia/Shanghai

# Redis 配置
REDIS_PORT=6379
REDIS_PASSWORD=123456
```

修改配置后，需要重新启动服务：

```bash
docker-compose down
docker-compose up -d
```

## 数据备份

### MySQL 备份

```bash
# 备份数据库
docker exec mysql8 mysqldump -uroot -p123456 ruoyi-vue-pro > backup.sql

# 恢复数据库
docker exec -i mysql8 mysql -uroot -p123456 ruoyi-vue-pro < backup.sql
```

### Redis 备份

```bash
# 备份 Redis 数据
docker exec redis redis-cli -a 123456 save

# 复制备份文件
docker cp redis:/data/dump.rdb ./redis-backup.rdb
```

## 连接信息

### MySQL 连接信息
- 主机: localhost
- 端口: 3306
- 用户名: root
- 密码: 123456
- 数据库: ruoyi-vue-pro

### Redis 连接信息
- 主机: localhost
- 端口: 6379
- 密码: 123456

## 注意事项

1. 生产环境请修改默认密码
2. 数据持久化在 Docker 卷中，删除容器不会丢失数据
3. 如需清空数据，使用 `docker-compose down -v` 命令
4. 确保主机的 3306 和 6379 端口未被占用

