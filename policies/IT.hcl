# Allow read access to the IT key
path "transit/keys/IT" {
  capabilities = ["read"]
}

# Allow read and write access to the IT store
path "kv-v2/data/ciphertexts/IT/*" {
  capabilities = ["read", "create"]
}
