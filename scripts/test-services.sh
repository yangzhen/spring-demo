#!/bin/bash

# 服务测试脚本

echo "=== Spring Cloud 灰度发布服务测试 ==="

# 等待服务启动
echo "等待服务启动..."
sleep 5

# 测试函数
test_endpoint() {
    local url=$1
    local description=$2
    local gray_header=$3
    
    echo ""
    echo "测试: $description"
    echo "URL: $url"
    
    if [ -n "$gray_header" ]; then
        echo "灰度标识: $gray_header"
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -H "gray: $gray_header" "$url" 2>/dev/null)
    else
        response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$url" 2>/dev/null)
    fi
    
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    body=$(echo "$response" | sed '/HTTP_CODE:/d')
    
    if [ "$http_code" = "200" ]; then
        echo "✅ 成功 (HTTP $http_code)"
        echo "响应: $body"
    else
        echo "❌ 失败 (HTTP $http_code)"
        echo "响应: $body"
    fi
}

# 检查服务是否启动
check_service() {
    local url=$1
    local service_name=$2
    
    echo "检查 $service_name 服务状态..."
    if curl -s "$url" > /dev/null 2>&1; then
        echo "✅ $service_name 服务已启动"
        return 0
    else
        echo "❌ $service_name 服务未启动"
        return 1
    fi
}

# 检查各个服务状态
echo "=== 检查服务状态 ==="
check_service "http://localhost:8080/actuator/health" "Gateway"
check_service "http://localhost:8081/actuator/health" "Consumer(normal)"
check_service "http://localhost:8082/actuator/health" "Provider(normal)"

# 直接测试Consumer服务
echo ""
echo "=== 直接测试Consumer服务 ==="
test_endpoint "http://localhost:8081/api/health" "Consumer健康检查"
test_endpoint "http://localhost:8081/api/test" "Consumer测试接口(normal)"

# 直接测试Provider服务
echo ""
echo "=== 直接测试Provider服务 ==="
test_endpoint "http://localhost:8082/api/health" "Provider健康检查"
test_endpoint "http://localhost:8082/api/data" "Provider数据接口(normal)"

# 通过Gateway测试
echo ""
echo "=== 通过Gateway测试 ==="
test_endpoint "http://localhost:8080/consumer/api/test" "Gateway->Consumer(normal)"
test_endpoint "http://localhost:8080/consumer/api/test" "Gateway->Consumer(gray-feat1)" "gray-feat1"
test_endpoint "http://localhost:8080/consumer/api/test" "Gateway->Consumer(gray-feat2)" "gray-feat2"

echo ""
echo "=== 测试完成 ==="
