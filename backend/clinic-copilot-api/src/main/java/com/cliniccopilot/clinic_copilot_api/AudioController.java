package com.cliniccopilot.clinic_copilot_api;


import com.cliniccopilot.client.AsrClient;
import com.cliniccopilot.dto.ApiError;
import com.cliniccopilot.dto.TranscriptionResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.MimeTypeUtils;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.web.bind.annotation.RequestHeader;

@RestController
@RequestMapping("/api/v1/audio")
public class AudioController {

    private static final Logger logger = LoggerFactory.getLogger(AudioController.class);

    private static final Set<String> ALLOWED_TYPES = Set.of(
            "audio/wav",
            "audio/wave",
            "audio/x-wav",
            "audio/mpeg",
            "audio/mp4",
            "audio/webm",
            "application/octet-stream" // some clients send this; allow but still check extension if you want
    );

    private final AsrClient asrClient;

    private final long maxBytes;
    private final String clientApiKey;

    public AudioController(AsrClient asrClient,
                          @Value("${app.upload.maxBytes:26214400}") long maxBytes,
                          @Value("${api.key}") String clientApiKey) {
        this.asrClient = asrClient;
        this.maxBytes = maxBytes;
        this.clientApiKey = clientApiKey;
    }

    @PostMapping(value = "/transcribe", consumes = MediaType.MULTIPART_FORM_DATA_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> transcribe(
            @RequestPart("audio") MultipartFile file,
            @RequestPart(value = "sessionId", required = false) String sessionId,
            @RequestHeader(value = "X-API-Key", required = false) String apiKey
    ) {
        String requestId = UUID.randomUUID().toString();
        logger.info("Transcription request received - requestId: {}, sessionId: {}, fileName: {}",
                requestId, sessionId, file != null ? file.getOriginalFilename() : "null");

        // 0) Validate API Key
        if (!isValidApiKey(apiKey)) {
            logger.warn("Validation failed for requestId {}: Invalid or missing API key", requestId);
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(
                    TranscriptionResponse.failure(requestId, new ApiError(
                            "UNAUTHORIZED",
                            "Invalid or missing API key. Include 'X-API-Key' header with your request.",
                            Map.of()
                    ))
            );
        }
        logger.debug("API key validated - requestId: {}", requestId);

        // 1) Validate presence
        if (file == null || file.isEmpty()) {
            logger.warn("Validation failed for requestId {}: Audio file is missing or empty", requestId);
            return ResponseEntity.badRequest().body(
                    TranscriptionResponse.failure(requestId, new ApiError("MISSING_FILE", "Audio file is required", Map.of()))
            );
        }
        logger.debug("File presence validated - requestId: {}, filename: {}", requestId, file.getOriginalFilename());

        // 2) Validate size
        if (file.getSize() > maxBytes) {
            logger.warn("Validation failed for requestId {}: File too large. Size: {} bytes, Max: {} bytes",
                    requestId, file.getSize(), maxBytes);
            return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE).body(
                    TranscriptionResponse.failure(requestId, new ApiError(
                            "FILE_TOO_LARGE",
                            "Max upload size is " + maxBytes + " bytes",
                            Map.of("maxBytes", maxBytes, "actualBytes", file.getSize())
                    ))
            );
        }
        logger.debug("File size validated - requestId: {}, size: {} bytes", requestId, file.getSize());

        // 3) Validate content type
        String contentType = (file.getContentType() != null) ? file.getContentType() : MimeTypeUtils.APPLICATION_OCTET_STREAM_VALUE;
        if (!ALLOWED_TYPES.contains(contentType)) {
            logger.warn("Validation failed for requestId {}: Invalid content type: {}", requestId, contentType);
            return ResponseEntity.badRequest().body(
                    TranscriptionResponse.failure(requestId, new ApiError(
                            "INVALID_AUDIO_FORMAT",
                            "Unsupported content type: " + contentType,
                            Map.of("allowed", ALLOWED_TYPES)
                    ))
            );
        }
        logger.debug("Content type validated - requestId: {}, contentType: {}", requestId, contentType);

        // 4) Forward to Python ASR (WebClient)
        try {
            logger.info("Forwarding to ASR runtime - requestId: {}", requestId);
            var asr = asrClient
                    .transcribe(file.getResource(), safeName(file.getOriginalFilename()), sessionId)
                    .block(); // Sprint 1: blocking at the edge is OK

            var audioMeta = new TranscriptionResponse.AudioMeta(
                    safeName(file.getOriginalFilename()),
                    contentType,
                    file.getSize(),
                    0
            );

            logger.info("Transcription succeeded - requestId: {}, transcript length: {}",
                    requestId, asr != null && asr.transcript() != null ? asr.transcript().length() : 0);
            return ResponseEntity.ok(TranscriptionResponse.success(requestId, sessionId, audioMeta, asr));


        } catch (WebClientResponseException ex) {
            return handleAsrHttpError(requestId, ex);
        } catch (io.netty.handler.timeout.ReadTimeoutException ex) {
            logger.error("ASR service timeout for requestId {}: Request took too long", requestId);
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(
                    TranscriptionResponse.failure(requestId, new ApiError(
                            "ASR_TIMEOUT",
                            "ASR service did not respond in time. Please try again.",
                            Map.of("timeout", "45 seconds")
                    ))
            );
        } catch (Exception ex) {
            logger.error("Unexpected ASR error for requestId {}: {} - {}",
                    requestId, ex.getClass().getSimpleName(), ex.getMessage(), ex);
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(
                    TranscriptionResponse.failure(requestId, new ApiError(
                            "ASR_SERVICE_ERROR",
                            "ASR service encountered an error. Please try again.",
                            Map.of("reason", ex.getClass().getSimpleName())
                    ))
            );
        }
    }

