#!/bin/bash

# RocketMQ 灰度路由测试脚本
# 测试Consumer发送消息和Provider消费消息的灰度路由功能

echo "=== RocketMQ 灰度路由测试 ==="
echo "测试时间: $(date)"
echo ""

# 基础URL
GATEWAY_URL="http://localhost:8080"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 发送测试请求
send_test_request() {
    local gray_version=$1
    local test_name=$2
    
    print_info "测试 $test_name..."
    
    if [ -z "$gray_version" ]; then
        response=$(curl -s "$GATEWAY_URL/consumer/api/send-message")
        print_info "请求: GET $GATEWAY_URL/consumer/api/send-message"
    else
        response=$(curl -s -H "gray: $gray_version" "$GATEWAY_URL/consumer/api/send-message")
        print_info "请求: GET $GATEWAY_URL/consumer/api/send-message -H \"gray: $gray_version\""
    fi
    
    echo "响应: $response"
    echo ""
    
    if echo "$response" | grep -q "messageStatus.*sent"; then
        print_success "$test_name 消息发送成功"
    else
        print_error "$test_name 消息发送失败"
    fi
    
    echo "----------------------------------------"
}

# 主测试流程
main() {
    echo "开始 RocketMQ 灰度路由测试..."
    echo ""
    
    # 测试消息发送和路由
    print_info "=== 测试消息发送和灰度路由 ==="
    
    # 测试normal版本
    send_test_request "" "Normal版本消息发送"
    sleep 2
    
    # 测试gray-feat1版本
    send_test_request "gray-feat1" "Gray-Feat1版本消息发送"
    sleep 2
    
    # 测试gray-feat2版本
    send_test_request "gray-feat2" "Gray-Feat2版本消息发送"
    sleep 2
    
    print_info "=== 批量测试消息发送 ==="
    
    print_info "发送5条normal版本消息..."
    for i in {1..5}; do
        curl -s "$GATEWAY_URL/consumer/api/send-message" > /dev/null
        echo -n "."
    done
    echo ""
    
    print_info "发送5条gray-feat1版本消息..."
    for i in {1..5}; do
        curl -s -H "gray: gray-feat1" "$GATEWAY_URL/consumer/api/send-message" > /dev/null
        echo -n "."
    done
    echo ""
    
    print_info "发送5条gray-feat2版本消息..."
    for i in {1..5}; do
        curl -s -H "gray: gray-feat2" "$GATEWAY_URL/consumer/api/send-message" > /dev/null
        echo -n "."
    done
    echo ""
    
    print_success "批量消息发送完成"
    
    print_info "等待10秒让所有消息处理完成..."
    sleep 10
    
    print_info "=== 测试结果验证 ==="
    echo "请检查以下日志来验证灰度路由是否正确:"
    echo ""
    echo "1. Provider Normal版本日志 (端口8082):"
    echo "   应该只看到处理 gray=null/normal 的消息"
    echo ""
    echo "2. Provider Gray-Feat1版本日志 (端口8085):"
    echo "   应该只看到处理 gray=gray-feat1 的消息"
    echo ""
    echo "3. Provider Gray-Feat2版本日志 (端口8086):"
    echo "   应该只看到处理 gray=gray-feat2 的消息"
    echo ""
    
    print_success "RocketMQ 灰度路由测试完成!"
}

# 执行主函数
main "$@"
