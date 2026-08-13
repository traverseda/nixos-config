"""OpenRouter vision provider — any vision-capable model on OpenRouter."""

from __future__ import annotations

import logging

from opencode_vision import openrouter
from opencode_vision.providers import VisionProvider, register_provider

log = logging.getLogger(__name__)


class OpenRouterVisionProvider(VisionProvider):
    """Vision provider backed by an OpenRouter vision model.

    Uses ``OPENROUTER_API_KEY`` and ``OPENROUTER_MODEL`` (default:
    ``openai/gpt-4.1-nano``) environment variables.
    """

    name: str = "openrouter"

    def describe(self, b64_data: str, mime_type: str, prompt: str) -> dict:
        """Describe an image via an OpenRouter vision model."""
        effective = prompt if prompt else openrouter.DESCRIBE_PROMPT
        return openrouter.call(effective, b64_data, mime_type)

    def ocr(self, b64_data: str, mime_type: str) -> dict:
        """Extract text from an image via an OpenRouter vision model."""
        return openrouter.call(openrouter.OCR_PROMPT, b64_data, mime_type)


# ── Auto-register ─────────────────────────────────────────────────────────────

register_provider("openrouter", OpenRouterVisionProvider)
