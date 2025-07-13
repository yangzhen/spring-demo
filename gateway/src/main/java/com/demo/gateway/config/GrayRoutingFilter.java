package com.demo.gateway.config;

import cn.hutool.core.util.StrUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cloud.client.ServiceInstance;
import org.springframework.cloud.client.discovery.DiscoveryClient;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.cloud.gateway.support.ServerWebExchangeUtils;
import org.springframework.core.Ordered;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import javax.annotation.Resource;
import java.net.URI;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 灰度路由过滤器
 * 根据请求头中的gray标识，动态路由到对应版本的服务实例
 * 
 * @author demo
 */
@Slf4j
@Component
public class GrayRoutingFilter implements GlobalFilter, Ordered {

    @Resource
    private DiscoveryClient discoveryClient;

    private static final String GRAY_HEADER = "gray";
    private static final String GRAY_VERSION_KEY = "gray-version";
    private static final String NORMAL_VERSION = "normal";

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();
        
        // 获取请求头中的灰度标识
        String grayVersion = request.getHeaders().getFirst(GRAY_HEADER);
        if (StrUtil.isBlank(grayVersion)) {
            grayVersion = NORMAL_VERSION;
        }
        
        log.info("请求路径: {}, 灰度版本: {}", request.getPath(), grayVersion);
        
        // 获取目标服务名
        URI uri = exchange.getAttribute(ServerWebExchangeUtils.GATEWAY_REQUEST_URL_ATTR);
        if (uri != null) {
            String serviceName = uri.getHost();
            
            // 根据灰度版本选择服务实例
            ServiceInstance targetInstance = selectServiceInstance(serviceName, grayVersion);
            
            if (targetInstance != null) {
                // 构建新的URI
                URI newUri = URI.create(String.format("%s://%s:%d%s", 
                    uri.getScheme(), 
                    targetInstance.getHost(), 
                    targetInstance.getPort(), 
                    uri.getPath()));
                
                // 更新请求URI
                exchange.getAttributes().put(ServerWebExchangeUtils.GATEWAY_REQUEST_URL_ATTR, newUri);
                
                log.info("路由到实例: {}:{}, 版本: {}", 
                    targetInstance.getHost(), 
                    targetInstance.getPort(), 
                    targetInstance.getMetadata().get(GRAY_VERSION_KEY));
            }
        }
        
        // 将灰度标识传递给下游服务
        ServerHttpRequest mutatedRequest = request.mutate()
            .header(GRAY_HEADER, grayVersion)
            .build();
        
        return chain.filter(exchange.mutate().request(mutatedRequest).build());
    }

    /**
     * 根据灰度版本选择服务实例
     */
    private ServiceInstance selectServiceInstance(String serviceName, String grayVersion) {
        try {
            List<ServiceInstance> instances = discoveryClient.getInstances(serviceName);
            if (instances.isEmpty()) {
                log.warn("未找到服务实例: {}", serviceName);
                return null;
            }
            
            // 过滤出匹配灰度版本的实例
            List<ServiceInstance> grayInstances = instances.stream()
                .filter(instance -> {
                    Map<String, String> metadata = instance.getMetadata();
                    String instanceGrayVersion = metadata.getOrDefault(GRAY_VERSION_KEY, NORMAL_VERSION);
                    return grayVersion.equals(instanceGrayVersion);
                })
                .collect(Collectors.toList());
            
            if (!grayInstances.isEmpty()) {
                // 简单轮询选择实例（实际项目中可以使用更复杂的负载均衡算法）
                int index = (int) (System.currentTimeMillis() % grayInstances.size());
                return grayInstances.get(index);
            } else {
                // 如果没有匹配的灰度实例，降级到normal版本
                List<ServiceInstance> normalInstances = instances.stream()
                    .filter(instance -> {
                        Map<String, String> metadata = instance.getMetadata();
                        String instanceGrayVersion = metadata.getOrDefault(GRAY_VERSION_KEY, NORMAL_VERSION);
                        return NORMAL_VERSION.equals(instanceGrayVersion);
                    })
                    .collect(Collectors.toList());
                
                if (!normalInstances.isEmpty()) {
                    log.warn("未找到灰度版本 {} 的实例，降级到normal版本", grayVersion);
                    int index = (int) (System.currentTimeMillis() % normalInstances.size());
                    return normalInstances.get(index);
                }
            }
            
            log.warn("未找到可用的服务实例: {}", serviceName);
            return null;
            
        } catch (Exception e) {
            log.error("选择服务实例失败: {}", serviceName, e);
            return null;
        }
    }

    @Override
    public int getOrder() {
        return -100;
    }
}
