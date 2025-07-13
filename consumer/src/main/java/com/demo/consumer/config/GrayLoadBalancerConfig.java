package com.demo.consumer.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.cloud.loadbalancer.annotation.LoadBalancerClient;
import org.springframework.cloud.loadbalancer.core.ServiceInstanceListSupplier;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 灰度负载均衡配置
 * 基于ServiceInstanceListSupplier实现灰度路由
 * 
 * @author demo
 */
@Slf4j
@Configuration
@LoadBalancerClient(name = "provider", configuration = GrayLoadBalancerConfig.class)
public class GrayLoadBalancerConfig {

    /**
     * 自定义服务实例列表提供器
     * 使用装饰器模式包装默认的ServiceInstanceListSupplier
     */
    @Bean
    public ServiceInstanceListSupplier serviceInstanceListSupplier(
            ConfigurableApplicationContext context) {
        
        log.info("创建灰度ServiceInstanceListSupplier");
        
        // 构建默认的ServiceInstanceListSupplier链
        // 使用withBlockingDiscoveryClient()而不是withDiscoveryClient()来避免ReactiveDiscoveryClient依赖
        ServiceInstanceListSupplier baseSupplier = ServiceInstanceListSupplier.builder()
                .withBlockingDiscoveryClient()
                .withCaching()
                .build(context);
        
        // 使用灰度过滤器包装
        return new GrayServiceInstanceListSupplier(baseSupplier);
    }
}
