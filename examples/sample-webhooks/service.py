"""Deliberately flawed, in-memory webhook receiver for a synthetic demo."""

import hashlib
import hmac


class WebhookReceiver:
    def __init__(self):
        self.key_store = {"acme-test": b"public-demo-old-key"}
        self.key_cache = {}

    def rotate_key(self, account, new_key):
        self.key_store[account] = new_key
        return {"rotated": True}

    def receive(self, account, payload, signature):
        if account not in self.key_cache:
            self.key_cache[account] = self.key_store[account]
        key = self.key_cache[account]
        expected = hmac.new(key, payload, hashlib.sha256).hexdigest()
        return 200 if hmac.compare_digest(expected, signature) else 401
