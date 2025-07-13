# Spring Cloud LoadBalancer 灰度路由实现

## 实现方案对比

### 原方案：基于 Feign 拦截器
- **实现方式**：通过 `FeignRequestInterceptor` 拦截请求，手动选择服务实例
- **缺点**：
  - 需要重复实现负载均衡逻辑
  - 与 Spring Cloud LoadBalancer 的设计理念不符
  - 代码复杂，维护困难
  - 性能开销较大

### 新方案：基于 ServiceInstanceListSupplier
- **实现方式**：通过自定义 `ServiceInstanceListSupplier` 过滤服务实例列表
- **优点**：
  - 符合 Spring Cloud LoadBalancer 的设计理念
  - 职责分离：ServiceInstanceListSupplier 负责实例过滤，LoadBalancer 负责选择策略
  - 代码简洁，易于维护
  - 性能更优，与框架集成更好

## 核心组件

### 1. GrayContext
```java
// 灰度上下文管理器，使用 ThreadLocal 管理当前请求的灰度信息
public class GrayContext {
    private static final ThreadLocal<String> GRAY_VERSION_HOLDER = new ThreadLocal<>();
    
    public static void setGrayVersion(String grayVersion);
    public static String getGrayVersion();
    public static void clear();
}
```

### 2. GrayServiceInstanceListSupplier
```java
// 灰度服务实例列表提供器，基于灰度上下文过滤服务实例
public class GrayServiceInstanceListSupplier implements ServiceInstanceListSupplier {
    private final ServiceInstanceListSupplier delegate;
    
    @Override
    public Flux<List<ServiceInstance>> get() {
        return delegate.get().map(this::filterByGrayVersion);
    }
}
```

### 3. GrayLoadBalancerConfig
```java
// 灰度负载均衡配置，使用装饰器模式包装默认的 ServiceInstanceListSupplier
@LoadBalancerClient(name = "provider", configuration = GrayLoadBalancerConfig.class)
public class GrayLoadBalancerConfig {
    
    @Bean
    public ServiceInstanceListSupplier serviceInstanceListSupplier(ConfigurableApplicationContext context) {
        ServiceInstanceListSupplier baseSupplier = ServiceInstanceListSupplier.builder()
                .withBlockingDiscoveryClient()
                .withCaching()
                .build(context);
        
        return new GrayServiceInstanceListSupplier(baseSupplier);
    }
}
```

### 4. 简化的 FeignRequestInterceptor
```java
// 仅负责传递灰度标识，不再处理服务实例选择
public class GrayFeignRequestInterceptor implements RequestInterceptor {
    @Override
    public void apply(RequestTemplate template) {
        String grayVersion = GrayContext.getGrayVersion();
        if (grayVersion != null && !GrayContext.getNormalVersion().equals(grayVersion)) {
            template.header("gray", grayVersion);
        }
    }
}
```

## 工作流程

1. **请求到达 Consumer**：Controller 设置灰度上下文
2. **Feign 调用 Provider**：拦截器添加灰度标识到请求头
3. **LoadBalancer 选择实例**：ServiceInstanceListSupplier 根据灰度上下文过滤实例
4. **请求完成**：清理灰度上下文

## 测试结果

```bash
=== 多次测试验证灰度路由一致性 ===

第1次测试:
  正常版本:
    Consumer版本: gray-feat2, Provider版本: normal
  gray-feat1:
    Consumer版本: gray-feat1, Provider版本: gray-feat1
  gray-feat2:
    Consumer版本: normal, Provider版本: gray-feat2

第2次测试:
  正常版本:
    Consumer版本: gray-feat2, Provider版本: normal
  gray-feat1:
    Consumer版本: gray-feat1, Provider版本: gray-feat1
  gray-feat2:
    Consumer版本: normal, Provider版本: gray-feat2

第3次测试:
  正常版本:
    Consumer版本: gray-feat2, Provider版本: normal
  gray-feat1:
    Consumer版本: gray-feat1, Provider版本: gray-feat1
  gray-feat2:
    Consumer版本: normal, Provider版本: gray-feat2
```

## 技术优势

1. **标准化**：完全基于 Spring Cloud LoadBalancer 标准实现
2. **可扩展**：可以轻松添加其他负载均衡策略（权重、健康检查等）
3. **高性能**：避免了手动服务发现和实例选择的开销
4. **易维护**：代码结构清晰，职责分离明确
5. **容错性**：支持灰度版本不存在时的降级策略

## 总结

通过使用 ServiceInstanceListSupplier 而不是自定义 ReactorLoadBalancer，我们实现了一个更加优雅、高效和符合 Spring Cloud 设计理念的灰度路由方案。这种实现方式不仅代码更简洁，而且性能更好，维护成本更低。
