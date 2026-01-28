package com.cliniccopilot.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AiRuntimeConfig {

    @Value("${ai.runtime.baseUrl}")
    private String baseUrl;

    @Value("${ai.runtime.apiKey}")
    private String apiKey;

    public String getBaseUrl() {
        return baseUrl;
    }

    public String getApiKey() {
        return apiKey;
    }
}
