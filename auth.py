"""
Authentication module for Medical ML API
Simple API Key authentication for development stage
"""

import os
import secrets
import hashlib
from datetime import datetime
from typing import Optional, Dict
from fastapi import Security, HTTPException, status, Request
from fastapi.security import APIKeyHeader

# =============================================================================
# CONFIGURATION
# =============================================================================

# API Key header name - developers will use this header
API_KEY_HEADER_NAME = "X-API-Key"

# Initialize the security scheme
api_key_header = APIKeyHeader(name=API_KEY_HEADER_NAME, auto_error=False)

# Endpoints that DON'T require authentication (public endpoints)
PUBLIC_ENDPOINTS = {
    "/",
    "/health",
    "/docs",
    "/openapi.json",
    "/redoc",
}

# =============================================================================
# API KEY STORAGE
# =============================================================================

# API Keys for your team
# Format: "key_name": "actual_api_key"
# 
# Generate new keys with: python -c "import secrets; print(secrets.token_urlsafe(32))"
#
# In production, move these to environment variables or a database!

API_KEYS: Dict[str, dict] = {
    # Backend Development Team
    "backend-dev-1": {
        "key": "dev_mml_bk1_Xt7Kp9Qm2Ws4Yn6Vb8Hj0Lc3Rf5Tg7Ui9Oa1Ed",
        "description": "Backend Developer 1",
        "created": "2025-01-25",
        "active": True,
    },
    "backend-dev-2": {
        "key": "dev_mml_bk2_Zp4Wq8Nm1Ks6Yh3Vt9Bj7Lx0Cf2Rg5Ui8Oa4Ed",
        "description": "Backend Developer 2", 
        "created": "2025-01-25",
        "active": True,
    },
    # Testing/QA
    "qa-team": {
        "key": "dev_mml_qa_Mn3Kp7Ws2Xt9Yb5Vh1Lj8Nc4Rf6Tg0Ui2Oa9Ed",
        "description": "QA Testing Team",
        "created": "2025-01-25",
        "active": True,
    },
    # Admin key (for you)
    "admin": {
        "key": "dev_mml_adm_Qw8Ep3Rt7Yu2Io5Pa9Sd4Fg1Hj6Kl0Zx8Cv3Bn",
        "description": "Admin Access",
        "created": "2025-01-25",
        "active": True,
    },
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def get_all_valid_keys() -> set:
    """Return set of all active API keys."""
    return {
        data["key"] 
        for data in API_KEYS.values() 
        if data.get("active", True)
    }

def get_key_info(api_key: str) -> Optional[dict]:
    """Get info about an API key (for logging)."""
    for name, data in API_KEYS.items():
        if data["key"] == api_key:
            return {"name": name, "description": data["description"]}
    return None

def is_public_endpoint(path: str) -> bool:
    """Check if the endpoint is public (no auth required)."""
    # Exact match
    return path in PUBLIC_ENDPOINTS

   

# =============================================================================
# AUTHENTICATION DEPENDENCY
# =============================================================================

async def verify_api_key(
    request: Request,
    api_key: Optional[str] = Security(api_key_header)
) -> Optional[str]:
    """
    Verify API key from request header.
    
    This is a FastAPI dependency - add it to protected endpoints.
    
    Usage:
        @app.post("/protected-endpoint")
        async def protected(api_key: str = Depends(verify_api_key)):
            ...
    """
    # Allow public endpoints without auth
    if is_public_endpoint(request.url.path):
        return None
    
    # Check if API key header is present
    if api_key is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error": "Missing API Key",
                "message": f"Include '{API_KEY_HEADER_NAME}' header with your request",
                "example": f"curl -H '{API_KEY_HEADER_NAME}: your-api-key' ..."
            },
            headers={"WWW-Authenticate": "ApiKey"},
        )
    
    # Validate the API key
    valid_keys = get_all_valid_keys()
    if api_key not in valid_keys:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "Invalid API Key",
                "message": "The provided API key is not valid or has been deactivated",
            },
        )
    
    # Return the validated key (can be used for logging)
    return api_key

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def generate_new_api_key(prefix: str = "dev_mml") -> str:
    """
    Generate a new secure API key.
    
    Usage:
        python -c "from auth import generate_new_api_key; print(generate_new_api_key('myprefix'))"
    """
    random_part = secrets.token_urlsafe(32)
    return f"{prefix}_{random_part}"

def list_api_keys() -> list:
    """List all API keys (for admin purposes). Masks the actual keys."""
    result = []
    for name, data in API_KEYS.items():
        key = data["key"]
        masked_key = f"{key[:12]}...{key[-4:]}"  # Show first 12 and last 4 chars
        result.append({
            "name": name,
            "masked_key": masked_key,
            "description": data["description"],
            "created": data["created"],
            "active": data["active"],
        })
    return result


# =============================================================================
# FOR TESTING
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("Medical ML API - Authentication Module")
    print("=" * 60)
    print("\nRegistered API Keys:")
    print("-" * 60)
    for key_info in list_api_keys():
        status_icon = "✅" if key_info["active"] else "❌"
        print(f"{status_icon} {key_info['name']}: {key_info['masked_key']}")
        print(f"   Description: {key_info['description']}")
        print(f"   Created: {key_info['created']}")
        print()
    
    print("\nGenerate a new API key:")
    print(f"   {generate_new_api_key('dev_mml_new')}")
