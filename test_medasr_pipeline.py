"""
Test MedASR using Pipeline API (simpler, more compatible)
"""
from transformers import pipeline
import torch

print("="*60)
print("TESTING MEDASR - Pipeline API")
print("="*60)

model_id = "/home/mlservice/ml-platform/cache/medasr/model"
audio_path = "/home/mlservice/ml-platform/cache/medasr/model/test_audio.wav"

print(f"\nModel: {model_id}")
print(f"Audio: {audio_path}")
print(f"Device: {'cuda' if torch.cuda.is_available() else 'cpu'}")

# Create pipeline
print("\nCreating ASR pipeline...")
pipe = pipeline(
    "automatic-speech-recognition",
    model=model_id,
    device=0 if torch.cuda.is_available() else -1
)
print("✓ Pipeline created")

# Transcribe
print("\nTranscribing...")
result = pipe(
    audio_path,
    chunk_length_s=20,
    stride_length_s=2
)

print("\n" + "="*60)
print("RESULT")
print("="*60)
print(f"Transcription: {result['text']}")
print("="*60)
print("\n✓ MedASR is working!")
