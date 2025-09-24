# Allow encryption using the Financial key
path "transit/encrypt/Financial" {
  capabilities = ["update"]
}

# Allow decryption using the Financial key
path "transit/decrypt/Financial" {
  capabilities = ["update"]
}

# Allow read and write access to the Financial store
path "kv-v2/data/ciphertexts/Financial/*" {
  capabilities = ["create", "read"]
}

path "kv-v2/metadata/ciphertexts/Financial/*" {
  capabilities = ["list"]
}
