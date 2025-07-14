# Spring Cloud 灰度发布项目结构说明

## 项目整体结构

```
spring-cloud-gray-demo/
├── pom.xml                                    # 顶层父工程POM文件
├── README.md                                  # 项目说明文档
├── PROJECT_STRUCTURE.md                       # 项目结构说明文档
├── GRAY_ROUTING_IMPLEMENTATION.md             # 灰度路由实现技术文档
├── GRAY_RELEASE_GUIDE.md                      # 灰度发布实践指导手册
├── ROCKETMQ_GRAY_ROUTING.md                   # RocketMQ灰度路由专项说明
├── REQUIREMENTS_BEST_PRACTICES.md             # 需求分析和最佳实践
├── .gitignore                                 # Git忽略文件配置
├── logs/                                      # 日志文件目录
├── scripts/                                   # 启动脚本目录
│   ├── start-all.sh                          # 启动所有服务脚本
│   ├── stop-all.sh                           # 停止所有服务脚本
│   ├── test-services.sh                      # 服务功能测试脚本
│   ├── test-mq-gray-routing.sh               # RocketMQ灰度路由测试脚本
│   ├── test-mq-gray-routing-simple.sh        # 简化版MQ路由测试脚本
│   └── demo-gray-routing.sh                  # 交互式演示脚本
├── gateway/                                   # 网关模块
│   ├── pom.xml                               # Gateway模块POM文件
│   └── src/main/
│       ├── java/com/demo/gateway/
│       │   ├── GatewayApplication.java       # Gateway启动类
│       │   └── config/
│       │       └── GrayRoutingFilter.java    # 灰度路由过滤器
│       └── resources/
│           ├── application.yml               # Gateway应用配置
│           └── bootstrap.yml                 # Gateway引导配置
├── consumer/                                  # 消费者模块
│   ├── pom.xml                               # Consumer模块POM文件
│   └── src/main/
│       ├── java/com/demo/consumer/
│       │   ├── ConsumerApplication.java      # Consumer启动类
│       │   ├── controller/
│       │   │   └── ConsumerController.java   # Consumer控制器
│       │   ├── service/
│       │   │   └── ConsumerService.java      # Consumer服务类
│       │   ├── feign/
│       │   │   └── ProviderFeignClient.java  # Provider服务Feign客户端
│       │   └── config/
│       │       ├── GrayContext.java          # 灰度上下文管理
│       │       ├── GrayFeignRequestInterceptor.java    # 灰度Feign请求拦截器
│       │       ├── GrayLoadBalancerConfig.java         # 灰度负载均衡配置
│       │       └── GrayServiceInstanceListSupplier.java # 灰度服务实例供应器
│       └── resources/
│           ├── application.yml               # Consumer应用配置
│           └── bootstrap.yml                 # Consumer引导配置
└── provider/                                  # 提供者模块
    ├── pom.xml                               # Provider模块POM文件
    └── src/main/
        ├── java/com/demo/provider/
        │   ├── ProviderApplication.java      # Provider启动类
        │   ├── controller/
        │   │   └── ProviderController.java   # Provider控制器
        │   ├── service/
        │   │   └── ProviderService.java      # Provider服务类
        │   └── consumer/
        │       └── GrayMessageConsumer.java  # RocketMQ灰度消息消费者
        └── resources/
            ├── application.yml               # Provider应用配置
            └── bootstrap.yml                 # Provider引导配置
```

## 模块详细说明

### 1. 顶层父工程 (/)

#### pom.xml
- **作用**: Maven多模块父工程配置
- **功能**: 
  - 管理子模块依赖版本
  - 统一Spring Boot、Spring Cloud、Spring Cloud Alibaba版本
  - 配置公共依赖和插件
  - 设置Java 1.8编译环境

### 2. Gateway模块 (/gateway)

#### GatewayApplication.java
- **作用**: Gateway网关启动类
- **功能**: 
  - 启用服务发现 (@EnableDiscoveryClient)
  - Spring Boot应用入口

#### GrayRoutingFilter.java
- **作用**: 灰度路由核心过滤器
- **功能**: 
  - 解析请求头中的灰度标识 (gray)
  - 从Nacos获取服务实例列表
  - 根据灰度版本选择目标服务实例
  - 支持版本降级 (灰度版本不存在时降级到normal)
  - 传递灰度标识到下游服务

