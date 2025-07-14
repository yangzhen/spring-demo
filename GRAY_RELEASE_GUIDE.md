# 灰度发布实践指导手册

## 📖 概述

本手册基于Spring Cloud灰度发布演示项目，为开发者和运维人员提供完整的灰度发布实践指导。通过本项目的学习和实践，您将掌握微服务架构下灰度发布的核心技术和最佳实践。

## 🎯 学习目标

完成本指导后，您将能够：

1. **理解灰度发布原理**: 掌握灰度发布的核心概念和实现机制
2. **实现HTTP请求路由**: 基于请求头实现服务版本路由
3. **实现消息队列路由**: 在RocketMQ中实现版本隔离和精确路由
4. **配置服务发现**: 使用Nacos实现多版本服务注册和发现
5. **监控和运维**: 掌握灰度发布的监控、回滚和故障处理

## 📚 前置知识

### 必备技能
- Java 8+ 开发经验
- Spring Boot/Spring Cloud 基础
- Maven 项目管理
- 微服务架构理解

### 推荐了解
- Nacos 服务注册与发现
- RocketMQ 消息队列
- Gateway 网关路由
- Docker 容器化部署

## 🏗️ 架构设计原理

### 1. 灰度发布架构图

```
┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   客户端     │───▶│   Gateway网关    │───▶│   Consumer服务   │
│  (携带gray)  │    │  (灰度路由过滤)   │    │  (版本标识)      │
└─────────────┘    └─────────────────┘    └─────────────────┘
                           │                        │
                           ▼                        ▼
                   ┌─────────────┐         ┌─────────────────┐
                   │   Nacos     │         │   Provider服务   │
                   │ (服务发现)   │         │  (多版本部署)    │
                   └─────────────┘         └─────────────────┘
                                                   │
                                                   ▼
                                          ┌─────────────────┐
                                          │   RocketMQ      │
                                          │ (消息灰度路由)   │
                                          └─────────────────┘
```

### 2. 核心组件职责

| 组件 | 职责 | 灰度实现方式 |
|------|------|-------------|
| Gateway | 入口路由 | 解析gray头部，路由到对应版本Consumer |
| Consumer | 业务处理 | 根据灰度标识调用对应版本Provider |
| Provider | 数据提供 | 多版本部署，提供不同业务逻辑 |
| Nacos | 服务发现 | 通过metadata区分服务版本 |
| RocketMQ | 消息队列 | 使用Tag机制实现消息版本隔离 |

## 🛠️ 实现步骤详解

### 步骤1: 环境准备

#### 1.1 安装基础设施
```bash
# 1. 安装并启动Nacos
wget https://github.com/alibaba/nacos/releases/download/2.2.3/nacos-server-2.2.3.tar.gz
tar -xzf nacos-server-2.2.3.tar.gz
cd nacos/bin
./startup.sh -m standalone

# 2. 安装并启动RocketMQ
wget https://archive.apache.org/dist/rocketmq/4.9.4/rocketmq-all-4.9.4-bin-release.zip
unzip rocketmq-all-4.9.4-bin-release.zip
cd rocketmq-all-4.9.4-bin-release/bin
./mqnamesrv
./mqbroker -n localhost:9876 autoCreateTopicEnable=true
```

#### 1.2 验证环境
```bash
# 验证Nacos
curl http://localhost:8848/nacos/v1/ns/operator/metrics

# 验证RocketMQ
./mqadmin updateTopic -n localhost:9876 -t gray-topic
```

### 步骤2: 服务版本配置

#### 2.1 Nacos元数据配置
```yaml
# application.yml
spring:
  cloud:
    nacos:
      discovery:
        metadata:
          gray-version: ${GRAY_VERSION:normal}  # 版本标识
          version: ${spring.application.version:1.0.0}
          zone: ${DEPLOY_ZONE:default}
```

#### 2.2 多版本部署配置
```bash
# Normal版本
export GRAY_VERSION=normal
export SERVER_PORT=8081

# Gray-feat1版本
export GRAY_VERSION=gray-feat1
export SERVER_PORT=8083

# Gray-feat2版本
export GRAY_VERSION=gray-feat2
export SERVER_PORT=8084
```

