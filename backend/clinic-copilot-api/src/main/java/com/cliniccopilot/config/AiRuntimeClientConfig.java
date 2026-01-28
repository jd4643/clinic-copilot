package com.cliniccopilot.config;


import io.netty.channel.ChannelOption;
import io.netty.handler.timeout.ReadTimeoutHandler;
import io.netty.handler.timeout.WriteTimeoutHandler;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

import java.time.Duration;

@Configuration
public class AiRuntimeClientConfig {

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


    @Bean
    public WebClient aiRuntimeWebClient(@Value("${ai.runtime.baseUrl}") String baseUrl,
                                        @Value("${ai.runtime.apiKey}") String apiKey) {
        HttpClient httpClient = HttpClient.create()
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 3000)
                .responseTimeout(Duration.ofSeconds(45))
                .doOnConnected(conn -> conn
                        .addHandlerLast(new ReadTimeoutHandler(45))
                        .addHandlerLast(new WriteTimeoutHandler(45)));

        return WebClient.builder()
                .baseUrl(baseUrl)
                .defaultHeader("X-API-Key", apiKey)
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .build();
    }
}