#### 配置文件
- **bootstrap.yml**: Nacos服务发现和配置中心配置
- **application.yml**: Gateway路由规则、监控端点配置

### 3. Consumer模块 (/consumer)

#### ConsumerApplication.java
- **作用**: Consumer服务启动类
- **功能**: 
  - 启用服务发现 (@EnableDiscoveryClient)
  - 启用Feign客户端 (@EnableFeignClients)

#### ConsumerController.java
- **作用**: Consumer REST控制器
- **功能**: 
  - 提供 /api/test 测试接口
  - 提供 /api/health 健康检查接口
  - 接收并处理灰度标识
  - 调用Provider服务

#### ConsumerService.java
- **作用**: Consumer业务服务类
- **功能**: 
  - 封装Provider服务调用逻辑
  - 异常处理

#### ProviderFeignClient.java
- **作用**: Provider服务的Feign客户端
- **功能**: 
  - 声明式HTTP客户端
  - 集成灰度请求拦截器
  - 调用Provider服务接口

#### GrayFeignRequestInterceptor.java
- **作用**: Feign请求拦截器
- **功能**: 
  - 在Feign调用时自动添加灰度标识头部
  - 从当前请求上下文获取灰度标识

#### GrayLoadBalancerConfig.java
- **作用**: 灰度负载均衡配置
- **功能**: 
  - 自定义负载均衡器
  - 根据灰度标识选择服务实例
  - 支持版本降级策略

#### 配置文件
- **bootstrap.yml**: Nacos配置，支持通过环境变量设置灰度版本
- **application.yml**: 服务端口、Feign配置、监控配置

### 4. Provider模块 (/provider)

#### ProviderApplication.java
- **作用**: Provider服务启动类
- **功能**: 
  - 启用服务发现 (@EnableDiscoveryClient)

#### ProviderController.java
- **作用**: Provider REST控制器
- **功能**: 
  - 提供 /api/data 数据接口
  - 提供 /api/health 健康检查接口
  - 接收灰度标识
  - 返回版本相关的业务数据

#### ProviderService.java
- **作用**: Provider业务服务类
- **功能**: 
  - 根据版本提供不同的业务逻辑
  - normal版本: 基础功能
  - gray-feat1版本: 用户画像分析功能
  - gray-feat2版本: 搜索算法优化功能

#### 配置文件
- **bootstrap.yml**: Nacos配置，支持通过环境变量设置灰度版本
- **application.yml**: 服务端口、监控配置

### 5. 新增核心组件

#### GrayContext.java (Consumer模块)
- **作用**: 灰度上下文管理器
- **功能**: 
  - 使用ThreadLocal管理请求级别的灰度标识
  - 提供灰度版本的设置、获取和清理方法
  - 确保灰度标识在整个调用链中的传递

#### GrayServiceInstanceListSupplier.java (Consumer模块)
- **作用**: 灰度服务实例供应器
- **功能**: 
  - 自定义服务实例过滤逻辑
  - 根据灰度标识筛选匹配的服务实例
  - 实现版本降级策略（灰度版本不可用时降级到normal）

#### GrayMessageConsumer.java (Provider模块)
- **作用**: RocketMQ灰度消息消费者
- **功能**: 
  - 基于Tag机制实现消息版本隔离
  - 严格匹配消息灰度标识和消费者版本
  - 提供不同版本的业务处理逻辑
  - 支持消息处理的监控和日志记录

### 6. 文档体系

#### README.md
- **作用**: 项目主文档
- **内容**: 项目概述、快速启动、演示指南、测试验证

#### GRAY_RELEASE_GUIDE.md
- **作用**: 灰度发布实践指导手册
- **内容**: 
  - 完整的学习目标和前置知识
  - 架构设计原理和实现步骤
  - 测试验证指南和最佳实践
  - 监控运维和故障排查
  - 扩展功能和高级特性

#### ROCKETMQ_GRAY_ROUTING.md
- **作用**: RocketMQ灰度路由专项说明
- **内容**: 
  - RocketMQ灰度路由的实现原理
  - Tag机制的技术细节
  - 问题排查和解决方案
  - 性能优化建议

