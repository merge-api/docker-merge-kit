# Sample webhook incident

This is a synthetic application and incident for the Docker + Merge demo.
Acme Test Account is fictional. No matching CRM record or support ticket is
assumed to exist in Agent Handler.

Incident: after rotating its signing key, Acme Test Account receives HTTP 401
responses for every webhook signed with the new key. Deliveries signed with the
previous key still succeed. The key rotation was acknowledged successfully.

Run the local reproduction with `python3 reproduce.py`. Exit code 1 means the
reported failure was reproduced. These signing keys are public test fixtures.

The investigation should cite the code and use Agent Handler to look for
matching customer/support records. If none exist, report that fact explicitly.
Do not present synthetic customer context as data retrieved from a live system.
