# Spring Cloud 灰度发布演示项目

## 项目概述

本项目是一个基于 Spring Cloud 的微服务灰度发布演示系统，包含 Gateway、Consumer、Provider 三个模块，支持多版本灰度发布功能。

## 技术栈

- Java 8
- Spring Boot 2.7.18
- Spring Cloud 2021.0.8
- Spring Cloud Alibaba 2021.0.5.0
- Nacos (服务注册与配置中心)

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

## 快速启动

### 1. 启动 Nacos

```bash
# 下载并启动 Nacos (单机模式)
cd nacos/bin
./startup.sh -m standalone
```

Nacos 控制台: http://localhost:8848/nacos (用户名/密码: nacos/nacos)

### 2. 编译项目

```bash
mvn clean compile
```

### 3. 启动服务

#### 启动 Gateway
```bash
cd gateway
mvn spring-boot:run
```

#### 启动 Consumer (多版本)
```bash
# Normal 版本
cd consumer
mvn spring-boot:run

# Gray-feat1 版本
cd consumer
GRAY_VERSION=gray-feat1 SERVER_PORT=8083 mvn spring-boot:run

# Gray-feat2 版本
cd consumer
GRAY_VERSION=gray-feat2 SERVER_PORT=8084 mvn spring-boot:run
```

#### 启动 Provider (多版本)
```bash
# Normal 版本
cd provider
mvn spring-boot:run

# Gray-feat1 版本
cd provider
GRAY_VERSION=gray-feat1 SERVER_PORT=8085 mvn spring-boot:run

# Gray-feat2 版本
cd provider
GRAY_VERSION=gray-feat2 SERVER_PORT=8086 mvn spring-boot:run
```

## 测试灰度发布

### 1. 正常版本测试
```bash
curl -X GET http://localhost:8080/consumer/api/test
```

### 2. 灰度版本测试
```bash
# 测试灰度功能1
curl -X GET http://localhost:8080/consumer/api/test -H "gray: gray-feat1"

# 测试灰度功能2
curl -X GET http://localhost:8080/consumer/api/test -H "gray: gray-feat2"
```

### 3. 健康检查
```bash
# Gateway 健康检查
curl -X GET http://localhost:8080/actuator/health

# Consumer 健康检查
curl -X GET http://localhost:8081/actuator/health

# Provider 健康检查
curl -X GET http://localhost:8082/actuator/health
```

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

## 注意事项

1. 确保 Nacos 服务已启动
2. 各服务启动顺序: Nacos -> Provider -> Consumer -> Gateway
3. 灰度标识通过 HTTP Header `gray` 传递
4. 服务版本通过 Nacos metadata `gray-version` 区分
5. 支持版本降级，未找到灰度版本时自动降级到 normal 版本

## 扩展功能

- 支持更多灰度策略 (按用户ID、地区等)
- 集成配置中心动态调整灰度规则
- 添加链路追踪和监控
- 支持蓝绿部署和金丝雀发布
