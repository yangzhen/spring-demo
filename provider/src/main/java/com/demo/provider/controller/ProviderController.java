package com.demo.provider.controller;

import com.demo.provider.service.ProviderService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.annotation.Resource;
import java.util.HashMap;
import java.util.Map;

/**
 * Provider 控制器
 * 
 * @author demo
 */
@Slf4j
@RestController
@RequestMapping("/api")
public class ProviderController {

    @Resource
    private ProviderService providerService;

    @Value("${spring.cloud.nacos.discovery.metadata.gray-version:normal}")
    private String grayVersion;

    @Value("${server.port}")
    private String port;

    /**
     * 获取数据接口
     */
    @GetMapping("/data")
    public Map<String, Object> getData(@RequestHeader(value = "gray", required = false) String gray) {
        log.info("Provider接收到请求，灰度标识: {}, 当前版本: {}", gray, grayVersion);
        
        Map<String, Object> result = new HashMap<>();
        result.put("service", "provider");
        result.put("version", grayVersion);
        result.put("port", port);
        result.put("gray", gray);
        result.put("timestamp", System.currentTimeMillis());
        
        // 根据版本返回不同的业务数据
        Map<String, Object> businessData = providerService.getBusinessData(grayVersion);
        result.put("businessData", businessData);
        
        return result;
    }

    /**
     * 健康检查接口
     */
    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> result = new HashMap<>();
        result.put("status", "UP");
        result.put("service", "provider");
        result.put("version", grayVersion);
        result.put("port", port);
        return result;
    }
}
