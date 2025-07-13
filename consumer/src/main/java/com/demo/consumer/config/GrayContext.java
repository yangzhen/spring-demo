package com.demo.consumer.config;

import lombok.extern.slf4j.Slf4j;

/**
 * 灰度上下文管理器
 * 使用ThreadLocal管理当前请求的灰度信息
 * 
 * @author demo
 */
@Slf4j
public class GrayContext {

    private static final String NORMAL_VERSION = "normal";
    private static final ThreadLocal<String> GRAY_VERSION_HOLDER = new ThreadLocal<>();

    /**
     * 设置当前请求的灰度版本
     */
    public static void setGrayVersion(String grayVersion) {
        if (grayVersion != null && !grayVersion.trim().isEmpty()) {
            GRAY_VERSION_HOLDER.set(grayVersion.trim());
            log.debug("设置灰度版本: {}", grayVersion);
        } else {
            GRAY_VERSION_HOLDER.set(NORMAL_VERSION);
            log.debug("设置灰度版本为默认: {}", NORMAL_VERSION);
        }
    }

    /**
     * 获取当前请求的灰度版本
     */
    public static String getGrayVersion() {
        String grayVersion = GRAY_VERSION_HOLDER.get();
        return grayVersion != null ? grayVersion : NORMAL_VERSION;
    }

    /**
     * 清除当前请求的灰度版本
     */
    public static void clear() {
        GRAY_VERSION_HOLDER.remove();
        log.debug("清除灰度版本上下文");
    }

    /**
     * 判断是否为灰度请求
     */
    public static boolean isGrayRequest() {
        String grayVersion = getGrayVersion();
        return !NORMAL_VERSION.equals(grayVersion);
    }

    /**
     * 获取正常版本标识
     */
    public static String getNormalVersion() {
        return NORMAL_VERSION;
    }
}