    private ResponseEntity<?> handleAsrHttpError(String requestId, WebClientResponseException ex) {
        int status = ex.getStatusCode().value();
        String body = ex.getResponseBodyAsString();

        logger.error("ASR runtime returned HTTP error for requestId {}: status={}, body={}",
                requestId, status, body);

        if (status == 503 || status == 502) {
            logger.warn("ASR service unavailable - requestId: {}", requestId);
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(
                    TranscriptionResponse.failure(requestId, new ApiError(
                            "ASR_UNAVAILABLE",
                            "The transcription service is temporarily unavailable. Please try again later.",
                            Map.of("status", status)
                    ))
            );
        } else if (status == 429) {
            logger.warn("ASR rate limited - requestId: {}", requestId);
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(
                    TranscriptionResponse.failure(requestId, new ApiError(
                            "ASR_RATE_LIMITED",
                            "Too many requests. Please try again later.",
                            Map.of("status", status)
                    ))
            );
        } else if (status >= 500) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(
                    TranscriptionResponse.failure(requestId, new ApiError(
                            "ASR_SERVER_ERROR",
                            "ASR service error. Please try again.",
                            Map.of("status", status)
                    ))
            );
        } else {
            return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(
                    TranscriptionResponse.failure(requestId, new ApiError(
                            "ASR_BAD_RESPONSE",
                            "ASR returned error: " + ex.getStatusCode(),
                            Map.of("status", status, "message", body)
                    ))
            );
        }
    }

    private String safeName(String original) {
        return (original == null || original.isBlank()) ? "audio" : original;
    }

    private boolean isValidApiKey(String apiKey) {
        // If no API key is configured (empty/blank), skip validation
        if (clientApiKey == null || clientApiKey.isBlank()) {
            logger.debug("API key validation skipped - no API key configured");
            return true;
        }

        // If API key is configured, it must match
        if (apiKey == null || apiKey.isBlank()) {
            return false;
        }

        return apiKey.equals(clientApiKey);
    }
}
