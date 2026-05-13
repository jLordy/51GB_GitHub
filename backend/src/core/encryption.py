"""
AES-256-GCM symmetric encryption for chat messages.

Ciphertext format stored in Firestore:
    enc:<base64(nonce[12 bytes] + ciphertext_with_auth_tag)>

The "enc:" prefix enables backward-compat detection: any text that does NOT
start with this prefix is treated as legacy plaintext and returned verbatim.
"""
from __future__ import annotations

import base64
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# ─────────────────────────────────────────────────────────────────────────────
# Key loading
# ─────────────────────────────────────────────────────────────────────────────

_NONCE_SIZE = 12   # 96-bit nonce (GCM standard)
_PREFIX = "enc:"


def _get_key() -> bytes:
    """Load and base64-decode the 32-byte AES-256 key from the environment."""
    raw = os.environ.get("CHAT_ENCRYPTION_KEY", "")
    if not raw:
        raise RuntimeError(
            "CHAT_ENCRYPTION_KEY environment variable is not set. "
            "Generate one with: python -c \"import os,base64; print(base64.b64encode(os.urandom(32)).decode())\""
        )
    key = base64.b64decode(raw)
    if len(key) != 32:
        raise RuntimeError(
            f"CHAT_ENCRYPTION_KEY must decode to exactly 32 bytes (got {len(key)})"
        )
    return key


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

def encrypt_text(text: str) -> str:
    """
    Encrypt *text* with AES-256-GCM.

    Returns a string of the form  enc:<base64(nonce + ciphertext_with_tag)>
    that is safe to store as a Firestore string field.
    """
    key = _get_key()
    aesgcm = AESGCM(key)
    nonce = os.urandom(_NONCE_SIZE)
    ciphertext = aesgcm.encrypt(nonce, text.encode("utf-8"), None)
    blob = base64.b64encode(nonce + ciphertext).decode("utf-8")
    return f"{_PREFIX}{blob}"


def try_decrypt(text: str) -> str:
    """
    Decrypt *text* if it starts with the 'enc:' prefix.

    If the text is legacy plaintext (no prefix), it is returned unchanged.
    Malformed / tampered ciphertext raises an exception — callers should
    catch and surface an appropriate error.
    """
    if not text.startswith(_PREFIX):
        return text  # legacy plaintext — backward compatible

    blob = text[len(_PREFIX):]
    raw = base64.b64decode(blob)
    nonce = raw[:_NONCE_SIZE]
    ciphertext = raw[_NONCE_SIZE:]
    key = _get_key()
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ciphertext, None).decode("utf-8")
