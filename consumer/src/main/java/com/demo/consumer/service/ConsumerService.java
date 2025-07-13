package com.demo.consumer.service;

import com.demo.consumer.feign.ProviderFeignClient;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.util.Map;

/**
 * Consumer 服务类
 * 
 * @author demo
 */
@Slf4j
@Service
public class ConsumerService {

    @Resource
    private ProviderFeignClient providerFeignClient;

    /**
     * 调用Provider服务
     */
    public Map<String, Object> callProvider(String gray) {
        try {
            log.info("Consumer调用Provider服务，灰度标识: {}", gray);
            return providerFeignClient.getData(gray);
        } catch (Exception e) {
            log.error("调用Provider服务失败", e);
            throw new RuntimeException("调用Provider服务失败: " + e.getMessage());
        }
    }
}
