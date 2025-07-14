package com.demo.provider.consumer;

import lombok.extern.slf4j.Slf4j;
import org.apache.rocketmq.common.message.MessageExt;
import org.apache.rocketmq.spring.annotation.RocketMQMessageListener;
import org.apache.rocketmq.spring.core.RocketMQListener;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;


/**
 * 灰度消息消费者
 * 根据灰度版本严格匹配消费消息
 * 
 * @author demo
 */
@Slf4j
@Component
@RocketMQMessageListener(
    topic = "gray-topic",
    consumerGroup = "provider-consumer-${spring.cloud.nacos.discovery.metadata.gray-version:normal}",
    selectorExpression = "${spring.cloud.nacos.discovery.metadata.gray-version:normal}"
)
public class GrayMessageConsumer implements RocketMQListener<MessageExt> {

    @Value("${spring.cloud.nacos.discovery.metadata.gray-version:normal}")
    private String currentGrayVersion;

    @Override
    public void onMessage(MessageExt message) {
        String messageGray = message.getUserProperty("gray");
        String messageBody = new String(message.getBody());
        String messageTag = message.getTags();
        
        log.info("收到MQ消息: topic={}, tag={}, messageGray={}, currentVersion={}, body={}", 
            message.getTopic(), messageTag, messageGray, currentGrayVersion, messageBody);
        
        // 由于使用了Tag机制，RocketMQ已经确保只有匹配的消息才会投递到此消费者
        // 因此不需要再进行应用层的版本匹配检查
        
        // 处理消息
        try {
            log.info("开始处理灰度消息: version={}, tag={}, messageId={}, message={}", 
                currentGrayVersion, messageTag, message.getMsgId(), messageBody);
            
            // 这里可以添加具体的业务逻辑
            processGrayMessage(messageBody, currentGrayVersion);
            
            log.info("灰度消息处理完成: version={}, tag={}, messageId={}", 
                currentGrayVersion, messageTag, message.getMsgId());
        } catch (Exception e) {
            log.error("处理灰度消息失败: version={}, tag={}, messageId={}, error={}", 
                currentGrayVersion, messageTag, message.getMsgId(), e.getMessage(), e);
            throw e; // 重新抛出异常，触发重试机制
        }
    }

    /**
     * 处理灰度消息的业务逻辑
     */
    private void processGrayMessage(String messageBody, String grayVersion) {
        // 根据不同的灰度版本执行不同的业务逻辑
        switch (grayVersion) {
            case "gray-feat1":
                log.info("执行gray-feat1版本的消息处理逻辑: {}", messageBody);
                // 这里可以添加gray-feat1特有的业务逻辑
                break;
            case "gray-feat2":
                log.info("执行gray-feat2版本的消息处理逻辑: {}", messageBody);
                // 这里可以添加gray-feat2特有的业务逻辑
                break;
            case "normal":
            default:
                log.info("执行normal版本的消息处理逻辑: {}", messageBody);
                // 这里可以添加normal版本的业务逻辑
                break;
        }
        
        // 模拟业务处理时间
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
