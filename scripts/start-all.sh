#!/bin/bash

# Spring Cloud 灰度发布演示项目启动脚本

echo "=== Spring Cloud 灰度发布演示项目启动脚本 ==="

# 检查Java环境
if ! command -v java &> /dev/null; then
    echo "错误: 未找到Java环境，请先安装Java 8"
    exit 1
fi

# 检查Maven环境
if ! command -v mvn &> /dev/null; then
    echo "错误: 未找到Maven环境，请先安装Maven"
    exit 1
fi

# 项目根目录
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
echo "项目根目录: $PROJECT_ROOT"

# 编译项目
echo "=== 编译项目 ==="
cd "$PROJECT_ROOT"
mvn clean compile -q
if [ $? -ne 0 ]; then
    echo "错误: 项目编译失败"
    exit 1
fi
echo "项目编译成功"

# 创建日志目录
mkdir -p "$PROJECT_ROOT/logs"

# 启动函数
start_service() {
    local service_name=$1
    local service_dir=$2
    local gray_version=${3:-"normal"}
    local server_port=${4:-""}
    local log_file="$PROJECT_ROOT/logs/${service_name}-${gray_version}.log"
    
    echo "启动 $service_name ($gray_version)..."
    
    cd "$PROJECT_ROOT/$service_dir"
    
    if [ -n "$server_port" ]; then
        GRAY_VERSION=$gray_version SERVER_PORT=$server_port nohup mvn spring-boot:run > "$log_file" 2>&1 &
    else
        GRAY_VERSION=$gray_version nohup mvn spring-boot:run > "$log_file" 2>&1 &
    fi
    
    local pid=$!
    echo "$service_name ($gray_version) 启动中，PID: $pid，日志文件: $log_file"
    sleep 3
}

# 启动服务
echo "=== 启动服务 ==="

# 启动 Provider 服务
start_service "provider" "provider" "normal" "8082"
start_service "provider" "provider" "gray-feat1" "8085"
start_service "provider" "provider" "gray-feat2" "8086"

# 等待 Provider 启动
echo "等待 Provider 服务启动..."
sleep 10

# 启动 Consumer 服务
start_service "consumer" "consumer" "normal" "8081"
start_service "consumer" "consumer" "gray-feat1" "8083"
start_service "consumer" "consumer" "gray-feat2" "8084"

# 等待 Consumer 启动
echo "等待 Consumer 服务启动..."
sleep 10

# 启动 Gateway 服务
start_service "gateway" "gateway" "normal" "8080"

# 等待 Gateway 启动
echo "等待 Gateway 服务启动..."
sleep 10

echo "=== 服务启动完成 ==="
echo ""
echo "服务访问地址:"
echo "- Gateway:   http://localhost:8080"
echo "- Consumer:  http://localhost:8081 (normal)"
echo "- Consumer:  http://localhost:8083 (gray-feat1)"
echo "- Consumer:  http://localhost:8084 (gray-feat2)"
echo "- Provider:  http://localhost:8082 (normal)"
echo "- Provider:  http://localhost:8085 (gray-feat1)"
echo "- Provider:  http://localhost:8086 (gray-feat2)"
echo ""
echo "测试命令:"
echo "# 正常版本测试"
echo "curl -X GET http://localhost:8080/consumer/api/test"
echo ""
echo "# 灰度版本测试"
echo "curl -X GET http://localhost:8080/consumer/api/test -H \"gray: gray-feat1\""
echo "curl -X GET http://localhost:8080/consumer/api/test -H \"gray: gray-feat2\""
echo ""
echo "日志文件位置: $PROJECT_ROOT/logs/"
echo ""
echo "停止所有服务请运行: ./scripts/stop-all.sh"
