#include "mp_device.h"

namespace mp {
// Ed25519 public key of the release signing key. The private key exists only as the GitHub Actions
// secret BRIDGE_OTA_SIGNING_KEY (generated in memory, never written to disk); CI signs every release.
const char* const kOtaPublicKeyB64 = "iIa9j0lB82MxZrFf7vQ_LDdsEdkM8j-XC-DNenmkgGs";
}  // namespace mp
