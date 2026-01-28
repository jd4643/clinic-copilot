@app.post("/transcribe")
async def transcribe_audio(audio: UploadFile = File(...)):
    """
    Transcribe audio to text using Google MedASR
    Supports medical terminology and dictation
    """
    try:
        logger.info(f"Transcription request: {audio.filename}")
        
        # Validate file type
        file_ext = os.path.splitext(audio.filename)[1].lower()
        allowed_formats = ['.wav', '.mp3', '.m4a', '.flac', '.ogg', '.webm']
        
        if file_ext not in allowed_formats:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported audio format '{file_ext}'. Allowed: {allowed_formats}"
            )
        
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_ext) as tmp_file:
            file_content = await audio.read()
            tmp_file.write(file_content)
            tmp_path = tmp_file.name
        
        try:
            # Get MedASR pipeline
            pipe, _ = model_manager.get_medasr()
            
            logger.info("Transcribing with MedASR pipeline...")
            
            # Use pipeline directly - it handles everything
            result = pipe(
                tmp_path,
                chunk_length_s=20,
                stride_length_s=2
            )
            
            text = result['text']
            
            # Calculate duration
            import librosa
            duration = librosa.get_duration(path=tmp_path)
            
            logger.info(f"Transcription complete: {len(text)} characters")
            
            return TranscriptionResponse(
                text=text,
                language="en",
                model="google/medasr",
                duration_seconds=duration
            )
            
        finally:
            # Clean up temp file
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
            
    except Exception as e:
        logger.error(f"Transcription error: {e}", exc_info=True)
        
        # Handle GPU OOM
        if "out of memory" in str(e).lower():
            logger.warning("GPU OOM - cleaning up models")
            model_manager.unload_all()
            raise HTTPException(
                status_code=503,
                detail="GPU out of memory. Models unloaded. Please retry."
            )
        
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")
