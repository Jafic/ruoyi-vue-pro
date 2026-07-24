#!/bin/bash
set -e

DATE=$(date +%Y%m%d%H%M)
# 基础路径（可通过环境变量覆盖）
BASE_PATH=${BASE_PATH:-/work/projects/yudao-server}
# 编译后 jar 的地址。部署时，Jenkins 会上传 jar 包到该目录下
SOURCE_PATH=${SOURCE_PATH:-$BASE_PATH/build}
# 服务名称。同时约定部署服务的 jar 包名字也为它。
SERVER_NAME=${SERVER_NAME:-yudao-server}
# Spring profile（数据源等仍以 Apollo 为准）
PROFILES_ACTIVE=${PROFILES_ACTIVE:-local}
# 健康检查 URL
HEALTH_CHECK_URL=${HEALTH_CHECK_URL:-http://127.0.0.1:48080/actuator/health/}

# Apollo（可由 Jenkins environment 注入）
APOLLO_META=${APOLLO_META:-http://127.0.0.1:8080}
APOLLO_ENV=${APOLLO_ENV:-DEV}

# heapError / 日志路径
HEAP_ERROR_PATH=$BASE_PATH/heapError
LOG_PATH=$BASE_PATH/logs
# JVM 参数
JAVA_OPS=${JAVA_OPS:-"-Xms512m -Xmx512m -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$HEAP_ERROR_PATH"}

# SkyWalking Agent 配置
#export SW_AGENT_NAME=$SERVER_NAME
#export SW_AGENT_COLLECTOR_BACKEND_SERVICES=192.168.0.84:11800
#export SW_GRPC_LOG_SERVER_HOST=192.168.0.84
#export SW_AGENT_TRACE_IGNORE_PATH="Redisson/PING,/actuator/**,/admin/**"
#export JAVA_AGENT=-javaagent:/work/skywalking/apache-skywalking-apm-bin/agent/skywalking-agent.jar

mkdir -p "$BASE_PATH"/{build,backup,heapError,logs}

# 备份
function backup() {
    if [ ! -f "$BASE_PATH/$SERVER_NAME.jar" ]; then
        echo "[backup] $BASE_PATH/$SERVER_NAME.jar 不存在，跳过备份"
    else
        echo "[backup] 开始备份 $SERVER_NAME ..."
        cp "$BASE_PATH/$SERVER_NAME.jar" "$BASE_PATH/backup/$SERVER_NAME-$DATE.jar"
        echo "[backup] 备份 $SERVER_NAME 完成"
    fi
}

# 最新构建代码 移动到项目环境
function transfer() {
    echo "[transfer] 开始转移 $SERVER_NAME.jar"

    if [ ! -f "$SOURCE_PATH/$SERVER_NAME.jar" ]; then
        # 兼容 target 产物可能带版本号的情况：取 build 目录下最新 jar
        LATEST_JAR=$(ls -t "$SOURCE_PATH"/*.jar 2>/dev/null | head -n 1 || true)
        if [ -z "$LATEST_JAR" ]; then
            echo "[transfer] 未找到 jar: $SOURCE_PATH/$SERVER_NAME.jar"
            exit 1
        fi
        echo "[transfer] 使用 $LATEST_JAR"
        cp "$LATEST_JAR" "$BASE_PATH/$SERVER_NAME.jar"
    else
        if [ -f "$BASE_PATH/$SERVER_NAME.jar" ]; then
            echo "[transfer] 移除旧 $BASE_PATH/$SERVER_NAME.jar"
            rm -f "$BASE_PATH/$SERVER_NAME.jar"
        fi
        echo "[transfer] 从 $SOURCE_PATH 复制 $SERVER_NAME.jar"
        cp "$SOURCE_PATH/$SERVER_NAME.jar" "$BASE_PATH/"
    fi

    echo "[transfer] 转移 $SERVER_NAME.jar 完成"
}

# 停止：优雅关闭之前已经启动的服务
function stop() {
    echo "[stop] 开始停止 $BASE_PATH/$SERVER_NAME"
    PID=$(ps -ef | grep "$BASE_PATH/$SERVER_NAME" | grep -v "grep" | awk '{print $2}')
    if [ -n "$PID" ]; then
        echo "[stop] $BASE_PATH/$SERVER_NAME 运行中，开始 kill [$PID]"
        kill -15 $PID
        for ((i = 0; i < 120; i++))
            do
                sleep 1
                PID=$(ps -ef | grep "$BASE_PATH/$SERVER_NAME" | grep -v "grep" | awk '{print $2}')
                if [ -n "$PID" ]; then
                    echo -e ".\c"
                else
                    echo "[stop] 停止 $BASE_PATH/$SERVER_NAME 成功"
                    break
                fi
            done

        if [ -n "$PID" ]; then
            echo "[stop] $BASE_PATH/$SERVER_NAME 失败，强制 kill -9 $PID"
            kill -9 $PID
        fi
    else
        echo "[stop] $BASE_PATH/$SERVER_NAME 未启动，无需停止"
    fi
}

# 启动：启动后端项目
function start() {
    echo "[start] 开始启动 $BASE_PATH/$SERVER_NAME"
    echo "[start] JAVA_OPS: $JAVA_OPS"
    echo "[start] JAVA_AGENT: ${JAVA_AGENT:-}"
    echo "[start] PROFILES: $PROFILES_ACTIVE"
    echo "[start] APOLLO_META: $APOLLO_META"
    echo "[start] APOLLO_ENV: $APOLLO_ENV"

    cd "$BASE_PATH"
    BUILD_ID=dontKillMe nohup java -server $JAVA_OPS ${JAVA_AGENT:-} \
      -Dapollo.meta="$APOLLO_META" \
      -Denv="$APOLLO_ENV" \
      -jar "$BASE_PATH/$SERVER_NAME.jar" \
      --spring.profiles.active="$PROFILES_ACTIVE" \
      > "$LOG_PATH/nohup.out" 2>&1 &

    echo "[start] 启动 $BASE_PATH/$SERVER_NAME 完成，日志: $LOG_PATH/nohup.out"
}

# 健康检查：自动判断后端项目是否正常启动
function healthCheck() {
    if [ -n "$HEALTH_CHECK_URL" ]; then
        echo "[healthCheck] 开始通过 $HEALTH_CHECK_URL 地址，进行健康检查"
        result="000"
        for ((i = 0; i < 120; i++))
            do
                result=$(curl -I -m 10 -o /dev/null -s -w %{http_code} "$HEALTH_CHECK_URL" || echo "000")
                if [ "$result" == "200" ]; then
                    echo "[healthCheck] 健康检查通过"
                    break
                else
                    echo -e ".\c"
                    sleep 1
                fi
            done

        if [ ! "$result" == "200" ]; then
            echo "[healthCheck] 健康检查不通过，可能部署失败。查看日志，自行判断是否启动成功"
            tail -n 50 "$LOG_PATH/nohup.out" || true
            exit 1
        else
            tail -n 10 "$LOG_PATH/nohup.out" || true
        fi
    else
        echo "[healthCheck] HEALTH_CHECK_URL 未配置，开始 sleep 120 秒"
        sleep 120
        echo "[healthCheck] sleep 120 秒完成，查看日志，自行判断是否启动成功"
        tail -n 50 "$LOG_PATH/nohup.out" || true
    fi
}

# 部署
function deploy() {
    cd "$BASE_PATH"
    backup
    stop
    transfer
    start
    healthCheck
}

deploy
