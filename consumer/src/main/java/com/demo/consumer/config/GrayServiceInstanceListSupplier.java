package com.demo.consumer.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.cloud.client.ServiceInstance;
import org.springframework.cloud.loadbalancer.core.ServiceInstanceListSupplier;
import reactor.core.publisher.Flux;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 灰度服务实例列表提供器
 * 基于灰度上下文过滤服务实例
 * 
 * @author demo
 */
@Slf4j
public class GrayServiceInstanceListSupplier implements ServiceInstanceListSupplier {

    private static final String GRAY_VERSION_KEY = "gray-version";
    private final ServiceInstanceListSupplier delegate;

    public GrayServiceInstanceListSupplier(ServiceInstanceListSupplier delegate) {
        this.delegate = delegate;
    }

    @Override
    public String getServiceId() {
        return delegate.getServiceId();
    }

    @Override
    public Flux<List<ServiceInstance>> get() {
        return delegate.get().map(this::filterByGrayVersion);
    }

    /**
     * 根据灰度版本过滤服务实例
     */
    private List<ServiceInstance> filterByGrayVersion(List<ServiceInstance> instances) {
        if (instances.isEmpty()) {
            log.warn("没有可用的服务实例: {}", getServiceId());
            return instances;
        }

        // 从灰度上下文获取灰度版本
        String grayVersion = GrayContext.getGrayVersion();
        log.debug("ServiceInstanceListSupplier过滤服务实例，服务: {}, 灰度版本: {}", getServiceId(), grayVersion);

        // 根据灰度版本过滤实例
        List<ServiceInstance> filteredInstances = filterInstancesByGrayVersion(instances, grayVersion);
        
        if (filteredInstances.isEmpty()) {
            // 如果没有匹配的灰度实例，降级到normal版本
            log.warn("未找到灰度版本 {} 的实例，降级到normal版本", grayVersion);
            filteredInstances = filterInstancesByGrayVersion(instances, GrayContext.getNormalVersion());
            
            if (filteredInstances.isEmpty()) {
                log.error("未找到任何可用的服务实例: {}", getServiceId());
                return instances; // 返回原始列表作为最后的降级
            }
        }

        log.info("ServiceInstanceListSupplier过滤结果: 服务={}, 灰度版本={}, 可用实例数={}", 
            getServiceId(), grayVersion, filteredInstances.size());
        
        return filteredInstances;
    }

    /**
     * 根据灰度版本过滤服务实例
     */
    private List<ServiceInstance> filterInstancesByGrayVersion(List<ServiceInstance> instances, String grayVersion) {
        return instances.stream()
            .filter(instance -> {
                Map<String, String> metadata = instance.getMetadata();
                String instanceGrayVersion = metadata.getOrDefault(GRAY_VERSION_KEY, GrayContext.getNormalVersion());
                boolean matches = grayVersion.equals(instanceGrayVersion);
                
                log.debug("实例过滤: {}:{}, 实例版本={}, 目标版本={}, 匹配={}", 
                    instance.getHost(), instance.getPort(), instanceGrayVersion, grayVersion, matches);
                
                return matches;
            })
            .collect(Collectors.toList());
    }
}
