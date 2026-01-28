package com.cliniccopilot.dto;

import java.util.List;

public record TranscriptionResponse(String requestId,
                                    String sessionId,
                                    String status,
                                    AudioMeta audio,
                                    AsrResult asr,
                                    List<String> warnings,
                                    ApiError error) {


    public static TranscriptionResponse success(String requestId, String sessionId, AudioMeta audio, AsrResult asr) {
        return new TranscriptionResponse(requestId, sessionId, "SUCCESS", audio, asr, List.of(), null);
    }

    public static TranscriptionResponse failure(String requestId, ApiError error) {
        return new TranscriptionResponse(requestId, null, "FAILED", null, null, List.of(), error);
    }


    public record AudioMeta(String originalFileName, String contentType, long sizeBytes, long durationMs) {}
    public record AsrResult(String transcript, List<Segment> segments) {}
    public record Segment(String speaker, long startMs, long endMs, String text) {}
}
