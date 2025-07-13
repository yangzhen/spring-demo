package com.demo.consumer.controller;

import com.demo.consumer.config.GrayContext;
import com.demo.consumer.service.ConsumerService;
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
 * Consumer 控制器
 * 
 * @author demo
 */
@Slf4j
@RestController
@RequestMapping("/api")
public class ConsumerController {

    @Resource
    private ConsumerService consumerService;

    @Value("${spring.cloud.nacos.discovery.metadata.gray-version:normal}")
    private String grayVersion;

    @Value("${server.port}")
    private String port;

    /**
     * 测试接口
     */
    @GetMapping("/test")
    public Map<String, Object> test(@RequestHeader(value = "gray", required = false) String gray) {
        try {
            // 设置灰度上下文
            GrayContext.setGrayVersion(gray);
            
            log.info("Consumer接收到请求，灰度标识: {}, 当前版本: {}", gray, grayVersion);
            
            Map<String, Object> result = new HashMap<>();
            result.put("service", "consumer");
            result.put("version", grayVersion);
            result.put("port", port);
            result.put("gray", gray);
            result.put("timestamp", System.currentTimeMillis());
            
            // 调用Provider服务
            Map<String, Object> providerResult = consumerService.callProvider(gray);
            result.put("providerData", providerResult);
            
            return result;
        } finally {
            // 清理灰度上下文
            GrayContext.clear();
        }
    }

    /**
     * 健康检查接口
     */
    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> result = new HashMap<>();
        result.put("status", "UP");
        result.put("service", "consumer");
        result.put("version", grayVersion);
        result.put("port", port);
        return result;
    }
}
