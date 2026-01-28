package com.cliniccopilot.client;


import com.cliniccopilot.dto.TranscriptionResponse;

import com.fasterxml.jackson.annotation.JsonProperty;
import org.springframework.core.io.Resource;
import org.springframework.http.MediaType;
import org.springframework.http.client.MultipartBodyBuilder;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.List;

@Component
public class AsrClient {


    private final WebClient aiRuntimeWebClient;


    public AsrClient(WebClient aiRuntimeWebClient) {
        this.aiRuntimeWebClient = aiRuntimeWebClient;
    }

    public Mono<TranscriptionResponse.AsrResult> transcribe(Resource audioResource, String originalFilename, String sessionId) {
        MultipartBodyBuilder builder = new MultipartBodyBuilder();
        builder.part("audio", audioResource)
                .filename(originalFilename)
                .contentType(MediaType.APPLICATION_OCTET_STREAM);

        if (sessionId != null && !sessionId.isBlank()) {
            builder.part("sessionId", sessionId);
        }
        return aiRuntimeWebClient.post()
                .uri("/transcribe")
                .contentType(MediaType.MULTIPART_FORM_DATA)
                .body(BodyInserters.fromMultipartData(builder.build()))
                .retrieve()
                .bodyToMono(AsrRuntimeResponse.class)
                .map(r -> new TranscriptionResponse.AsrResult(
                        r.transcript(),        // Changed from r.transcript()
                        r.segments()     // Will be null since MedASR doesn't return segments
                ));
    }

    // This matches what Python returns.
    public record AsrRuntimeResponse(String transcript, java.util.List<TranscriptionResponse.Segment> segments) {}




      /*  public record AsrRuntimeResponse(
                String text,                    // Changed from "transcript" to "text"
                String language,                // Added
                String model,                   // Added
                @JsonProperty("duration_seconds") double durationSeconds,  // Added
                List<TranscriptionResponse.Segment> segments  // Keep this (even though not in response)
        ) {}*/


}
