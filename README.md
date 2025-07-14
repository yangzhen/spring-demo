# Spring Cloud 灰度发布演示项目

## 项目概述

本项目是一个完整的**微服务灰度发布演示系统**，专门用于指导和演示如何在Spring Cloud微服务架构中实现灰度发布功能。

### 🎯 演示目标
- **HTTP请求灰度路由**: 演示如何根据请求头实现服务版本路由
- **RocketMQ消息灰度路由**: 演示如何在消息队列中实现版本隔离
- **多版本并行部署**: 演示如何同时运行多个服务版本
- **灰度发布最佳实践**: 提供完整的灰度发布解决方案

### 🏗️ 系统架构
本项目包含 Gateway、Consumer、Provider 三个核心模块，每个模块都支持多版本并行部署。

## 技术栈

- Java 8
- Spring Boot 2.7.18
- Spring Cloud 2021.0.8
- Spring Cloud Alibaba 2021.0.5.0
- Nacos (服务注册与配置中心)
- RocketMQ (消息队列，支持灰度路由)

## 系统架构

```
┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   Client/前端    │───▶│   Gateway网关     │───▶│   Consumer服务    │
└─────────────────┘    └──────────────────┘    └──────────────────┘                              │                          │
                              ▼                          ▼
                       ┌──────────────┐         ┌──────────────────┐
                       │   Nacos注册   │         │   Provider服务    │
                       │   配置中心    │         └──────────────────┘
                       └──────────────┘                  │
                                                         ▼
                                                ┌──────────────┐
                                                │   Nacos注册   │
                                                │   配置中心    │
                                                └──────────────┘
```

## 模块说明

### Gateway (网关模块)
- **端口**: 8080
- **职责**: API网关，统一入口，灰度路由
- **功能**: 根据请求头 `gray` 动态路由到对应版本的Consumer服务

### Consumer (消费者模块)
- **端口**: 8081 (normal), 8083 (gray-feat1), 8084 (gray-feat2)
- **职责**: 业务处理，调用Provider服务
- **功能**: 处理业务逻辑，根据灰度标识调用对应版本的Provider

### Provider (提供者模块)
- **端口**: 8082 (normal), 8085 (gray-feat1), 8086 (gray-feat2)
- **职责**: 数据提供，核心业务实现
- **功能**: 根据版本提供不同的业务功能

## 灰度版本

- **normal**: 正常版本，基础功能
- **gray-feat1**: 灰度功能1，新增用户画像分析
- **gray-feat2**: 灰度功能2，优化搜索算法

## 🚀 快速启动指南

### 前置条件
- Java 8+
- Maven 3.6+
- Nacos 2.x
- RocketMQ 4.x

### 方式一：一键启动（推荐）

```bash
# 1. 启动所有服务
./scripts/start-all.sh

# 2. 运行测试验证
./scripts/test-services.sh

# 3. 测试RocketMQ灰度路由
./scripts/test-mq-gray-routing.sh

# 4. 停止所有服务
./scripts/stop-all.sh
```

### 方式二：手动启动

#### 1. 启动基础设施

**启动 Nacos**
```bash
# 下载并启动 Nacos (单机模式)
cd nacos/bin
./startup.sh -m standalone
```
📍 Nacos 控制台: http://localhost:8848/nacos (用户名/密码: nacos/nacos)

**启动 RocketMQ**
```bash
# 启动 NameServer
cd rocketmq/bin
./mqnamesrv

# 启动 Broker
./mqbroker -n localhost:9876 autoCreateTopicEnable=true
```
📍 RocketMQ 控制台: http://localhost:8080 (如果安装了控制台)

#### 2. 编译项目
```bash
mvn clean compile
```

#### 3. 启动微服务

**启动 Provider (多版本)**
```bash
# Normal 版本 (端口8082)
cd provider && mvn spring-boot:run

# Gray-feat1 版本 (端口8085)
cd provider && GRAY_VERSION=gray-feat1 SERVER_PORT=8085 mvn spring-boot:run

# Gray-feat2 版本 (端口8086)
cd provider && GRAY_VERSION=gray-feat2 SERVER_PORT=8086 mvn spring-boot:run
```

**启动 Consumer (多版本)**
```bash
# Normal 版本 (端口8081)
cd consumer && mvn spring-boot:run

# Gray-feat1 版本 (端口8083)
cd consumer && GRAY_VERSION=gray-feat1 SERVER_PORT=8083 mvn spring-boot:run

# Gray-feat2 版本 (端口8084)
cd consumer && GRAY_VERSION=gray-feat2 SERVER_PORT=8084 mvn spring-boot:run
```

**启动 Gateway**
```bash
# Gateway (端口8080)
cd gateway && mvn spring-boot:run
```

### 启动验证
```bash
# 检查所有服务健康状态
curl http://localhost:8080/actuator/health
curl http://localhost:8081/actuator/health
curl http://localhost:8082/actuator/health
```

## 📋 演示步骤指南