#### GRAY_ROUTING_IMPLEMENTATION.md
- **作用**: 灰度路由实现技术文档
- **内容**: 
  - 详细的技术实现说明
  - 核心组件的设计思路
  - 代码示例和配置说明

#### REQUIREMENTS_BEST_PRACTICES.md
- **作用**: 需求分析和最佳实践
- **内容**: 
  - 灰度发布的业务需求分析
  - 技术选型和架构决策
  - 开发和运维最佳实践

### 7. 脚本目录 (/scripts)

#### start-all.sh
- **作用**: 一键启动所有服务脚本
- **功能**: 
  - 检查Java和Maven环境
  - 编译项目
  - 按顺序启动所有服务的多个版本
  - 生成启动日志
  - 提供测试命令示例

#### stop-all.sh
- **作用**: 一键停止所有服务脚本
- **功能**: 
  - 查找并停止所有Spring Boot进程
  - 优雅关闭和强制终止
  - 可选清理日志文件

#### test-services.sh
- **作用**: 服务基础功能测试脚本
- **功能**: 
  - 验证所有服务的健康状态
  - 测试HTTP请求灰度路由功能
  - 检查服务注册和发现

#### test-mq-gray-routing.sh
- **作用**: RocketMQ灰度路由测试脚本
- **功能**: 
  - 测试消息发送和灰度路由
  - 验证消息版本隔离
  - 批量测试和结果验证

#### test-mq-gray-routing-simple.sh
- **作用**: 简化版MQ路由测试脚本
- **功能**: 
  - 快速验证RocketMQ灰度路由核心功能
  - 检查配置和实现的正确性
  - 适合CI/CD集成

#### demo-gray-routing.sh
- **作用**: 交互式演示脚本
- **功能**: 
  - 分步骤指导演示灰度发布功能
  - 实时验证和结果分析
  - 故障转移和降级演示
  - 适合学习和培训使用

## 灰度发布实现原理

### 1. 版本标识
- 通过Nacos metadata中的 `gray-version` 字段标识服务版本
- 支持的版本: `normal`、`gray-feat1`、`gray-feat2`

### 2. HTTP请求路由
- 客户端通过HTTP Header `gray` 传递灰度标识
- Gateway根据灰度标识路由到对应版本的Consumer
- Consumer根据灰度标识调用对应版本的Provider

### 3. RocketMQ消息路由
- **消息发送**: Consumer发送消息时，将灰度标识设置为消息Tag
- **消费者组**: 不同版本的Provider使用不同的消费者组
  - Normal版本: `provider-consumer-normal`
  - Gray-feat1版本: `provider-consumer-gray-feat1`
  - Gray-feat2版本: `provider-consumer-gray-feat2`
- **Tag过滤**: 消费者通过selectorExpression只消费匹配版本的消息
- **版本隔离**: 确保消息严格按版本路由，避免跨版本消费

### 4. 负载均衡
- 自定义负载均衡器根据灰度标识过滤服务实例
- 支持版本降级，确保服务可用性

### 5. 配置管理
- 通过环境变量 `GRAY_VERSION` 设置服务版本
- 支持动态配置和热更新

### 6. 灰度上下文传递
- 使用ThreadLocal在单个请求中维护灰度标识
- 通过Feign拦截器在服务间调用中传递灰度标识
- 确保整个调用链的灰度一致性

## 部署架构

### 服务端口分配
- Gateway: 8080
- Consumer Normal: 8081
- Consumer Gray-feat1: 8083
- Consumer Gray-feat2: 8084
- Provider Normal: 8082
- Provider Gray-feat1: 8085
- Provider Gray-feat2: 8086

### 依赖关系
```
Client -> Gateway -> Consumer -> Provider -> Nacos
```

### 启动顺序
1. Nacos服务注册中心
2. Provider服务 (所有版本)
3. Consumer服务 (所有版本)
4. Gateway网关服务

这个项目结构清晰地展示了Spring Cloud微服务灰度发布的完整实现，包含了服务注册发现、负载均衡、配置管理等核心功能。
