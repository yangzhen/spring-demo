package com.demo.consumer.service;

import com.demo.consumer.feign.ProviderFeignClient;
import lombok.extern.slf4j.Slf4j;
import org.apache.rocketmq.spring.core.RocketMQTemplate;
import org.springframework.messaging.Message;
import org.springframework.messaging.support.MessageBuilder;
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

    @Resource
    private RocketMQTemplate rocketMQTemplate;

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

    /**
     * 调用Provider的hello接口
     */
    public Map<String, Object> callProviderHello(String gray) {
        try {
            log.info("Consumer调用Provider Hello接口，灰度标识: {}", gray);
            return providerFeignClient.hello(gray);
        } catch (Exception e) {
            log.error("调用Provider Hello接口失败", e);
            throw new RuntimeException("调用Provider Hello接口失败: " + e.getMessage());
        }
    }

    /**
     * 发送灰度消息到RocketMQ
     */
    public void sendGrayMessage(String gray) {
        try {
            String messageBody = "Hello MQ Gray";
            String grayTag = gray != null ? gray : "normal";
            
            // 构建消息，设置灰度标识为用户属性（保留兼容性）
            Message<String> message = MessageBuilder
                .withPayload(messageBody)
                .setHeader("gray", grayTag)
                .build();
            
            // 使用Tag机制发送消息：topic:tag格式
            String destination = "gray-topic:" + grayTag;
            rocketMQTemplate.syncSend(destination, message);
            
            log.info("发送灰度消息成功: destination={}, gray={}, message={}", 
                destination, grayTag, messageBody);
        } catch (Exception e) {
            log.error("发送灰度消息失败", e);
            throw new RuntimeException("发送灰度消息失败: " + e.getMessage());
        }
    }
}
