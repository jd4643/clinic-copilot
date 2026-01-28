"""
Test MedASR using Google's official example code (FIXED)
"""
from transformers import AutoModelForCTC, AutoProcessor
import librosa
import torch

print("="*60)
print("TESTING MEDASR - Google's Official Example")
print("="*60)

# Use local model path
model_id = "/home/mlservice/ml-platform/cache/medasr/model"
audio_path = "/home/mlservice/ml-platform/cache/medasr/model/test_audio.wav"

print(f"\nModel: {model_id}")
print(f"Audio: {audio_path}")

# Check device
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Device: {device}")

# Load processor
print("\nLoading processor...")
processor = AutoProcessor.from_pretrained(model_id, local_files_only=True)
print("✓ Processor loaded")

# Load model
print("\nLoading model...")
model = AutoModelForCTC.from_pretrained(
    model_id,
    local_files_only=True,
    torch_dtype=torch.float16 if device == "cuda" else torch.float32
).to(device)
print(f"✓ Model loaded on {device}")

# Load audio
print("\nLoading audio...")
speech, sample_rate = librosa.load(audio_path, sr=16000)
print(f"✓ Audio loaded: {len(speech)/16000:.2f} seconds")

# Process audio
print("\nProcessing...")
inputs = processor(speech, sampling_rate=sample_rate, return_tensors="pt", padding=True)

# CRITICAL FIX: Convert inputs to same dtype as model
if device == "cuda":
    inputs = {k: v.to(device).half() for k, v in inputs.items()}  # Convert to float16
else:
    inputs = {k: v.to(device) for k, v in inputs.items()}

print("✓ Inputs prepared")

# Generate transcription
print("\nGenerating transcription...")
with torch.no_grad():
    outputs = model.generate(**inputs)

# Decode
decoded_text = processor.batch_decode(outputs)[0]

print("\n" + "="*60)
print("RESULT")
print("="*60)
print(f"Transcription: {decoded_text}")
print("="*60)
print("\n✓ MedASR is working!")