### 步骤3: Gateway灰度路由实现

#### 3.1 灰度路由过滤器
```java
@Component
public class GrayRoutingFilter implements GlobalFilter, Ordered {
    
    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        // 1. 提取灰度标识
        String grayVersion = extractGrayVersion(exchange.getRequest());
        
        // 2. 设置路由上下文
        if (StringUtils.hasText(grayVersion)) {
            exchange.getAttributes().put("gray-version", grayVersion);
        }
        
        return chain.filter(exchange);
    }
    
    private String extractGrayVersion(ServerHttpRequest request) {
        // 从请求头获取灰度标识
        return request.getHeaders().getFirst("gray");
    }
}
```

#### 3.2 负载均衡配置
```java
@Configuration
public class GrayLoadBalancerConfig {
    
    @Bean
    @Primary
    public ServiceInstanceListSupplier grayServiceInstanceListSupplier(
            ConfigurableApplicationContext context) {
        return ServiceInstanceListSupplier.builder()
                .withDiscoveryClient()
                .withHealthChecks()
                .with(new GrayServiceInstanceListSupplier())
                .build(context);
    }
}
```

### 步骤4: 服务间调用灰度传递

#### 4.1 Feign拦截器
```java
@Component
public class GrayFeignRequestInterceptor implements RequestInterceptor {
    
    @Override
    public void apply(RequestTemplate template) {
        String grayVersion = GrayContext.getGrayVersion();
        if (StringUtils.hasText(grayVersion)) {
            template.header("gray", grayVersion);
        }
    }
}
```

#### 4.2 灰度上下文管理
```java
public class GrayContext {
    private static final ThreadLocal<String> GRAY_VERSION = new ThreadLocal<>();
    
    public static void setGrayVersion(String version) {
        GRAY_VERSION.set(version);
    }
    
    public static String getGrayVersion() {
        return GRAY_VERSION.get();
    }
    
    public static void clear() {
        GRAY_VERSION.remove();
    }
}
```

### 步骤5: RocketMQ消息灰度路由

#### 5.1 消息生产者配置
```java
@Service
public class MessageProducer {
    
    @Autowired
    private RocketMQTemplate rocketMQTemplate;
    
    public void sendGrayMessage(String message, String grayVersion) {
        // 使用Tag机制发送消息
        String destination = "gray-topic:" + (grayVersion != null ? grayVersion : "normal");
        
        Message<String> msg = MessageBuilder
                .withPayload(message)
                .setHeader("gray", grayVersion)
                .build();
                
        rocketMQTemplate.syncSend(destination, msg);
    }
}
```

#### 5.2 消息消费者配置
```java
@Component
@RocketMQMessageListener(
    topic = "gray-topic",
    consumerGroup = "provider-consumer-${spring.cloud.nacos.discovery.metadata.gray-version:normal}",
    selectorExpression = "${spring.cloud.nacos.discovery.metadata.gray-version:normal}"
)
public class GrayMessageConsumer implements RocketMQListener<MessageExt> {
    
    @Value("${spring.cloud.nacos.discovery.metadata.gray-version:normal}")
    private String currentGrayVersion;
    
    @Override
    public void onMessage(MessageExt message) {
        String messageTag = message.getTags();
        String messageBody = new String(message.getBody());
        
        log.info("收到灰度消息: version={}, tag={}, message={}", 
                currentGrayVersion, messageTag, messageBody);
        
        // 处理业务逻辑
        processMessage(messageBody);
    }
}
```

## 🧪 测试验证指南

### 1. 功能测试

#### 1.1 HTTP路由测试
```bash
# 测试正常版本
curl -X GET http://localhost:8080/consumer/api/test
# 预期: 路由到normal版本

# 测试灰度版本
curl -X GET http://localhost:8080/consumer/api/test -H "gray: gray-feat1"
# 预期: 路由到gray-feat1版本
```

#### 1.2 消息路由测试
```bash
# 发送灰度消息
curl -X GET http://localhost:8080/consumer/api/send-message -H "gray: gray-feat1"

# 检查消费日志
tail -f logs/provider-gray-feat1.log | grep "收到灰度消息"
```

