"""OpenRouter Vision API client.

Connects to any vision-capable model hosted on OpenRouter
(e.g. ``openai/gpt-4.1-nano``) for image description and OCR.
Requires ``OPENROUTER_API_KEY`` in the environment; the model is
selected with ``OPENROUTER_MODEL`` (default: ``openai/gpt-4.1-nano``).
"""

from __future__ import annotations

import json
import logging
import os
import time
import urllib.error
import urllib.request

log = logging.getLogger(__name__)

API_KEY_ENV_VARS = ("OPENROUTER_API_KEY",)

API_URL = "https://openrouter.ai/api/v1/chat/completions"

DESCRIBE_PROMPT = """Describe this image comprehensively and objectively. Include:
1. Main subject and composition
2. Colors, lighting, visual style
3. ALL visible text (transcribed exactly, preserve original language)
4. People, objects, environment
5. Context and purpose (UI screenshot, photo, diagram, document, etc.)
6. Technical quality and notable visual elements

Be precise. Do not speculate beyond what is visible."""

OCR_PROMPT = """Extract ALL text from this image EXACTLY as it appears.
Preserve the original language, capitalization, line breaks, and formatting.
Return ONLY the extracted text with no commentary.
If there is no readable text, say "[No text detected]"."""

DEFAULT_MODEL = "openai/gpt-4.1-nano"

MAX_RETRIES = 3
RETRY_BASE_DELAY = 2  # seconds, doubles each retry


def get_api_key() -> str | None:
    for var in API_KEY_ENV_VARS:
        val = os.environ.get(var)
        if val:
            return val
    return None


def get_model() -> str:
    return os.environ.get("OPENROUTER_MODEL", DEFAULT_MODEL)


def call(prompt: str, b64_data: str, mime_type: str = "image/png") -> dict:
    """Call the OpenRouter chat completions API with a base64 image.

    Args:
        prompt: Text prompt to send alongside the image.
        b64_data: Base64-encoded image data.
        mime_type: MIME type of the image (e.g. "image/png").

    Returns:
        {"text": "..."} on success, or {"error": "..."} on failure.
    """
    api_key = get_api_key()
    if not api_key:
        return {
            "error": "OPENROUTER_API_KEY not found. Set it in the environment."
        }

    model = get_model()
    data_url = f"data:{mime_type};base64,{b64_data}"

    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            }
        ],
        "temperature": 0.2,
        "max_tokens": 8192,
    }

    last_error = None
    for attempt in range(MAX_RETRIES):
        try:
            req = urllib.request.Request(
                API_URL,
                data=json.dumps(payload).encode("utf-8"),
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {api_key}",
                },
            )
            with urllib.request.urlopen(req, timeout=60) as resp:
                result = json.loads(resp.read().decode("utf-8"))

            choices = result.get("choices", [])
            if not choices:
                return {"error": f"[NO CHOICES] {str(result)[:300]}"}

            message = choices[0].get("message", {})
            content = message.get("content", "")
            if not content:
                finish = choices[0].get("finish_reason", "?")
                return {"error": f"[EMPTY: finish_reason={finish}]"}

            return {"text": content.strip()}

        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")
            if e.code == 429 and attempt < MAX_RETRIES - 1:
                delay = RETRY_BASE_DELAY ** (attempt + 1)
                log.warning("Rate limited, retrying in %ds...", delay)
                time.sleep(delay)
                last_error = {"error": f"HTTP {e.code}: {body[:300]}"}
                continue
            return {"error": f"HTTP {e.code}: {body[:300]}"}

        except Exception as e:
            if attempt < MAX_RETRIES - 1:
                delay = RETRY_BASE_DELAY ** (attempt + 1)
                log.warning("API error, retrying in %ds: %s", delay, e)
                time.sleep(delay)
                last_error = {"error": f"{type(e).__name__}: {e}"}
                continue
            return {"error": f"{type(e).__name__}: {e}"}

    return last_error or {"error": "Failed after all retries"}
