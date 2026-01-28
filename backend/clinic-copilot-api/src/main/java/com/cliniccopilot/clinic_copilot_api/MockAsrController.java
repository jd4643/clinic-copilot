package com.cliniccopilot.clinic_copilot_api;

import com.cliniccopilot.dto.TranscriptionResponse;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/mock")
public class MockAsrController {

    @PostMapping(value = "/v1/asr/transcribe", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public MockAsrResponse transcribe(@RequestPart("file") MultipartFile file,
                                      @RequestPart(value = "sessionId", required = false) String sessionId) {

        return new MockAsrResponse(
                "This is a mock transcript for " + (file.getOriginalFilename() == null ? "audio" : file.getOriginalFilename()),
                List.of(new TranscriptionResponse.Segment("Unknown", 0, 1500, "Mock segment text"))
        );
    }

    public record MockAsrResponse(String transcript, List<TranscriptionResponse.Segment> segments) {}
}