### 2. 压力测试

#### 2.1 并发路由测试
```bash
# 并发测试脚本
for i in {1..100}; do
  curl -X GET http://localhost:8080/consumer/api/test -H "gray: gray-feat1" &
done
wait

# 验证所有请求都路由到正确版本
```

#### 2.2 消息吞吐量测试
```bash
# 批量发送消息
for i in {1..1000}; do
  curl -X GET http://localhost:8080/consumer/api/send-message -H "gray: gray-feat1"
done

# 监控消费情况
./mqadmin queryMsgByKey -n localhost:9876 -t gray-topic -k gray-feat1
```

### 3. 故障测试

#### 3.1 服务降级测试
```bash
# 停止灰度版本服务
kill -9 $(ps aux | grep 'gray-feat1' | awk '{print $2}')

# 测试降级行为
curl -X GET http://localhost:8080/consumer/api/test -H "gray: gray-feat1"
# 预期: 降级到normal版本
```

#### 3.2 消息堆积测试
```bash
# 停止消费者
kill -9 $(ps aux | grep 'provider.*gray-feat1' | awk '{print $2}')

# 发送消息
for i in {1..100}; do
  curl -X GET http://localhost:8080/consumer/api/send-message -H "gray: gray-feat1"
done

# 重启消费者，验证消息恢复消费
```

## 📊 监控和运维

### 1. 关键指标监控

#### 1.1 服务健康监控
```bash
# 健康检查脚本
#!/bin/bash
services=("8080" "8081" "8082" "8083" "8084" "8085" "8086")
for port in "${services[@]}"; do
  status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/actuator/health)
  echo "Port $port: $status"
done
```

#### 1.2 流量分布监控
```bash
# 查看Nacos服务实例
curl -X GET "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=consumer"

# 分析流量分布
grep "gray:" logs/gateway.log | awk '{print $NF}' | sort | uniq -c
```

### 2. 日志分析

#### 2.1 关键日志模式
```bash
# 灰度路由日志
grep "灰度路由" logs/*.log

# 消息路由日志
grep "收到MQ消息" logs/provider-*.log

# 错误日志
grep "ERROR" logs/*.log
```

#### 2.2 性能分析
```bash
# 响应时间分析
grep "处理时间" logs/*.log | awk '{print $NF}' | sort -n

# 吞吐量分析
grep "$(date '+%Y-%m-%d %H:%M')" logs/*.log | wc -l
```

## 🚀 部署最佳实践

### 1. 渐进式发布策略

#### 1.1 流量分配策略
```
阶段1: 5%流量  -> gray-feat1 (观察1小时)
阶段2: 20%流量 -> gray-feat1 (观察2小时)
阶段3: 50%流量 -> gray-feat1 (观察4小时)
阶段4: 100%流量 -> gray-feat1 (全量发布)
```

#### 1.2 回滚策略
```bash
# 快速回滚脚本
#!/bin/bash
echo "开始回滚到normal版本..."

# 1. 停止灰度版本
./scripts/stop-gray-services.sh

# 2. 清理Nacos注册
curl -X DELETE "http://localhost:8848/nacos/v1/ns/instance?serviceName=consumer&ip=127.0.0.1&port=8083"

# 3. 验证回滚
curl -X GET http://localhost:8080/consumer/api/test -H "gray: gray-feat1"

echo "回滚完成"
```

### 2. 配置管理

#### 2.1 环境配置
```yaml
# dev环境
gray:
  enabled: true
  versions: ["gray-feat1", "gray-feat2"]
  default-version: "normal"

# prod环境
gray:
  enabled: true
  versions: ["gray-feat1"]
  default-version: "normal"
  traffic-ratio:
    gray-feat1: 10  # 10%流量
```

#### 2.2 动态配置
```java
@RefreshScope
@ConfigurationProperties(prefix = "gray")
public class GrayConfig {
    private boolean enabled = true;
    private List<String> versions = Arrays.asList("normal");
    private String defaultVersion = "normal";
    private Map<String, Integer> trafficRatio = new HashMap<>();
}
```