### 步骤1：HTTP请求灰度路由演示

**目标**: 演示如何通过HTTP请求头实现服务版本路由

```bash
# 1. 测试正常版本 (不带灰度标识)
curl -X GET http://localhost:8080/consumer/api/test
# 预期结果: 路由到normal版本的Consumer和Provider

# 2. 测试灰度版本1 (带gray-feat1标识)
curl -X GET http://localhost:8080/consumer/api/test -H "gray: gray-feat1"
# 预期结果: 路由到gray-feat1版本的Consumer和Provider

# 3. 测试灰度版本2 (带gray-feat2标识)
curl -X GET http://localhost:8080/consumer/api/test -H "gray: gray-feat2"
# 预期结果: 路由到gray-feat2版本的Consumer和Provider
```

**观察要点**:
- 响应中的`version`字段显示实际处理请求的服务版本
- 响应中的`port`字段显示处理请求的服务端口
- 不同版本返回不同的业务数据

### 步骤2：RocketMQ消息灰度路由演示

**目标**: 演示消息队列中的版本隔离和精确路由

```bash
# 1. 发送正常版本消息
curl -X GET http://localhost:8080/consumer/api/send-message
# 预期结果: 只有normal版本的Provider消费此消息

# 2. 发送灰度版本1消息
curl -X GET http://localhost:8080/consumer/api/send-message -H "gray: gray-feat1"
# 预期结果: 只有gray-feat1版本的Provider消费此消息

# 3. 发送灰度版本2消息
curl -X GET http://localhost:8080/consumer/api/send-message -H "gray: gray-feat2"
# 预期结果: 只有gray-feat2版本的Provider消费此消息

# 4. 批量测试消息路由
./scripts/test-mq-gray-routing.sh
# 预期结果: 自动化验证所有版本的消息路由正确性
```

**观察要点**:
- 查看Provider服务日志，确认消息只被对应版本消费
- 验证消息的Tag字段与消费者版本匹配
- 确认没有跨版本的消息投递

### 步骤3：服务发现和负载均衡验证

**目标**: 验证Nacos服务发现和灰度负载均衡

```bash
# 1. 查看服务注册情况
curl -X GET http://localhost:8080/actuator/health
# 观察discoveryClient中注册的服务实例

# 2. 多次调用同一接口，观察负载均衡
for i in {1..5}; do
  curl -X GET http://localhost:8080/consumer/api/test -H "gray: gray-feat1"
  echo "---"
done
# 预期结果: 请求始终路由到gray-feat1版本
```

### 步骤4：故障转移和降级演示

**目标**: 演示灰度版本不可用时的降级机制

```bash
# 1. 停止gray-feat1版本的Consumer服务
# 找到gray-feat1的Consumer进程并停止

# 2. 测试降级行为
curl -X GET http://localhost:8080/consumer/api/test -H "gray: gray-feat1"
# 预期结果: 自动降级到normal版本处理请求

# 3. 重新启动gray-feat1版本
cd consumer && GRAY_VERSION=gray-feat1 SERVER_PORT=8083 mvn spring-boot:run

# 4. 验证服务恢复
curl -X GET http://localhost:8080/consumer/api/test -H "gray: gray-feat1"
# 预期结果: 重新路由到gray-feat1版本
```

## 🔍 学习要点

### 1. 灰度路由实现原理

**Gateway层路由**:
- 通过`GrayRoutingFilter`解析请求头中的灰度标识
- 使用`GrayServiceInstanceListSupplier`过滤服务实例
- 实现基于metadata的服务发现和负载均衡

**服务间调用**:
- 通过`GrayFeignRequestInterceptor`传递灰度上下文
- 使用`GrayContext`维护请求级别的灰度状态
- 确保整个调用链的灰度一致性

**消息队列路由**:
- 使用RocketMQ Tag机制实现消息级别的版本隔离
- 通过消费者组和选择器表达式精确控制消息消费
- 避免跨版本的消息投递和处理

### 2. 关键配置说明

**Nacos元数据配置**:
```yaml
spring:
  cloud:
    nacos:
      discovery:
        metadata:
          gray-version: ${GRAY_VERSION:normal}
```

**RocketMQ消费者配置**:
```java
@RocketMQMessageListener(
    topic = "gray-topic",
    consumerGroup = "provider-consumer-${spring.cloud.nacos.discovery.metadata.gray-version:normal}",
    selectorExpression = "${spring.cloud.nacos.discovery.metadata.gray-version:normal}"
)
```

### 3. 最佳实践

1. **版本标识规范**: 使用语义化的版本标识，如`gray-feat1`、`gray-feat2`
2. **降级策略**: 确保灰度版本不可用时能够降级到稳定版本
3. **监控告警**: 监控各版本的流量分布和错误率
4. **渐进式发布**: 从小流量开始，逐步扩大灰度范围
5. **快速回滚**: 发现问题时能够快速切换回稳定版本

## 🧪 测试验证

### 自动化测试脚本

