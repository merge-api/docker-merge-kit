"""Reproduce the incident without network requests or external credentials."""

import hashlib
import hmac
from service import WebhookReceiver


def sign(key, payload):
    return hmac.new(key, payload, hashlib.sha256).hexdigest()


receiver = WebhookReceiver()
payload = b'{"event":"invoice.paid"}'
old_key = b"public-demo-old-key"
new_key = b"public-demo-new-key"
before = receiver.receive("acme-test", payload, sign(old_key, payload))
receiver.rotate_key("acme-test", new_key)
after = receiver.receive("acme-test", payload, sign(new_key, payload))
old_after = receiver.receive("acme-test", payload, sign(old_key, payload))
print("SYNTHETIC SAMPLE / no external requests")
print(f"Before rotation:              {before} (expected 200)")
print(f"New key after rotation:       {after} (expected 200)")
print(f"Old key after rotation:       {old_after} (expected 401)")
print("REPRODUCED" if after != 200 else "NOT REPRODUCED")
raise SystemExit(1 if after != 200 or old_after != 401 else 0)
