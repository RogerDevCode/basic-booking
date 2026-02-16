#!/usr/bin/env python3
"""
N8N API Configuration
Centralized configuration for all n8n scripts

Priority:
1. Environment variables (already set in system)
2. .env file
3. Default values

Usage:
    from config import N8NConfig
    config = N8NConfig()
    print(config.api_url)
"""

import os
from pathlib import Path
from typing import Optional


def load_env_file(env_path: Optional[str] = None) -> None:
    """
    Load environment variables from .env file
    Only sets variables that are NOT already defined in environment

    Args:
        env_path: Path to .env file. Defaults to scripts-py/.env
    """
    if env_path is None:
        env_path = Path(__file__).parent / ".env"
    else:
        env_path = Path(env_path)

    if not env_path.exists():
        return

    with open(env_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                # Only set if NOT already in environment
                if key not in os.environ:
                    os.environ[key] = value


class N8NConfig:
    """
    N8N API Configuration

    Reads configuration from (in order of priority):
    1. Parameters passed to constructor
    2. Environment variables (N8N_API_URL, N8N_API_KEY, N8N_ACCESS_TOKEN)
    3. .env file (only for variables not already in environment)
    """

    def __init__(
        self,
        api_url: Optional[str] = None,
        api_key: Optional[str] = None,
        timeout: int = 30,
        verify_ssl: bool = True,
    ):
        # Load .env file (only for missing variables)
        load_env_file()

        # API URL: parameter > env var > default
        self.api_url = api_url or os.getenv("N8N_API_URL") or "http://localhost:5678"
        self.api_url = self.api_url.rstrip("/")
        
        # Strip /api/v1 if already present to avoid duplication in base_endpoint
        if self.api_url.endswith("/api/v1"):
            self.api_url = self.api_url[:-7]

        # API Key: parameter > N8N_API_KEY > N8N_ACCESS_TOKEN
        self.api_key = (
            api_key or os.getenv("N8N_API_KEY") or os.getenv("N8N_ACCESS_TOKEN")
        )

        self.timeout = timeout
        self.verify_ssl = verify_ssl

        if not self.api_key:
            raise ValueError(
                "N8N API Key not found. Options:\n"
                "  1. Set N8N_API_KEY environment variable\n"
                "  2. Set N8N_ACCESS_TOKEN environment variable\n"
                "  3. Create .env file with N8N_API_KEY=your-key\n"
                "  4. Pass api_key parameter"
            )

    @property
    def headers(self) -> dict:
        return {"X-N8N-API-Key": self.api_key, "Content-Type": "application/json"}

    @property
    def base_endpoint(self) -> str:
        return f"{self.api_url}/api/v1"

    def workflow_endpoint(self, workflow_id: str = "") -> str:
        path = f"/workflows/{workflow_id}" if workflow_id else "/workflows"
        return f"{self.base_endpoint}{path}"

    def execution_endpoint(self, execution_id: str = "") -> str:
        path = f"/executions/{execution_id}" if execution_id else "/executions"
        return f"{self.base_endpoint}{path}"


# Known workflow IDs (for convenience)
WORKFLOW_IDS = {
    "BB_00_Global_Error_Handler": "_Za9GzqB2cS9HVwBglt43",
    "BB_02_Security_Firewall": "Rhn_gioVdn3Q3AeiyNPYg",
}

# Workflows directory path
WORKFLOWS_DIR = Path(__file__).parent.parent / "workflows"
