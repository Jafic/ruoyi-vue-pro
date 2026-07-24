#!/bin/bash
# 部署后验收（在部署机执行）
# 用法: bash script/shell/verify-deploy.sh
set -e

HEALTH_CHECK_URL=${HEALTH_CHECK_URL:-http://127.0.0.1:48080/actuator/health/}
UI_URL=${UI_URL:-http://127.0.0.1/}
BACKEND_LOG=${BACKEND_LOG:-/work/projects/yudao-server/logs/nohup.out}
UI_DIR=${UI_DIR:-/work/projects/yudao-ui-admin}

PASS=0
FAIL=0

check() {
  local name=$1
  shift
  if "$@"; then
    echo "[OK] $name"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $name"
    FAIL=$((FAIL + 1))
  fi
}

echo "==== 部署验收 ===="

code=$(curl -I -m 10 -o /dev/null -s -w %{http_code} "$HEALTH_CHECK_URL" || echo "000")
check "后端健康检查 $HEALTH_CHECK_URL => $code" test "$code" = "200"

if [ -f "$BACKEND_LOG" ]; then
  if grep -qiE 'apollo.*(fail|error|unable to|Connection refused)' "$BACKEND_LOG"; then
    echo "[FAIL] 后端日志疑似 Apollo 连接失败，请检查 $BACKEND_LOG"
    FAIL=$((FAIL + 1))
  else
    echo "[OK] 后端日志未见明显 Apollo 连接失败关键字"
    PASS=$((PASS + 1))
  fi
else
  echo "[FAIL] 后端日志不存在: $BACKEND_LOG"
  FAIL=$((FAIL + 1))
fi

check "前端目录存在 index.html" test -f "$UI_DIR/index.html"

ui_code=$(curl -I -m 10 -o /dev/null -s -w %{http_code} "$UI_URL" || echo "000")
check "Nginx 站点 $UI_URL => $ui_code" test "$ui_code" = "200" -o "$ui_code" = "301" -o "$ui_code" = "302"

api_code=$(curl -I -m 10 -o /dev/null -s -w %{http_code} "${UI_URL%/}/admin-api/" || echo "000")
# 后端可能返回 401/404/405，只要不是 502/000 即说明反代通了
check "API 反代可达 (HTTP $api_code，非 502/000)" test "$api_code" != "000" -a "$api_code" != "502" -a "$api_code" != "504"

echo "==== 结果: PASS=$PASS FAIL=$FAIL ===="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "请人工确认：浏览器打开 $UI_URL 可登录，业务接口正常。"