## 🔧 故障排查指南

### 1. 常见问题

#### 1.1 路由不生效
**症状**: 请求没有路由到预期版本
**排查步骤**:
```bash
# 1. 检查Gateway日志
grep "GrayRoutingFilter" logs/gateway.log

# 2. 检查Nacos注册
curl "http://localhost:8848/nacos/v1/ns/instance/list?serviceName=consumer"

# 3. 检查负载均衡配置
grep "gray-version" logs/consumer-*.log
```

#### 1.2 消息路由错误
**症状**: 消息被错误版本消费
**排查步骤**:
```bash
# 1. 检查Topic和Tag
./mqadmin topicList -n localhost:9876

# 2. 检查消费者组
./mqadmin consumerProgress -n localhost:9876 -g provider-consumer-gray-feat1

# 3. 检查消息属性
grep "messageGray" logs/provider-*.log
```

### 2. 性能问题

#### 2.1 响应时间过长
**排查步骤**:
```bash
# 1. 检查服务健康状态
curl http://localhost:8080/actuator/health

# 2. 分析响应时间分布
grep "耗时" logs/*.log | awk '{print $NF}' | sort -n | tail -10

# 3. 检查资源使用
top -p $(pgrep -f "spring-boot")
```

#### 2.2 消息堆积
**排查步骤**:
```bash
# 1. 检查消费者状态
./mqadmin consumerProgress -n localhost:9876

# 2. 检查消费速率
grep "处理完成" logs/provider-*.log | wc -l

# 3. 调整消费者配置
# 增加消费者线程数或实例数
```

## 📈 扩展功能

### 1. 高级路由策略

#### 1.1 基于用户的灰度
```java
public class UserBasedGrayRouter {
    public String determineGrayVersion(String userId) {
        // 基于用户ID哈希
        int hash = userId.hashCode() % 100;
        if (hash < 5) {
            return "gray-feat1";  // 5%用户
        }
        return "normal";
    }
}
```

#### 1.2 基于地域的灰度
```java
public class RegionBasedGrayRouter {
    public String determineGrayVersion(String region) {
        // 特定地域使用灰度版本
        if ("beijing".equals(region) || "shanghai".equals(region)) {
            return "gray-feat1";
        }
        return "normal";
    }
}
```

### 2. 监控增强

#### 2.1 Prometheus指标
```java
@Component
public class GrayMetrics {
    private final Counter grayRequestCounter = Counter.build()
            .name("gray_requests_total")
            .labelNames("version", "service")
            .help("Total gray requests")
            .register();
    
    public void recordGrayRequest(String version, String service) {
        grayRequestCounter.labels(version, service).inc();
    }
}
```

#### 2.2 链路追踪
```java
@Component
public class GrayTracing {
    public void addGraySpanTag(String grayVersion) {
        Span span = Tracing.currentTracer().nextSpan();
        span.tag("gray.version", grayVersion);
        span.start();
    }
}
```

## 📝 总结

通过本指导手册的学习和实践，您已经掌握了：

1. **灰度发布的核心原理**和实现机制
2. **HTTP请求路由**的配置和实现
3. **RocketMQ消息路由**的Tag机制应用
4. **服务发现和负载均衡**的灰度配置
5. **监控、运维和故障排查**的最佳实践

### 关键收获

- ✅ 理解了微服务灰度发布的完整技术栈
- ✅ 掌握了Spring Cloud Gateway的灰度路由实现
- ✅ 学会了RocketMQ的消息版本隔离技术
- ✅ 具备了灰度发布的监控和运维能力
- ✅ 了解了生产环境的部署和回滚策略

### 下一步建议

1. **深入学习**: 研究更复杂的灰度策略和路由算法
2. **实践应用**: 在实际项目中应用灰度发布技术
3. **技术扩展**: 集成更多监控和链路追踪工具
4. **性能优化**: 优化灰度路由的性能和稳定性
5. **团队分享**: 将学到的知识分享给团队成员

希望本指导手册能够帮助您在微服务灰度发布的道路上更进一步！
