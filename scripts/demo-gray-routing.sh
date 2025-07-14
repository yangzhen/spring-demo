#!/bin/bash

# 灰度发布演示脚本
# 用于指导演示Spring Cloud灰度发布功能

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 基础URL
GATEWAY_URL="http://localhost:8080"

print_title() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}[步骤 $1]${NC} $2"
    echo ""
}

print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[注意]${NC} $1"
}

print_command() {
    echo -e "${YELLOW}执行命令:${NC} $1"
}

wait_for_user() {
    echo ""
    echo -e "${CYAN}按回车键继续...${NC}"
    read -r
    echo ""
}

# 检查服务状态
check_services() {
    print_step "1" "检查服务状态"
    
    services=("8080:Gateway" "8081:Consumer-Normal" "8082:Provider-Normal" 
              "8083:Consumer-Gray1" "8084:Consumer-Gray2" 
              "8085:Provider-Gray1" "8086:Provider-Gray2")
    
    all_healthy=true
    
    for service in "${services[@]}"; do
        port=$(echo $service | cut -d: -f1)
        name=$(echo $service | cut -d: -f2)
        
        status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/actuator/health 2>/dev/null)
        
        if [ "$status" = "200" ]; then
            print_success "$name (端口$port) - 健康"
        else
            print_error "$name (端口$port) - 不可用"
            all_healthy=false
        fi
    done
    
    if [ "$all_healthy" = false ]; then
        print_error "部分服务不可用，请先启动所有服务："
        print_command "./scripts/start-all.sh"
        exit 1
    fi
    
    print_success "所有服务运行正常！"
    wait_for_user
}

# 演示HTTP请求灰度路由
demo_http_routing() {
    print_step "2" "演示HTTP请求灰度路由"
    
    print_info "我们将演示如何通过HTTP请求头实现服务版本路由"
    print_info "观察响应中的version和port字段，确认路由到正确的服务版本"
    echo ""
    
    # 测试normal版本
    print_info "2.1 测试正常版本（不带灰度标识）"
    print_command "curl -X GET $GATEWAY_URL/consumer/api/test"
    echo ""
    
    response=$(curl -s "$GATEWAY_URL/consumer/api/test")
    echo "响应结果:"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    echo ""
    
    if echo "$response" | grep -q '"version":"normal"'; then
        print_success "✓ 正确路由到normal版本"
    else
        print_warning "! 路由结果需要确认"
    fi
    
    wait_for_user
    
    # 测试gray-feat1版本
    print_info "2.2 测试灰度版本1（gray-feat1）"
    print_command "curl -X GET $GATEWAY_URL/consumer/api/test -H \"gray: gray-feat1\""
    echo ""
    
    response=$(curl -s -H "gray: gray-feat1" "$GATEWAY_URL/consumer/api/test")
    echo "响应结果:"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    echo ""
    
    if echo "$response" | grep -q '"version":"gray-feat1"'; then
        print_success "✓ 正确路由到gray-feat1版本"
    else
        print_warning "! 路由结果需要确认"
    fi
    
    wait_for_user
    
    # 测试gray-feat2版本
    print_info "2.3 测试灰度版本2（gray-feat2）"
    print_command "curl -X GET $GATEWAY_URL/consumer/api/test -H \"gray: gray-feat2\""
    echo ""
    
    response=$(curl -s -H "gray: gray-feat2" "$GATEWAY_URL/consumer/api/test")
    echo "响应结果:"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    echo ""
    
    if echo "$response" | grep -q '"version":"gray-feat2"'; then
        print_success "✓ 正确路由到gray-feat2版本"
    else
        print_warning "! 路由结果需要确认"
    fi
    
    wait_for_user
}

# 演示RocketMQ消息灰度路由
demo_mq_routing() {
    print_step "3" "演示RocketMQ消息灰度路由"
    
    print_info "我们将演示消息队列中的版本隔离和精确路由"
    print_info "每个版本的Provider只会消费对应版本的消息"
    echo ""
    
    # 发送normal版本消息
    print_info "3.1 发送正常版本消息"
    print_command "curl -X GET $GATEWAY_URL/consumer/api/send-message"
    echo ""
    
    response=$(curl -s "$GATEWAY_URL/consumer/api/send-message")
    echo "响应结果:"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    echo ""
    
    if echo "$response" | grep -q '"messageStatus":"sent"'; then
        print_success "✓ 消息发送成功"
        print_info "请查看Provider Normal版本日志，确认只有normal版本消费了此消息"
    else
        print_error "✗ 消息发送失败"
    fi
    
    wait_for_user
    
    # 发送gray-feat1版本消息
    print_info "3.2 发送灰度版本1消息"
    print_command "curl -X GET $GATEWAY_URL/consumer/api/send-message -H \"gray: gray-feat1\""
    echo ""
    
    response=$(curl -s -H "gray: gray-feat1" "$GATEWAY_URL/consumer/api/send-message")
    echo "响应结果:"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    echo ""
    
    if echo "$response" | grep -q '"messageStatus":"sent"'; then
        print_success "✓ 消息发送成功"
        print_info "请查看Provider Gray-Feat1版本日志，确认只有gray-feat1版本消费了此消息"
    else
        print_error "✗ 消息发送失败"
    fi
    
    wait_for_user
    
    # 发送gray-feat2版本消息
    print_info "3.3 发送灰度版本2消息"
    print_command "curl -X GET $GATEWAY_URL/consumer/api/send-message -H \"gray: gray-feat2\""
    echo ""
    
    response=$(curl -s -H "gray: gray-feat2" "$GATEWAY_URL/consumer/api/send-message")
    echo "响应结果:"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    echo ""
    
    if echo "$response" | grep -q '"messageStatus":"sent"'; then
        print_success "✓ 消息发送成功"
        print_info "请查看Provider Gray-Feat2版本日志，确认只有gray-feat2版本消费了此消息"
    else
        print_error "✗ 消息发送失败"
    fi
    
    wait_for_user
}

