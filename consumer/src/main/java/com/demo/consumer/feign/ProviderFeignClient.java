package com.demo.consumer.feign;

import com.demo.consumer.config.GrayFeignRequestInterceptor;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;

import java.util.Map;

/**
 * Provider服务Feign客户端
 * 
 * @author demo
 */
@FeignClient(name = "provider", configuration = GrayFeignRequestInterceptor.class)
public interface ProviderFeignClient {

    /**
     * 获取Provider数据
     */
    @GetMapping("/api/data")
    Map<String, Object> getData(@RequestHeader(value = "gray", required = false) String gray);

    /**
     * 调用Provider Hello接口
     */
    @GetMapping("/api/hello")
    Map<String, Object> hello(@RequestHeader(value = "gray", required = false) String gray);
}
