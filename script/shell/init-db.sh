#!/bin/bash
# 一次性：初始化 MySQL 业务库（需在仓库根目录或传入 SQL 路径）
# 用法:
#   export MYSQL_USER=root MYSQL_PASSWORD=xxx MYSQL_HOST=127.0.0.1
#   bash script/shell/init-db.sh
# 或: bash script/shell/init-db.sh /path/to/ruoyi-vue-pro.sql
set -e

MYSQL_HOST=${MYSQL_HOST:-127.0.0.1}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_USER=${MYSQL_USER:-root}
MYSQL_DATABASE=${MYSQL_DATABASE:-ruoyi-vue-pro}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
SQL_FILE=${1:-"$REPO_ROOT/sql/mysql/ruoyi-vue-pro.sql"}

if [ ! -f "$SQL_FILE" ]; then
  echo "[init-db] SQL 文件不存在: $SQL_FILE"
  exit 1
fi

MYSQL_PWD_ARGS=()
if [ -n "${MYSQL_PASSWORD:-}" ]; then
  export MYSQL_PWD="$MYSQL_PASSWORD"
fi

echo "[init-db] 创建数据库 $MYSQL_DATABASE @ ${MYSQL_HOST}:${MYSQL_PORT}"
mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -e \
  "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "[init-db] 导入 $SQL_FILE"
mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" "$MYSQL_DATABASE" < "$SQL_FILE"

if [ -f "$REPO_ROOT/sql/mysql/quartz.sql" ]; then
  echo "[init-db] 可选: 如需 quartz 表，请手动执行 sql/mysql/quartz.sql"
fi

echo "[init-db] 完成。请在 Apollo Portal 核对:"
echo "  - app.id = qCdREtShftb8BS5vlllIODvlTf7TNyMn"
echo "  - namespace = application"
echo "  - spring.datasource.dynamic.datasource.master.* 与本库一致"
echo "  - spring.data.redis.host/port/password"
echo "  - server.port（建议 48080）"
