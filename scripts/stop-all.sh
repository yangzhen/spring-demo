#!/bin/bash

# Spring Cloud 灰度发布演示项目停止脚本

echo "=== Spring Cloud 灰度发布演示项目停止脚本 ==="

# 查找并停止Spring Boot应用
echo "正在查找运行中的Spring Boot应用..."

# 查找包含spring-boot:run的Java进程
PIDS=$(ps aux | grep 'spring-boot:run' | grep -v grep | awk '{print $2}')

if [ -z "$PIDS" ]; then
    echo "未找到运行中的Spring Boot应用"
else
    echo "找到以下Spring Boot应用进程:"
    ps aux | grep 'spring-boot:run' | grep -v grep | awk '{print "PID: " $2 " - " $11 " " $12 " " $13}'
    
    echo ""
    echo "正在停止应用..."
    
    for PID in $PIDS; do
        echo "停止进程 PID: $PID"
        kill -15 $PID
        
        # 等待进程优雅关闭
        sleep 2
        
        # 检查进程是否还在运行
        if kill -0 $PID 2>/dev/null; then
            echo "进程 $PID 未能优雅关闭，强制终止"
            kill -9 $PID
        else
            echo "进程 $PID 已成功停止"
        fi
    done
fi

# 额外检查可能的Java进程
echo ""
echo "检查其他相关Java进程..."
OTHER_PIDS=$(ps aux | grep java | grep -E '(gateway|consumer|provider)' | grep -v grep | awk '{print $2}')

if [ -n "$OTHER_PIDS" ]; then
    echo "找到其他相关Java进程:"
    ps aux | grep java | grep -E '(gateway|consumer|provider)' | grep -v grep | awk '{print "PID: " $2 " - " $11 " " $12}'
    
    for PID in $OTHER_PIDS; do
        echo "停止进程 PID: $PID"
        kill -15 $PID
        sleep 1
        if kill -0 $PID 2>/dev/null; then
            kill -9 $PID
        fi
    done
fi

echo ""
echo "=== 所有服务已停止 ==="

# 清理日志文件（可选）
read -p "是否清理日志文件? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
    if [ -d "$PROJECT_ROOT/logs" ]; then
        rm -rf "$PROJECT_ROOT/logs"
        echo "日志文件已清理"
    fi
fi

echo "停止脚本执行完成"
