# Allow encryption using the IT key
path "transit/encrypt/IT" {
  capabilities = ["update"]
}

# Allow decryption using the IT key
path "transit/decrypt/IT" {
  capabilities = ["update"]
}

# Allow read and write access to the IT store
path "kv-v2/data/ciphertexts/IT/*" {
  capabilities = ["create", "read", "list"]
}
