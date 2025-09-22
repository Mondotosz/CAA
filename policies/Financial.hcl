# Allow read access to the Financial key
path "transit/keys/Financial" {
  capabilities = ["read"]
}

# Allow read and write access to the Financial store
path "kv-v2/data/ciphertexts/Financial/*" {
  capabilities = ["read", "create"]
}