# 演示日志验证
demo_log_verification() {
    print_step "4" "验证消息路由日志"
    
    print_info "现在我们来验证消息是否正确路由到对应版本的Provider"
    echo ""
    
    # 检查Provider Normal版本日志
    print_info "4.1 检查Provider Normal版本消息消费日志"
    print_command "tail -10 logs/provider-normal.log | grep \"收到MQ消息\""
    echo ""
    
    if [ -f "logs/provider-normal.log" ]; then
        echo "Provider Normal版本最近的消息消费记录:"
        tail -10 logs/provider-normal.log | grep "收到MQ消息" | tail -3 || echo "暂无消息消费记录"
        echo ""
        print_info "应该只看到tag=normal的消息"
    else
        print_warning "日志文件不存在: logs/provider-normal.log"
    fi
    
    wait_for_user
    
    # 检查Provider Gray-Feat1版本日志
    print_info "4.2 检查Provider Gray-Feat1版本消息消费日志"
    print_command "tail -10 logs/provider-gray-feat1.log | grep \"收到MQ消息\""
    echo ""
    
    if [ -f "logs/provider-gray-feat1.log" ]; then
        echo "Provider Gray-Feat1版本最近的消息消费记录:"
        tail -10 logs/provider-gray-feat1.log | grep "收到MQ消息" | tail -3 || echo "暂无消息消费记录"
        echo ""
        print_info "应该只看到tag=gray-feat1的消息"
    else
        print_warning "日志文件不存在: logs/provider-gray-feat1.log"
    fi
    
    wait_for_user
    
    # 检查Provider Gray-Feat2版本日志
    print_info "4.3 检查Provider Gray-Feat2版本消息消费日志"
    print_command "tail -10 logs/provider-gray-feat2.log | grep \"收到MQ消息\""
    echo ""
    
    if [ -f "logs/provider-gray-feat2.log" ]; then
        echo "Provider Gray-Feat2版本最近的消息消费记录:"
        tail -10 logs/provider-gray-feat2.log | grep "收到MQ消息" | tail -3 || echo "暂无消息消费记录"
        echo ""
        print_info "应该只看到tag=gray-feat2的消息"
    else
        print_warning "日志文件不存在: logs/provider-gray-feat2.log"
    fi
    
    wait_for_user
}

# 演示故障转移
demo_failover() {
    print_step "5" "演示故障转移和降级"
    
    print_info "我们将演示当灰度版本不可用时的降级机制"
    print_warning "注意：此演示会临时停止gray-feat1版本的Consumer服务"
    echo ""
    
    print_info "5.1 当前gray-feat1版本正常工作"
    print_command "curl -X GET $GATEWAY_URL/consumer/api/test -H \"gray: gray-feat1\""
    echo ""
    
    response=$(curl -s -H "gray: gray-feat1" "$GATEWAY_URL/consumer/api/test")
    echo "响应结果:"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    echo ""
    
    if echo "$response" | grep -q '"version":"gray-feat1"'; then
        print_success "✓ gray-feat1版本正常工作"
    else
        print_warning "! gray-feat1版本可能已经不可用"
    fi
    
    wait_for_user
    
    print_info "5.2 模拟gray-feat1版本故障"
    print_warning "请手动停止gray-feat1版本的Consumer服务（端口8083）"
    print_info "您可以在另一个终端执行以下命令："
    print_command "kill \$(ps aux | grep 'consumer.*8083' | grep -v grep | awk '{print \$2}')"
    echo ""
    print_info "停止服务后，按回车键继续测试降级行为..."
    read -r
    
    print_info "5.3 测试降级行为"
    print_command "curl -X GET $GATEWAY_URL/consumer/api/test -H \"gray: gray-feat1\""
    echo ""
    
    response=$(curl -s -H "gray: gray-feat1" "$GATEWAY_URL/consumer/api/test")
    echo "响应结果:"
    echo "$response" | jq . 2>/dev/null || echo "$response"
    echo ""
    
    if echo "$response" | grep -q '"version":"normal"'; then
        print_success "✓ 成功降级到normal版本"
    elif echo "$response" | grep -q '"version":"gray-feat1"'; then
        print_warning "! 仍然路由到gray-feat1版本，可能服务未完全停止"
    else
        print_error "✗ 降级失败或服务不可用"
    fi
    
    wait_for_user
}

