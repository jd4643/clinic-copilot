"""
Model lifecycle management with lazy loading and TTL cache
"""
import gc
import time
import torch
from typing import Optional, Dict, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta
import logging
import os

logger = logging.getLogger(__name__)

@dataclass
class ModelState:
    model: any
    tokenizer: Optional[any]
    processor: Optional[any]
    last_used: datetime
    load_time: float

class ModelManager:
    """
    Manages model lifecycle:
    - Lazy loading (only load when needed)
    - TTL-based unloading (free GPU after idle time)
    - Prevents OOM by managing GPU memory
    """
    
    def __init__(self, ttl_minutes: int = 10):
        self.models: Dict[str, ModelState] = {}
        self.ttl = timedelta(minutes=ttl_minutes)
        self.cache_dir = os.path.expanduser("~/ml-platform/cache")
        
    def get_medgemma(self) -> Tuple[any, any]:
        """Get or load MedGemma model"""
        if "medgemma" in self.models:
            self.models["medgemma"].last_used = datetime.now()
            return self.models["medgemma"].model, self.models["medgemma"].tokenizer
        
        return self._load_medgemma()
    
    def get_medasr(self) -> Tuple[any, any]:
        """Get or load MedASR model"""
        if "medasr" in self.models:
            self.models["medasr"].last_used = datetime.now()
            return self.models["medasr"].model, self.models["medasr"].processor
        
        return self._load_medasr()
    
    def _load_medgemma(self):
        """Load MedGemma into GPU memory"""
        from transformers import AutoTokenizer, AutoModelForCausalLM
        
        logger.info("Loading MedGemma...")
        start = time.time()
        
        model_path = f"{self.cache_dir}/medgemma/models--google--medgemma-1.5-4b-it/snapshots/e9792da5fb8ee651083d345ec4bce07c3c9f1641"
       
        
        tokenizer = AutoTokenizer.from_pretrained(
            model_path,
            local_files_only=True,
            trust_remote_code=True
        )
        
        model = AutoModelForCausalLM.from_pretrained(
            model_path,
            local_files_only=True,
            torch_dtype=torch.bfloat16,
            device_map="auto",
            trust_remote_code=True
        )
        
        load_time = time.time() - start
        logger.info(f"MedGemma loaded in {load_time:.2f}s")
        
        self.models["medgemma"] = ModelState(
            model=model,
            tokenizer=tokenizer,
            processor=None,
            last_used=datetime.now(),
            load_time=load_time
        )
        
        return model, tokenizer
    
    def _load_medasr(self):
        """Load Google MedASR using Pipeline API"""
        from transformers import pipeline
        import torch
        
        logger.info("Loading Google MedASR (Pipeline API)...")
        start = time.time()
        
        model_path = f"{self.cache_dir}/medasr/model"
        
        # Create ASR pipeline (handles all the complexity)
        pipe = pipeline(
            "automatic-speech-recognition",
            model=model_path,
            device=0 if torch.cuda.is_available() else -1
        )
        
        logger.info("✓ MedASR pipeline created")
        
        load_time = time.time() - start
        logger.info(f"MedASR loaded in {load_time:.2f}s")
        
        # Store pipeline - use pipe for all three arguments
        self.models["medasr"] = ModelState(
            model=pipe,
            tokenizer=pipe,
            processor=pipe,  # FIXED: Added processor argument
            last_used=time.time(),
            load_time=load_time
        )
        
        return pipe, pipe

    def cleanup_idle_models(self):
        """Unload models that haven't been used recently"""
        # Cleanup uses time.time() for consistency
        
        to_remove = []
       
       
        for name, state in self.models.items():
            if isinstance(state.last_used, float):
                last_used_timestamp = state.last_used
            else:
                last_used_timestamp = state.last_used.timestamp()
            
            if time.time() - last_used_timestamp > self.ttl.total_seconds():
            
                to_remove.append(name)
        
        for name in to_remove:
            logger.info(f"unloading idle model: {name}")
            del self.models[name]
            gc.collect()
            torch.cuda.empty_cache()
            
    
    def unload_all(self):
        """Force unload all models"""
        self.models.clear()
        gc.collect()
        torch.cuda.empty_cache()
        logger.info("All models unloaded")

# Global instance
model_manager = ModelManager(ttl_minutes=10)
