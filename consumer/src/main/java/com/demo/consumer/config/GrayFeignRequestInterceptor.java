package com.demo.consumer.config;

import feign.RequestInterceptor;
import feign.RequestTemplate;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;

/**
 * 灰度Feign请求拦截器
 * 用于在Feign调用时传递灰度标识
 * 服务实例选择由GrayReactorLoadBalancer负责
 * 
 * @author demo
 */
@Slf4j
@Configuration
public class GrayFeignRequestInterceptor implements RequestInterceptor {

    private static final String GRAY_HEADER = "gray";

    @Override
    public void apply(RequestTemplate template) {
        // 从灰度上下文获取灰度版本并传递
        String grayVersion = GrayContext.getGrayVersion();
        
        if (grayVersion != null && !GrayContext.getNormalVersion().equals(grayVersion)) {
            template.header(GRAY_HEADER, grayVersion);
            log.debug("Feign请求添加灰度标识: {}", grayVersion);
        }
    }
}