```bash
# 1. 服务基础功能测试
./scripts/test-services.sh

# 2. RocketMQ灰度路由测试
./scripts/test-mq-gray-routing.sh

# 3. 简化版本验证测试
./scripts/test-mq-gray-routing-simple.sh

# 4. 交互式演示脚本（推荐用于学习和演示）
./scripts/demo-gray-routing.sh
```

### 🎭 交互式演示

**推荐使用演示脚本进行学习**：

```bash
# 启动交互式演示（包含详细说明和步骤指导）
./scripts/demo-gray-routing.sh
```

演示脚本特点：
- 🎯 **分步骤指导**: 每个步骤都有详细说明和预期结果
- 🔍 **实时验证**: 自动检查服务状态和路由结果
- 📊 **日志分析**: 指导查看和分析关键日志
- 🛠️ **故障演示**: 演示故障转移和降级机制
- 📚 **学习友好**: 适合初学者理解灰度发布原理

演示内容包括：
1. **服务健康检查** - 验证所有服务正常运行
2. **HTTP请求灰度路由** - 演示请求头路由机制
3. **RocketMQ消息灰度路由** - 演示消息版本隔离
4. **日志验证** - 确认消息路由正确性
5. **故障转移演示** - 演示降级机制
6. **批量测试** - 验证路由稳定性

### 手动验证检查点

- [ ] 所有服务正常启动并注册到Nacos
- [ ] HTTP请求能够根据gray头部正确路由
- [ ] RocketMQ消息按版本精确投递和消费
- [ ] 服务健康检查全部通过
- [ ] 日志中无错误信息
- [ ] 灰度版本不可用时能够降级

### 常见问题排查

1. **服务启动失败**: 检查端口占用和依赖服务状态
2. **路由不生效**: 验证Nacos元数据配置和Gateway过滤器
3. **消息路由错误**: 检查RocketMQ Topic和Tag配置
4. **版本不匹配**: 确认环境变量GRAY_VERSION设置正确

## 灰度发布流程

1. **请求到达Gateway**: 客户端请求携带 `gray` 头部到达Gateway
2. **Gateway路由**: Gateway根据 `gray` 头部选择对应版本的Consumer实例
3. **Consumer处理**: Consumer处理业务逻辑，调用Provider服务时传递灰度标识
4. **Provider响应**: Provider根据版本返回不同的业务数据
5. **结果返回**: 结果逐层返回到客户端

## 配置说明

### 灰度版本配置
通过环境变量 `GRAY_VERSION` 设置服务版本:
- `normal`: 正常版本 (默认)
- `gray-feat1`: 灰度功能1
- `gray-feat2`: 灰度功能2

### Nacos 配置
- 服务地址: `localhost:8848`
- 命名空间: `public`
- 分组: `DEFAULT_GROUP`

## 监控与管理

### Actuator 端点
所有服务都开启了 Actuator 监控端点:
- `/actuator/health`: 健康检查
- `/actuator/info`: 应用信息
- `/actuator/metrics`: 指标信息

### Nacos 控制台
访问 http://localhost:8848/nacos 查看:
- 服务注册情况
- 服务实例详情
- 配置管理

## RocketMQ 灰度路由

### 功能说明
本项目实现了基于RocketMQ的灰度路由功能，支持按版本精确投递和消费消息：

1. **Consumer发送消息**: Consumer服务调用 `/api/send-message` 接口时，会：
   - 调用Provider的hello接口
   - 发送带有灰度标识的消息到RocketMQ

2. **Provider消费消息**: 每个Provider实例只消费匹配自己版本的消息：
   - Normal版本只消费 `gray=null/normal` 的消息
   - Gray-feat1版本只消费 `gray=gray-feat1` 的消息
   - Gray-feat2版本只消费 `gray=gray-feat2` 的消息

### 实现原理
- **消息发送**: Consumer在发送消息时，将灰度标识设置为消息的用户属性
- **消费者组**: 不同版本的Provider使用不同的消费者组名称
- **版本匹配**: Provider消费者严格匹配消息的灰度标识和自身版本

### 配置说明
- **Topic**: `gray-topic`
- **Producer Group**: `consumer-gray-producer`
- **Consumer Group**: `provider-consumer-{version}`
- **NameServer**: `localhost:9876`

## 注意事项

1. 确保 Nacos 和 RocketMQ 服务已启动
2. 各服务启动顺序: Nacos -> RocketMQ -> Provider -> Consumer -> Gateway
3. 灰度标识通过 HTTP Header `gray` 传递
4. 服务版本通过 Nacos metadata `gray-version` 区分
5. 支持版本降级，未找到灰度版本时自动降级到 normal 版本
6. RocketMQ消息严格按版本路由，确保灰度环境隔离

## 扩展功能

- 支持更多灰度策略 (按用户ID、地区等)
- 集成配置中心动态调整灰度规则
- 添加链路追踪和监控
- 支持蓝绿部署和金丝雀发布
