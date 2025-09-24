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
  capabilities = ["create", "update", "read"]
}

path "kv-v2/metadata/ciphertexts/IT/*" {
  capabilities = ["create", "update"]
}

path "kv-v2/metadata/ciphertexts/IT/*" {
  capabilities = ["list"]
}