# 演示批量测试
demo_batch_test() {
    print_step "6" "批量测试和性能验证"
    
    print_info "我们将进行批量测试，验证灰度路由的稳定性"
    echo ""
    
    print_info "6.1 批量HTTP请求测试"
    print_command "for i in {1..10}; do curl -s -H \"gray: gray-feat2\" $GATEWAY_URL/consumer/api/test; done"
    echo ""
    
    print_info "发送10个gray-feat2版本的请求..."
    success_count=0
    for i in {1..10}; do
        response=$(curl -s -H "gray: gray-feat2" "$GATEWAY_URL/consumer/api/test")
        if echo "$response" | grep -q '"version":"gray-feat2"'; then
            ((success_count++))
        fi
        echo -n "."
    done
    echo ""
    echo ""
    
    print_success "成功路由: $success_count/10 个请求"
    
    wait_for_user
    
    print_info "6.2 批量消息发送测试"
    print_command "for i in {1..5}; do curl -s -H \"gray: gray-feat2\" $GATEWAY_URL/consumer/api/send-message; done"
    echo ""
    
    print_info "发送5条gray-feat2版本的消息..."
    message_success_count=0
    for i in {1..5}; do
        response=$(curl -s -H "gray: gray-feat2" "$GATEWAY_URL/consumer/api/send-message")
        if echo "$response" | grep -q '"messageStatus":"sent"'; then
            ((message_success_count++))
        fi
        echo -n "."
        sleep 1
    done
    echo ""
    echo ""
    
    print_success "成功发送: $message_success_count/5 条消息"
    
    print_info "等待3秒让消息处理完成..."
    sleep 3
    
    print_info "检查消息消费情况:"
    if [ -f "logs/provider-gray-feat2.log" ]; then
        consumed_count=$(grep "收到MQ消息.*tag=gray-feat2" logs/provider-gray-feat2.log | tail -5 | wc -l)
        print_success "Provider Gray-Feat2版本消费了 $consumed_count 条消息"
    else
        print_warning "无法检查消息消费情况，日志文件不存在"
    fi
    
    wait_for_user
}

# 总结演示
demo_summary() {
    print_title "演示总结"
    
    print_info "🎉 恭喜！您已经完成了Spring Cloud灰度发布的完整演示"
    echo ""
    
    print_success "✅ 演示内容回顾:"
    echo "   1. 服务健康检查 - 验证所有服务正常运行"
    echo "   2. HTTP请求灰度路由 - 根据请求头路由到不同版本"
    echo "   3. RocketMQ消息灰度路由 - 消息按版本精确投递和消费"
    echo "   4. 日志验证 - 确认消息路由的正确性"
    echo "   5. 故障转移演示 - 灰度版本不可用时的降级机制"
    echo "   6. 批量测试 - 验证灰度路由的稳定性和性能"
    echo ""
    
    print_info "🔍 关键技术点:"
    echo "   • Gateway灰度路由过滤器"
    echo "   • Nacos服务发现和元数据"
    echo "   • Feign客户端灰度传递"
    echo "   • RocketMQ Tag机制消息路由"
    echo "   • 负载均衡和故障转移"
    echo ""
    
    print_info "📚 进一步学习:"
    echo "   • 查看 README.md 了解项目详情"
    echo "   • 查看 GRAY_RELEASE_GUIDE.md 学习实践指导"
    echo "   • 查看 ROCKETMQ_GRAY_ROUTING.md 了解消息路由实现"
    echo "   • 查看 GRAY_ROUTING_IMPLEMENTATION.md 了解技术实现"
    echo ""
    
    print_info "🛠️ 实用命令:"
    echo "   • 启动所有服务: ./scripts/start-all.sh"
    echo "   • 停止所有服务: ./scripts/stop-all.sh"
    echo "   • 测试服务功能: ./scripts/test-services.sh"
    echo "   • 测试MQ路由: ./scripts/test-mq-gray-routing.sh"
    echo ""
    
    print_success "感谢您的参与！希望这个演示对您理解微服务灰度发布有所帮助。"
}

# 主函数
main() {
    print_title "Spring Cloud 灰度发布演示"
    
    print_info "欢迎参加Spring Cloud灰度发布功能演示！"
    print_info "本演示将指导您了解微服务架构下的灰度发布实现"
    echo ""
    print_warning "请确保已经启动了所有必要的服务（Nacos、RocketMQ、微服务）"
    print_info "如果还未启动，请先执行: ./scripts/start-all.sh"
    echo ""
    
    wait_for_user
    
    # 执行演示步骤
    check_services
    demo_http_routing
    demo_mq_routing
    demo_log_verification
    demo_failover
    demo_batch_test
    demo_summary
}

# 执行主函数
main "$@"
