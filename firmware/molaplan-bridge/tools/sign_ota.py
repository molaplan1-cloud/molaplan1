#!/usr/bin/env python3
"""Sign a Molaplan Bridge firmware image and write its OTA manifest.

  BRIDGE_OTA_SIGNING_KEY=<base64 32-byte Ed25519 seed> \
    python3 tools/sign_ota.py firmware.bin 0.8.0 https://…/molaplan-bridge-0.8.0.bin > manifest.json

The key is read only from the environment (in CI: the repository secret). The signed message is
  molaplan-bridge-ota|v1|<version>|<code>|<size>|<sha256 hex>
which the bridge checks against the public key compiled into it (lib/mpcore/src/mp_ota_key.cpp)."""
import base64, hashlib, json, os, sys

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey


def version_code(v):
    a, b, c = (list(map(int, v.split(".")[:3])) + [0, 0, 0])[:3]
    return a * 10000 + b * 100 + c


def b64url(b):
    return base64.urlsafe_b64encode(b).decode().rstrip("=")


def manifest(image, version, url, seed):
    sha = hashlib.sha256(image).hexdigest()
    code = version_code(version)
    msg = f"molaplan-bridge-ota|v1|{version}|{code}|{len(image)}|{sha}".encode()
    key = Ed25519PrivateKey.from_private_bytes(seed)
    return {"version": version, "code": code, "size": len(image), "sha256": sha, "sig": b64url(key.sign(msg)), "url": url}


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    raw = os.environ.get("BRIDGE_OTA_SIGNING_KEY", "").strip()
    if not raw:
        sys.exit("BRIDGE_OTA_SIGNING_KEY is not set")
    seed = base64.b64decode(raw + "=" * (-len(raw) % 4), altchars=b"-_" if ("-" in raw or "_" in raw) else None)
    if len(seed) != 32:
        sys.exit("BRIDGE_OTA_SIGNING_KEY must be a base64 32-byte seed")
    with open(sys.argv[1], "rb") as f:
        image = f.read()
    print(json.dumps(manifest(image, sys.argv[2], sys.argv[3], seed), indent=1))


if __name__ == "__main__":
    main()
